import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service responsible for picking wallpaper, capturing ultra-crisp 1080p+
/// thermal receipt graphics, and saving directly to the Android MediaStore Gallery.
class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  /// Picks a custom image from gallery for backdrop.
  Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Captures a [RepaintBoundary] at 3.0x pixel ratio (~1080p to 4K resolution).
  Future<Uint8List?> captureBoundary(GlobalKey boundaryKey) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('ReceiptService.captureBoundary error: $e');
      return null;
    }
  }

  /// Saves the rendered thermal receipt into Android MediaStore under "Pictures/Quick Post Receipts".
  Future<String?> saveReceiptToGallery(Uint8List pngBytes, String storeName) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = storeName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'Receipt_${safeName}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post Receipts',
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

    // Direct DCIM storage fallback if MediaStore channel did not return path
    final bool mediaStoreSuccess = finalSavedPath != null &&
        (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

    if (!mediaStoreSuccess) {
      try {
        final dir = Directory('/storage/emulated/0/Pictures/Quick Post Receipts');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;

        await _channel.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    // App internal storage fallback
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

  /// Shares the graphic via native Android share sheet.
  Future<void> shareReceipt(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'image/png')],
      text: 'Created with Quick Post Thermal Receipt Studio! 🧾✨',
    );
  }
}

