import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'font_selector.dart';

class TemplateTransform {
  final double scale;
  final double offsetX;
  final double offsetY;
  final double areaWidth;
  final double areaHeight;
  final int imagePixelWidth;
  final int imagePixelHeight;

  const TemplateTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.areaWidth,
    required this.areaHeight,
    required this.imagePixelWidth,
    required this.imagePixelHeight,
  });
}

class _ResizeParams {
  final Uint8List pngBytes;
  final int width;
  final int height;

  const _ResizeParams(this.pngBytes, this.width, this.height);
}

class _PostImageParams {
  final String text;
  final Uint8List imageBytes;
  final TemplateTransform? transform;
  final FontInfo? selectedFont;

  const _PostImageParams({
    required this.text,
    required this.imageBytes,
    required this.transform,
    required this.selectedFont,
  });
}

class ImageGenerator {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  
  static Future<void> _scanMediaFile(String filePath, String mimeType) async {
    try {
      await _channel.invokeMethod('scanMediaFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
    } catch (e) {
      // Silently fail - media scanner is not critical
    }
  }
  
  static Uint8List? _resizeAndEncodePng(_ResizeParams params) {
    final img.Image? pngImage = img.decodeImage(params.pngBytes);
    if (pngImage == null) return null;

    final img.Image resized = img.copyResize(
      pngImage,
      width: params.width,
      height: params.height,
      interpolation: img.Interpolation.cubic,
    );

    return img.encodePng(resized, level: 6);
  }

  static Uint8List? _generatePostImageSync(_PostImageParams params) {
    final img.Image? src = img.decodeImage(params.imageBytes);
    if (src == null) return null;

    final img.Image canvas = img.Image(width: 1080, height: 1350);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    img.Image lower;
    final transform = params.transform;
    if (transform != null && transform.imagePixelWidth > 0 && transform.imagePixelHeight > 0) {
      final double s = transform.scale;
      final double areaW = transform.areaWidth;
      final double areaH = transform.areaHeight;
      final double offX = transform.offsetX;
      final double offY = transform.offsetY;
      final double srcW = areaW / s;
      final double srcH = areaH / s;
      final double srcX = ((transform.imagePixelWidth * s - areaW) / 2 - offX) / s;
      final double srcY = ((transform.imagePixelHeight * s - areaH) / 2 - offY) / s;

      final int ix = srcX.clamp(0, transform.imagePixelWidth.toDouble()).floor();
      final int iy = srcY.clamp(0, transform.imagePixelHeight.toDouble()).floor();
      final int iw = srcW.clamp(1, (transform.imagePixelWidth - ix).toDouble()).floor();
      final int ih = srcH.clamp(1, (transform.imagePixelHeight - iy).toDouble()).floor();

      final img.Image cropped = img.copyCrop(src, x: ix, y: iy, width: iw, height: ih);
      lower = img.copyResize(cropped, width: 1080, height: 1080, interpolation: img.Interpolation.cubic);
    } else {
      final double srcRatio = src.width / src.height;
      img.Image resized;
      if (srcRatio > 1) {
        resized = img.copyResize(src, height: 1080, interpolation: img.Interpolation.cubic);
        final int x = ((resized.width - 1080) / 2).round();
        lower = img.copyCrop(resized, x: x, y: 0, width: 1080, height: 1080);
      } else {
        resized = img.copyResize(src, width: 1080, interpolation: img.Interpolation.cubic);
        final int y = ((resized.height - 1080) / 2).round();
        lower = img.copyCrop(resized, x: 0, y: y, width: 1080, height: 1080);
      }
    }

    img.compositeImage(canvas, lower, dstX: 0, dstY: 270);
    _drawTextTopBox(canvas, params.text, params.selectedFont);

    return _encodeValidJpg(canvas);
  }
  
  static Future<String?> savePostToGallery({
    required String text,
    File? imageFile,
    TemplateTransform? transform,
    FontInfo? selectedFont,
    GlobalKey? templateKey,
    int? outputWidth,
    int? outputHeight,
  }) async {
    // Request minimally invasive permissions; avoid MANAGE_EXTERNAL_STORAGE which can kick to Settings
    final photosStatus = await Permission.photos.request();
    final storageStatus = await Permission.storage.request();
    final bool hasPermission = photosStatus.isGranted || storageStatus.isGranted;
    if (!hasPermission) {
      throw Exception('Storage permission not granted. Enable Photos/Storage permissions.');
    }

    Uint8List? imageBytes;
    
    // Try to capture from widget first (for custom fonts and grid mode)
    if (templateKey != null) {
      imageBytes = await _captureWidgetAsImage(
        templateKey,
        targetWidth: outputWidth,
        targetHeight: outputHeight,
      );
    }
    
    // Fallback to traditional image generation (only for single image mode)
    if (imageBytes == null && imageFile != null) {
      imageBytes = await _generatePostImage(text, imageFile, transform: transform, selectedFont: selectedFont);
    }
    if (imageBytes == null) {
      throw Exception('Failed to generate image');
    }

    final String? savedPath = await _saveImageToGallery(imageBytes);
    if (savedPath == null) {
      throw Exception('Failed to save image');
    }
    return savedPath;
  }

  static Uint8List? _encodeValidJpg(img.Image image) {
    final Uint8List jpg = img.encodeJpg(image, quality: 95);
    if (jpg.isEmpty) return null;
    final img.Image? verify = img.decodeImage(jpg);
    if (verify == null) return null;
    return jpg;
  }

  static void _drawTextTopBox(img.Image canvas, String text, FontInfo? selectedFont) {
    final int topHeight = 270;
    final int canvasWidth = canvas.width;
    final int xPadding = 40;
    final int maxWidth = canvasWidth - xPadding * 2;
    
    if (text.isEmpty) return;
    
    // For now, use the image package's built-in font but with better sizing
    // The image package has limited font support, so we'll use arial24 as the base
    final font = img.arial24;
    
    // Calculate optimal font size based on text length and available space
    final fontSize = _calculateOptimalFontSize(text, maxWidth, topHeight);
    final scaleFactor = fontSize / 24.0; // arial24 is 24px base size
    
    // Simple text wrapping
    final lines = _wrapText(text, maxWidth, scaleFactor);
    
    // Calculate total height needed
    final lineHeight = (font.lineHeight * scaleFactor).round() + 4;
    final totalHeight = lines.length * lineHeight;
    final startY = ((topHeight - totalHeight) / 2).clamp(0, topHeight - lineHeight).toInt();
    
    // Draw each line
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineWidth = _estimateTextWidth(line, scaleFactor);
      final x = xPadding + ((maxWidth - lineWidth) / 2).toInt();
      final y = startY + (i * lineHeight);
      
      // Draw text with scaling
      _drawScaledText(canvas, line, x, y, scaleFactor);
    }
  }
  
