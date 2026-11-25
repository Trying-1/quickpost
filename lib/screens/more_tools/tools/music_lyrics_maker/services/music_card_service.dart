import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service responsible for picking album artwork, capturing 1080p+ music card
/// graphics, and saving directly to the Android MediaStore Gallery.
class MusicCardService {
  static final MusicCardService _instance = MusicCardService._internal();
  factory MusicCardService() => _instance;
  MusicCardService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the user's gallery for album art or background wallpaper.
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
      debugPrint('MusicCardService.captureBoundary error: $e');
      return null;
    }
  }

  /// Saves the rendered music card graphic into the Android MediaStore under "Pictures/Quick Post Music Cards".
  Future<String?> saveMusicCardToGallery(Uint8List pngBytes, String songTitle) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeTitle = songTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'MusicCard_${safeTitle}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post Music Cards',
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
        final dcimDir = Directory('/storage/emulated/0/Pictures/Quick Post Music Cards');
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

    // App documents fallback
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

  /// Shares the music card graphic via the native Android share sheet.
  Future<void> shareMusicCard(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'image/png')],
      text: 'Created with Quick Post Music & Lyrics Card Maker!',
    );
  }
}

