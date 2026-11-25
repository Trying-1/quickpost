import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pixel_art_model.dart';

/// Service handling image decoding, retro color quantization, multi-mode dithering
/// (Bayer 4x4, Bayer 2x2, Floyd-Steinberg), chromatic aberration shift, sprite outlines,
/// and MediaStore gallery export.
class PixelArtService {
  static final PixelArtService _instance = PixelArtService._internal();
  factory PixelArtService() => _instance;
  PixelArtService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  static const List<List<int>> _bayer4x4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];

  static const List<List<int>> _bayer2x2 = [
    [0, 2],
    [3, 1],
  ];

  /// Picks an image from the photo gallery.
  Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Decodes an image file and normalizes its orientation & max bounds (max 900px).
  Future<img.Image?> decodeWorkingImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);

      if (oriented.width > 900 || oriented.height > 900) {
        if (oriented.width >= oriented.height) {
          return img.copyResize(oriented, width: 900, interpolation: img.Interpolation.linear);
        } else {
          return img.copyResize(oriented, height: 900, interpolation: img.Interpolation.linear);
        }
      }
      return oriented;
    } catch (e) {
      debugPrint('PixelArtService decode error: $e');
      return null;
    }
  }

  /// Converts an [img.Image] directly into a Flutter [ui.Image] (used for Before/After comparison).
  Future<ui.Image> imgImageToUiImage(img.Image source) async {
    final int w = source.width;
    final int h = source.height;
    final Uint8List rgba = Uint8List(w * h * 4);
    int offset = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        rgba[offset++] = p.r.toInt().clamp(0, 255);
        rgba[offset++] = p.g.toInt().clamp(0, 255);
        rgba[offset++] = p.b.toInt().clamp(0, 255);
        rgba[offset++] = p.a.toInt().clamp(0, 255);
      }
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Generates a vibrant built-in synthwave retro sunset landscape sample image.
  img.Image generateSampleScene({int width = 320, int height = 320}) {
    final img.Image canvas = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final double ny = y / height;
      for (int x = 0; x < width; x++) {
        final double nx = x / width;

        double r, g, b;
        if (ny < 0.62) {
          final t = ny / 0.62;
          r = 22 + t * 225;
          g = 12 + t * t * 110;
          b = 68 + math.sin(t * math.pi) * 115;

          if (ny < 0.35 && ((x * 73 + y * 139) % 197 == 0)) {
            r = 255;
            g = 250;
            b = 220;
          }

          final double dx = nx - 0.5;
          final double dy = ny - 0.38;
          final double dist = math.sqrt(dx * dx + dy * dy);
          if (dist < 0.21) {
            final bool stripeCut = ny > 0.36 && ((y ~/ 6) % 2 == 0) && ny < 0.56;
            if (!stripeCut) {
              final double sunT = ((ny - 0.17) / 0.42).clamp(0.0, 1.0);
              r = 255;
              g = (238 - sunT * 170).clamp(0, 255);
              b = (95 - sunT * 60).clamp(0, 255);
            }
          }

          final double m1 = 0.62 - 0.14 * math.max(0.0, 1.0 - (nx - 0.24).abs() * 3.8);
          final double m2 = 0.62 - 0.18 * math.max(0.0, 1.0 - (nx - 0.74).abs() * 3.2);
          final double m3 = 0.62 - 0.09 * math.max(0.0, 1.0 - (nx - 0.50).abs() * 5.0);
          final double mountainY = math.min(m1, math.min(m2, m3));
          if (ny >= mountainY) {
            r = 24;
            g = 16;
            b = 44;
          }
        } else {
          final double t = (ny - 0.62) / 0.38;
          r = 16 + (1.0 - t) * 40;
          g = 12 + (1.0 - t) * 20;
          b = 48 + t * 38;

          final double perspectiveX = (nx - 0.5) / (0.15 + t * 1.4);
          final bool vLine = (perspectiveX * 6.0).abs() % 1.0 < 0.08;
          final bool hLine = (math.pow(t, 0.75) * 9.0) % 1.0 < 0.11;
          if (vLine || hLine) {
            r = 0;
            g = 230;
            b = 225;
          }
        }

        canvas.setPixelRgba(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
          255,
        );
      }
    }

    return canvas;
  }

  /// Processes [source] into a quantized pixel grid & GPU [ui.Image] using the requested
  /// resolution, color adjustments, optional sprite outline, RGB shift, dithering algorithm,
  /// and retro console palette.
  Future<({ui.Image pixelImage, Uint8List rgbaBytes, int cols, int rows})> processPixelArt({
    required img.Image source,
    required PixelArtConfig config,
  }) async {
    // 1. Optional aspect-ratio center crop
    img.Image cropped = source;
    final double? targetRatio = config.aspectRatio.ratio;
    if (targetRatio != null && targetRatio > 0) {
      final double srcRatio = source.width / source.height;
      int cropW = source.width;
      int cropH = source.height;
      if (srcRatio > targetRatio) {
        cropW = (source.height * targetRatio).round().clamp(1, source.width);
      } else if (srcRatio < targetRatio) {
        cropH = (source.width / targetRatio).round().clamp(1, source.height);
      }
      final int offsetX = ((source.width - cropW) / 2).round();
      final int offsetY = ((source.height - cropH) / 2).round();
      cropped = img.copyCrop(source, x: offsetX, y: offsetY, width: cropW, height: cropH);
    }

    // 2. Downsample cleanly to grid resolution
    final int cols = config.pixelColumns.clamp(12, 160);
    final int rows = math.max(12, (cols * (cropped.height / cropped.width)).round());

    final img.Image sampled = img.copyResize(
      cropped,
      width: cols,
      height: rows,
      interpolation: img.Interpolation.average,
    );

    // 3. Build working floating-point RGB buffer (rows * cols * 3)
    final int totalPixels = cols * rows;
    final Float64List buf = Float64List(totalPixels * 3);

    final double brightnessOffset = config.brightness * 255.0;
    final double contrastFactor = config.contrast;
    final double satFactor = config.saturation;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final p = sampled.getPixel(x, y);
        double r = p.r.toDouble();
        double g = p.g.toDouble();
        double b = p.b.toDouble();

        // Optional RGB invert
        if (config.invertColors) {
          r = 255.0 - r;
          g = 255.0 - g;
          b = 255.0 - b;
        }

        // Brightness & contrast
        r = ((r - 128.0) * contrastFactor + 128.0) + brightnessOffset;
        g = ((g - 128.0) * contrastFactor + 128.0) + brightnessOffset;
        b = ((b - 128.0) * contrastFactor + 128.0) + brightnessOffset;

        // Luma-preserving saturation adjustment
        if ((satFactor - 1.0).abs() > 0.01) {
          final double luma = 0.299 * r + 0.587 * g + 0.114 * b;
          r = luma + (r - luma) * satFactor;
          g = luma + (g - luma) * satFactor;
          b = luma + (b - luma) * satFactor;
        }

        final int idx = (y * cols + x) * 3;
        buf[idx] = r.clamp(0.0, 255.0);
        buf[idx + 1] = g.clamp(0.0, 255.0);
        buf[idx + 2] = b.clamp(0.0, 255.0);
      }
    }

    // 4. Optional Chromatic RGB Split (horizontal channel convergence shift)
    if (config.rgbSplitColumns > 0) {
      final int shift = config.rgbSplitColumns;
      final Float64List copyBuf = Float64List.fromList(buf);
      for (int y = 0; y < rows; y++) {
        for (int x = 0; x < cols; x++) {
          final int rx = (x - shift).clamp(0, cols - 1);
          final int bx = (x + shift).clamp(0, cols - 1);
          final int dstIdx = (y * cols + x) * 3;
          buf[dstIdx] = copyBuf[(y * cols + rx) * 3]; // Red shifted left
          buf[dstIdx + 2] = copyBuf[(y * cols + bx) * 3 + 2]; // Blue shifted right
        }
      }
    }

    // 5. Optional Inked Sprite Edge Outline darkening
    if (config.edgeOutline && cols > 4 && rows > 4) {
      final Float64List lum = Float64List(totalPixels);
      for (int i = 0; i < totalPixels; i++) {
        final int bi = i * 3;
        lum[i] = 0.299 * buf[bi] + 0.587 * buf[bi + 1] + 0.114 * buf[bi + 2];
      }
      for (int y = 1; y < rows - 1; y++) {
        for (int x = 1; x < cols - 1; x++) {
          final int c = y * cols + x;
          final double gx = (lum[c + 1] - lum[c - 1]).abs();
          final double gy = (lum[c + cols] - lum[c - cols]).abs();
          final double edge = gx + gy;
          if (edge > 78.0) {
            final double darken = (1.0 - ((edge - 78.0) / 170.0).clamp(0.0, 0.72));
            final int bi = c * 3;
            buf[bi] *= darken;
            buf[bi + 1] *= darken;
            buf[bi + 2] *= darken;
          }
        }
      }
    }

    // 6. Palette RGB table
    final List<List<int>>? paletteRgb = config.palette == PixelPaletteType.trueColor
        ? null
        : config.palette.swatchColors
            .map((c) => [
                  (c.r * 255.0).round().clamp(0, 255),
                  (c.g * 255.0).round().clamp(0, 255),
                  (c.b * 255.0).round().clamp(0, 255),
                ])
            .toList();

    final Uint8List rgbaBytes = Uint8List(totalPixels * 4);
    final bool useFloyd = config.ditherAlgorithm == DitherAlgorithm.floydSteinberg;
    final double ditherAmp = config.ditherStrength * 70.0;

    // 7. Dithering & Palette Quantization pass
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final int bi = (y * cols + x) * 3;
        double r = buf[bi];
        double g = buf[bi + 1];
        double b = buf[bi + 2];

        // Ordered Bayer matrices
        if (config.ditherAlgorithm == DitherAlgorithm.bayer4x4 && ditherAmp > 0) {
          final double shift = ((_bayer4x4[y & 3][x & 3] / 16.0) - 0.5) * ditherAmp;
          r += shift;
          g += shift;
          b += shift;
        } else if (config.ditherAlgorithm == DitherAlgorithm.bayer2x2 && ditherAmp > 0) {
          final double shift = ((_bayer2x2[y & 1][x & 1] / 4.0) - 0.5) * ditherAmp;
          r += shift;
          g += shift;
          b += shift;
        }

        final int ir = r.round().clamp(0, 255);
        final int ig = g.round().clamp(0, 255);
        final int ib = b.round().clamp(0, 255);

        int qr = ir;
        int qg = ig;
        int qb = ib;

        if (paletteRgb != null) {
          int bestIdx = 0;
          int bestDist = 0x7FFFFFFF;
          for (int i = 0; i < paletteRgb.length; i++) {
            final pr = paletteRgb[i][0];
            final pg = paletteRgb[i][1];
            final pb = paletteRgb[i][2];
            final dr = ir - pr;
            final dg = ig - pg;
            final db = ib - pb;
            final int dist = (2 * dr * dr) + (4 * dg * dg) + (3 * db * db);
            if (dist < bestDist) {
              bestDist = dist;
              bestIdx = i;
            }
          }
          qr = paletteRgb[bestIdx][0];
          qg = paletteRgb[bestIdx][1];
          qb = paletteRgb[bestIdx][2];
        } else if (config.ditherAlgorithm != DitherAlgorithm.none) {
          // Subtle 5-bit retro depth quantization for True Color dither mode
          qr = ((ir >> 3) << 3).clamp(0, 255);
          qg = ((ig >> 3) << 3).clamp(0, 255);
          qb = ((ib >> 3) << 3).clamp(0, 255);
        }

        // Propagate quantization residual to neighbors for Floyd-Steinberg error diffusion
        if (useFloyd) {
          final double errR = (ir - qr) * config.ditherStrength;
          final double errG = (ig - qg) * config.ditherStrength;
          final double errB = (ib - qb) * config.ditherStrength;

          void addErr(int nx, int ny, double factor) {
            if (nx >= 0 && nx < cols && ny >= 0 && ny < rows) {
              final int ni = (ny * cols + nx) * 3;
              buf[ni] = (buf[ni] + errR * factor).clamp(0.0, 255.0);
              buf[ni + 1] = (buf[ni + 1] + errG * factor).clamp(0.0, 255.0);
              buf[ni + 2] = (buf[ni + 2] + errB * factor).clamp(0.0, 255.0);
            }
          }

          addErr(x + 1, y, 7.0 / 16.0);
          addErr(x - 1, y + 1, 3.0 / 16.0);
          addErr(x, y + 1, 5.0 / 16.0);
          addErr(x + 1, y + 1, 1.0 / 16.0);
        }

        final int outIdx = (y * cols + x) * 4;
        rgbaBytes[outIdx] = qr;
        rgbaBytes[outIdx + 1] = qg;
        rgbaBytes[outIdx + 2] = qb;
        rgbaBytes[outIdx + 3] = 255;
      }
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaBytes,
      cols,
      rows,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final ui.Image result = await completer.future;
    return (pixelImage: result, rgbaBytes: rgbaBytes, cols: cols, rows: rows);
  }

  /// Captures the RepaintBoundary pixel canvas at crisp 3.2x resolution.
  Future<Uint8List?> captureBoundary(GlobalKey boundaryKey, {double pixelRatio = 3.2}) async {
    try {
      final RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('PixelArtService captureBoundary error: $e');
      return null;
    }
  }

  /// Saves the pixel art graphic to Pictures/Quick Post Pixel Art in Android MediaStore.
  Future<String?> savePixelArtToGallery(Uint8List pngBytes, String tagName) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = tagName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'QuickPostPixel_${safeName}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post Pixel Art',
      });
    } catch (e) {
      debugPrint('saveImageToGallery channel error: $e');
    }

    if (finalSavedPath != null && finalSavedPath.startsWith('/')) {
      try {
        await _channel.invokeMethod('scanMediaFile', {
          'filePath': finalSavedPath,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    final bool mediaStoreSuccess = finalSavedPath != null &&
        (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

    if (!mediaStoreSuccess) {
      try {
        final dcimDir = Directory('/storage/emulated/0/Pictures/Quick Post Pixel Art');
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }
        final file = File('${dcimDir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;

        await _channel.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    if (finalSavedPath == null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;
      } catch (_) {}
    }

    return finalSavedPath;
  }

  /// Opens the native share sheet for the exported PNG.
  Future<void> sharePixelArt(String filePath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'image/png')],
          text: 'Created with QuickPost 8-Bit Pixel Studio',
        ),
      );
    } catch (e) {
      debugPrint('Share pixel art error: $e');
    }
  }
}