  static List<String> _wrapText(String text, int maxWidth, double scaleFactor) {
    final words = text.split(' ');
    final lines = <String>[];
    String currentLine = '';
    
    // Estimate character width (arial24 is ~14px per char)
    final charWidth = (14 * scaleFactor).round();
    final maxCharsPerLine = (maxWidth / charWidth).floor().clamp(8, 80);
    
    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      if (testLine.length <= maxCharsPerLine) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = word;
        } else {
          // Word is too long, break it
          lines.add(word);
        }
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    // Limit to 4 lines max
    if (lines.length > 4) {
      lines.removeRange(4, lines.length);
      if (lines.isNotEmpty) {
        final lastLine = lines.last;
        if (lastLine.length > 3) {
          lines[lines.length - 1] = lastLine.substring(0, lastLine.length - 3) + '...';
        }
      }
    }
    
    return lines;
  }
  
  static int _estimateTextWidth(String text, double scaleFactor) {
    return (text.length * 14 * scaleFactor).round();
  }
  
  static void _drawScaledText(img.Image canvas, String text, int x, int y, double scaleFactor) {
    // Since we can't easily scale the bitmap font, we'll use the base font
    // and adjust positioning to simulate scaling
    img.drawString(canvas, text, font: img.arial24, x: x, y: y, color: img.ColorRgb8(0, 0, 0));
  }
  
  static double _calculateOptimalFontSize(String text, int width, int height) {
    if (text.isEmpty) return 48.0; // Larger base size for better quality
    
    // Start with a base size and adjust based on text length and available space
    double baseSize = (width * 0.12).clamp(24.0, 72.0); // Increased base size
    
    // Adjust for text length
    if (text.length > 100) {
      baseSize *= 0.7;
    } else if (text.length > 50) {
      baseSize *= 0.8;
    } else if (text.length > 30) {
      baseSize *= 0.9;
    }
    
    // Adjust for available height
    final heightFactor = (height / 270.0).clamp(0.5, 1.5);
    baseSize *= heightFactor;
    
    return baseSize.clamp(20.0, 80.0); // Higher minimum and maximum sizes
  }
  
  static Future<Uint8List?> _captureWidgetAsImage(
    GlobalKey key, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    try {
      final RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      // Capture at 4x resolution for maximum quality
      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Offload decoding, resizing, and encoding to a background isolate
      final int width = targetWidth ?? 1080;
      final int height = targetHeight ?? 1350;
      return compute<_ResizeParams, Uint8List?>(
        _resizeAndEncodePng,
        _ResizeParams(pngBytes, width, height),
      );
    } catch (e) {
      // Return null on error - caller will handle
      return null;
    }
  }
  
  static Future<Uint8List?> _generatePostImage(String text, File imageFile, {TemplateTransform? transform, FontInfo? selectedFont}) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    return compute<_PostImageParams, Uint8List?>(
      _generatePostImageSync,
      _PostImageParams(
        text: text,
        imageBytes: bytes,
        transform: transform,
        selectedFont: selectedFont,
      ),
    );
  }

  static Future<String?> _saveImageToGallery(Uint8List imageBytes) async {
    try {
      // Try using MediaStore API first (works on Android 10+)
      try {
        final String filename = 'QuickPost_${DateTime.now().millisecondsSinceEpoch}.png';
        final result = await _channel.invokeMethod('saveImageToGallery', {
          'imageBytes': imageBytes,
          'filename': filename,
          'folderName': 'Quick Post',
        });
        
        if (result != null && result is String && result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        // MediaStore failed, try fallback methods
      }

      // Fallback 1: Try Pictures directory
      final Directory? pictures = await _getPublicPicturesDirectory();
      if (pictures != null) {
        try {
          final Directory postDir = Directory('${pictures.path}/Quick Post');
          if (!await postDir.exists()) {
            await postDir.create(recursive: true);
          }
          final String filename = 'QuickPost_${DateTime.now().millisecondsSinceEpoch}.png';
          final File f = File('${postDir.path}/$filename');
          await f.writeAsBytes(imageBytes, flush: true);
          if (await f.exists() && await f.length() > 0) {
            await _scanMediaFile(f.path, 'image/png');
            return f.path;
          }
        } catch (e) {
          // Continue to next fallback
        }
      }

      // Fallback 2: Try DCIM directory
      final Directory? dcim = await _getPublicDCIMDirectory();
      if (dcim != null) {
        try {
          final Directory postDir = Directory('${dcim.path}/Quick Post');
          if (!await postDir.exists()) {
            await postDir.create(recursive: true);
          }
          final String filename = 'QuickPost_${DateTime.now().millisecondsSinceEpoch}.png';
          final File f = File('${postDir.path}/$filename');
          await f.writeAsBytes(imageBytes, flush: true);
          if (await f.exists() && await f.length() > 0) {
            await _scanMediaFile(f.path, 'image/png');
            return f.path;
          }
        } catch (e) {
          // Continue to next fallback
        }
      }

      // Fallback 3: Try Download directory
      final Directory? download = await _getPublicDownloadDirectory();
      if (download != null) {
        try {
          final Directory postDir = Directory('${download.path}/Quick Post');
          if (!await postDir.exists()) {
            await postDir.create(recursive: true);
          }
          final String filename = 'QuickPost_${DateTime.now().millisecondsSinceEpoch}.png';
          final File f = File('${postDir.path}/$filename');
          await f.writeAsBytes(imageBytes, flush: true);
          if (await f.exists() && await f.length() > 0) {
            await _scanMediaFile(f.path, 'image/png');
            return f.path;
          }
        } catch (e) {
          // Continue to next fallback
        }
      }

      // Fallback 4: App-specific directory (always works, no permissions needed)
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) {
        try {
          final Directory postDir = Directory('${external.path}/Quick Post');
          if (!await postDir.exists()) {
            await postDir.create(recursive: true);
          }
          final String filename = 'QuickPost_${DateTime.now().millisecondsSinceEpoch}.png';
          final File f = File('${postDir.path}/$filename');
          await f.writeAsBytes(imageBytes, flush: true);
          if (await f.exists() && await f.length() > 0) {
            await _scanMediaFile(f.path, 'image/png');
            return f.path;
          }
        } catch (e) {
          // Last resort failed
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Directory?> _getPublicPicturesDirectory() async {
    final Directory d = Directory('/storage/emulated/0/Pictures');
    if (await d.exists()) return d;
    try { await d.create(recursive: true); } catch (_) {}
    return await d.exists() ? d : null;
  }

  static Future<Directory?> _getPublicDownloadDirectory() async {
    final Directory d = Directory('/storage/emulated/0/Download');
    if (await d.exists()) return d;
    try { await d.create(recursive: true); } catch (_) {}
    return await d.exists() ? d : null;
  }

  static Future<Directory?> _getPublicDCIMDirectory() async {
    final Directory d = Directory('/storage/emulated/0/DCIM');
    if (await d.exists()) return d;
    try { await d.create(recursive: true); } catch (_) {}
    return await d.exists() ? d : null;
  }
}
