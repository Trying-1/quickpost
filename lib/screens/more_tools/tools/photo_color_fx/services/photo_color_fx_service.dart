import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service that handles image picking, native hardware-accelerated Skia rendering
/// with color matrix transformations, and direct MediaStore gallery saving.
class PhotoColorFxService {
  static final PhotoColorFxService _instance = PhotoColorFxService._internal();
  factory PhotoColorFxService() => _instance;
  PhotoColorFxService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the device photo gallery.
  Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Hardware-accelerated Skia render: applies [matrix] to [imageFile]
  /// preserving full original resolution and encoding to high-res PNG.
  Future<Uint8List> renderFilteredImage({
    required File imageFile,
    required List<double> matrix,
  }) async {
    final Uint8List fileBytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(fileBytes);
    final frame = await codec.getNextFrame();
    final ui.Image fullImage = frame.image;

    final int width = fullImage.width;
    final int height = fullImage.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final paint = Paint()
      ..colorFilter = ColorFilter.matrix(matrix)
      ..filterQuality = FilterQuality.high;

    canvas.drawImage(fullImage, Offset.zero, paint);

    final picture = recorder.endRecording();
    final ui.Image filteredImage = await picture.toImage(width, height);
    final ByteData? byteData = await filteredImage.toByteData(format: ui.ImageByteFormat.png);

    fullImage.dispose();
    filteredImage.dispose();

    return byteData!.buffer.asUint8List();
  }

  /// Saves the processed image into the Android MediaStore under "Pictures/Quick Post FX".
  Future<String?> saveFilteredImageToGallery(Uint8List pngBytes, String baseName) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'QuickPostFX_${safeName}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post FX',
      });
    } catch (e) {
      debugPrint('saveImageToGallery channel error: $e');
    }

    // Trigger MediaScanner for immediate visibility in Gallery/Photos
    if (finalSavedPath != null && finalSavedPath.startsWith('/')) {
      try {
        await _channel.invokeMethod('scanMediaFile', {
          'filePath': finalSavedPath,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    // Only fallback if MediaStore saving failed completely
    final bool mediaStoreSuccess = finalSavedPath != null &&
        (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

    if (!mediaStoreSuccess) {
      try {
        final dcimDir = Directory('/storage/emulated/0/Pictures/Quick Post FX');
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

    // App Documents fallback
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

  /// Shares the processed image via the native Android share sheet.
  Future<void> shareFilteredImage(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'image/png')],
      text: 'Created with Quick Post Photo FX!',
    );
  }
}

