import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/carousel_project.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';

/// Service responsible for batch high-resolution PNG rendering and exporting
/// of all slides in a Carousel Post Project.
class CarouselExportService {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');

  /// Gets or creates the backup folder in Downloads/Quick Post Backup.
  static Future<Directory> getExportDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Quick Post Backup');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final dir = Directory('${Directory.current.path}/Quick Post Backup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Exports the entire carousel sequentially slide-by-slide.
  static Future<List<String>> exportAllSlides({
    required CarouselProject project,
    required GlobalKey repaintKey,
    required Future<void> Function(int index) onSwitchSlide,
    required void Function(int current, int total, String status) onProgress,
  }) async {
    final exportedPaths = <String>[];
    final total = project.slides.length;
    final exportDir = await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedProjectTitle = project.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();

    for (int i = 0; i < total; i++) {
      final slide = project.slides[i];
      final slideLabel = _getSlideSlug(slide, i);
      onProgress(i + 1, total, 'Rendering slide ${i + 1} of $total ($slideLabel)...');

      // 1. Switch UI to this slide
      await onSwitchSlide(i);

      // 2. Allow two frames to paint and settle layout + image assets
      await Future.delayed(const Duration(milliseconds: 250));
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Find RepaintBoundary and capture high-res frame
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        continue;
      }

      final renderWidth = boundary.size.width;
      final targetWidth = project.theme.aspectRatioPreset.exportWidth.toDouble();
      final pixelRatio = (targetWidth / renderWidth).clamp(1.0, 4.0);

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) continue;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 4. Save to Downloads/Quick Post Backup
      final fileName = 'CarouselPost_${sanitizedProjectTitle}_${timestamp}_slide_${(i + 1).toString().padLeft(2, '0')}_$slideLabel.png';
      final file = File('${exportDir.path}/$fileName');
      await file.writeAsBytes(pngBytes, flush: true);
      exportedPaths.add(file.path);

      // 5. Register with Android MediaStore / Gallery
      try {
        await _channel.invokeMethod('saveImageToGallery', {
          'imageBytes': pngBytes,
          'filename': fileName,
          'folderName': 'Quick Post Carousel',
        });
      } catch (_) {
        try {
          await _channel.invokeMethod('scanMediaFile', {
            'filePath': file.path,
            'mimeType': 'image/png',
          });
        } catch (_) {}
      }
    }

    return exportedPaths;
  }

  /// Exports just the currently active slide.
  static Future<String?> exportSingleSlide({
    required CarouselProject project,
    required int slideIndex,
    required GlobalKey repaintKey,
  }) async {
    final slide = project.slides[slideIndex];
    final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final renderWidth = boundary.size.width;
    final targetWidth = project.theme.aspectRatioPreset.exportWidth.toDouble();
    final pixelRatio = (targetWidth / renderWidth).clamp(1.0, 4.0);

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final exportDir = await getExportDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final slideLabel = _getSlideSlug(slide, slideIndex);
    final fileName = 'CarouselPost_single_${timestamp}_slide_${(slideIndex + 1).toString().padLeft(2, '0')}_$slideLabel.png';

    final file = File('${exportDir.path}/$fileName');
    await file.writeAsBytes(pngBytes, flush: true);

    try {
      await _channel.invokeMethod('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Quick Post Carousel',
      });
    } catch (_) {
      try {
        await _channel.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    return file.path;
  }

  static String _getSlideSlug(CarouselSlide slide, int index) {
    switch (slide.type) {
      case SlideType.cover:
        return 'cover';
      case SlideType.cta:
        return 'cta';
      case SlideType.content:
        return slide.title.isNotEmpty
            ? slide.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()
            : 'slide_${slide.slideNumber}';
    }
  }
}

