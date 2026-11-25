import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../services/ad_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/app_review_service.dart';
import '../models/carousel_slide.dart';

/// Batch image & video capture service for [CarouselPostScreen].
class CarouselExportService {
  static const MethodChannel _platform =
      MethodChannel('com.quickpost.app/processor');

  /// Captures every slide's preview boundary at 1080px width and saves PNGs to gallery.
  static Future<void> exportImages({
    required BuildContext context,
    required List<CarouselSlide> slides,
    required PageController pageController,
    required int originalIndex,
    required VoidCallback onClearSelection,
    required ValueChanged<int> onJumpSlideIndex,
  }) async {
    AnalyticsService()
        .logSaveAction(feature: 'carousel_post', type: 'image_batch');
    if (slides.every((s) => s.image == null && s.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add content to export')),
      );
      return;
    }

    double currentProgress = 0.0;
    String currentStep = 'Preparing slides...';
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            title: const Text('Exporting Images'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                    value: currentProgress, color: const Color(0xFF6C63FF)),
                const SizedBox(height: 16),
                Text(currentStep, style: const TextStyle(fontSize: 12)),
                Text('${(currentProgress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );

    try {
      int savedCount = 0;
      onClearSelection();

      for (int i = 0; i < slides.length; i++) {
        dialogSetState?.call(() {
          currentStep = 'Capturing slide ${i + 1} of ${slides.length}...';
          currentProgress = i / slides.length;
        });

        pageController.jumpToPage(i);
        onJumpSlideIndex(i);

        await Future.delayed(const Duration(milliseconds: 200));
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 100));

        final boundary = slides[i].previewKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final exportPixelRatio = 1080.0 / boundary.size.width;
          final image = await boundary.toImage(pixelRatio: exportPixelRatio);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            final filename =
                'QuickPost_Carousel_${DateTime.now().millisecondsSinceEpoch}_$i.png';
            await _platform.invokeMethod('saveImageToGallery', {
              'imageBytes': pngBytes,
              'filename': filename,
              'folderName': 'Quick Post',
            });
            savedCount++;
          }
        }
      }

      pageController.jumpToPage(originalIndex);
      onJumpSlideIndex(originalIndex);

      if (context.mounted) Navigator.pop(context);

      if (savedCount > 0) {
        AdService().showInterstitialAd();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Successfully exported $savedCount images to gallery!')),
          );
        }
        AppReviewService().incrementExportCount();
        AppReviewService().checkAndRequestReview();
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image export failed: $e')),
        );
      }
    }
  }

  /// Captures every slide into temporary PNGs and compiles a video natively.
  static Future<void> exportVideo({
    required BuildContext context,
    required List<CarouselSlide> slides,
    required PageController pageController,
    required int originalIndex,
    required VoidCallback onClearSelection,
    required ValueChanged<int> onJumpSlideIndex,
  }) async {
    AnalyticsService().logSaveAction(feature: 'carousel_post', type: 'video');

    double currentProgress = 0.0;
    String currentStep = 'Preparing slides...';
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            title: const Text('Exporting Video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                    value: currentProgress, color: const Color(0xFF6C63FF)),
                const SizedBox(height: 16),
                Text(currentStep, style: const TextStyle(fontSize: 12)),
                Text('${(currentProgress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );

    try {
      final tempDir = await Directory.systemTemp.createTemp('carousel_export_');
      final List<String> framePaths = [];

      onClearSelection();

      for (int i = 0; i < slides.length; i++) {
        dialogSetState?.call(() {
          currentStep = 'Capturing slide ${i + 1} of ${slides.length}...';
          currentProgress = (i / slides.length) * 0.3;
        });

        pageController.jumpToPage(i);
        onJumpSlideIndex(i);

        await Future.delayed(const Duration(milliseconds: 200));
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 100));

        final boundary = slides[i].previewKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final exportPixelRatio = 1080.0 / boundary.size.width;
          final image = await boundary.toImage(pixelRatio: exportPixelRatio);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final framePath = '${tempDir.path}/slide_$i.png';
            await File(framePath).writeAsBytes(byteData.buffer.asUint8List());
            framePaths.add(framePath);
          }
        }
      }

      pageController.jumpToPage(originalIndex);
      onJumpSlideIndex(originalIndex);

      if (framePaths.isEmpty) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      dialogSetState?.call(() {
        currentStep = 'Encoding video...';
        currentProgress = 0.3;
      });

      _platform.setMethodCallHandler((call) async {
        if (call.method == 'onProgress') {
          final nativeProgress = (call.arguments as num).toDouble();
          dialogSetState?.call(() {
            currentProgress = 0.3 + nativeProgress * 0.7;
            currentStep =
                'Encoding video... ${(currentProgress * 100).toInt()}%';
          });
        } else if (call.method == 'onStep') {
          dialogSetState?.call(() => currentStep = call.arguments as String);
        }
      });

      final String? result =
          await _platform.invokeMethod('createVideoFromImages', {
        'imagePaths': framePaths,
        'durationPerSlide': 3.0,
      });

      if (context.mounted) Navigator.pop(context);

      if (result != null) {
        AdService().showInterstitialAd();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video saved to gallery!')),
          );
        }
        AppReviewService().incrementExportCount();
        AppReviewService().checkAndRequestReview();
      }

      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video export failed: $e')),
        );
      }
    } finally {
      _platform.setMethodCallHandler(null);
    }
  }
}

