import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../../../services/ad_service.dart';
import '../../../../utils/image_generator.dart';

/// Handles rendering the [ImagePostMakerScreen] preview RepaintBoundary to an image file
/// and presenting the export completion dialog.
class ImagePostExportService {
  ImagePostExportService._();

  static Future<void> exportPost({
    required BuildContext context,
    required File? selectedImage,
    required GlobalKey repaintKey,
    required bool fullScreen,
    required double imageAspectRatio,
    required Future<void> Function() saveLatestPreset,
    required VoidCallback onBeforeExport,
    required VoidCallback onAfterExport,
    required void Function(String msg, {bool isError}) showToast,
  }) async {
    if (selectedImage == null) {
      showToast('Please select a background image', isError: true);
      return;
    }

    await saveLatestPreset();

    onBeforeExport();

    // Wait for the UI to rebuild cleanly without selection borders
    await Future.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final outAspect = fullScreen ? 9 / 16 : imageAspectRatio;
      const int baseWidth = 1080;
      const int exportWidth = baseWidth;
      final int exportHeight = (baseWidth / outAspect).round();

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: '',
        imageFile: selectedImage,
        transform: null,
        selectedFont: null,
        templateKey: repaintKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (savedPath != null) {
        AdService().showInterstitialAd();
        showToast('✅ Saved successfully to gallery!');

        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Export Success'),
            content: Text('Saved to: $savedPath'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  OpenFile.open(savedPath);
                },
                child: const Text('Open'),
              ),
            ],
          ),
        );
      } else {
        showToast('Failed to save image', isError: true);
      }
    } catch (e) {
      showToast('Error exporting: $e', isError: true);
    } finally {
      onAfterExport();
    }
  }
}
