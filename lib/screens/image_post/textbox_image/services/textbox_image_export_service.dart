import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../../../../services/ad_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/app_review_service.dart';
import '../../../../utils/font_selector.dart';
import '../../../../utils/image_generator.dart';

/// Shared gallery export flow (progress dialog, PNG capture, success/error dialogs)
/// for Single Image and 2x2 Grid modes in Textbox Image.
class TextboxImageExportService {
  const TextboxImageExportService._();

  static Future<void> savePost({
    required BuildContext context,
    required String analyticsFeature,
    required bool hasImages,
    required String missingImageMessage,
    required String text,
    required File? singleImage,
    required FontInfo? selectedFont,
    required GlobalKey previewTemplateKey,
    required double aspectRatio,
    required ValueChanged<bool> onShowPlaceholderChanged,
  }) async {
    AnalyticsService().logSaveAction(feature: analyticsFeature, type: 'image');
    final bool hasText = text.trim().isNotEmpty;

    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missingImageMessage),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  hasText ? 'Saving, please wait...' : 'Saving without text...',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!hasText) {
      onShowPlaceholderChanged(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    try {
      const int baseWidth = 1080;
      final int exportWidth;
      final int exportHeight;

      if (aspectRatio >= 1.0) {
        exportWidth = baseWidth;
        exportHeight = (baseWidth / aspectRatio).round();
      } else {
        exportHeight = baseWidth;
        exportWidth = (baseWidth * aspectRatio).round();
      }

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: text,
        imageFile: singleImage,
        transform: null,
        selectedFont: selectedFont,
        templateKey: previewTemplateKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      AppReviewService().incrementExportCount();
      AppReviewService().checkAndRequestReview();

      if (!context.mounted) return;

      if (savedPath != null) {
        AdService().showInterstitialAd();
        await _showSuccessDialog(context, savedPath);
      } else {
        await _showErrorDialog(
          context,
          'Failed to save post. Please try again.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await _showErrorDialog(context, 'Error: $e');
      }
    } finally {
      if (!hasText) {
        onShowPlaceholderChanged(true);
      }
    }
  }

  static Future<void> _showSuccessDialog(
    BuildContext context,
    String savedPath,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green[50]!, Colors.green[100]!],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your post has been saved successfully',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        savedPath,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        try {
                          final file = File(savedPath);
                          if (await file.exists()) {
                            await OpenFile.open(savedPath);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not open file'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showErrorDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

