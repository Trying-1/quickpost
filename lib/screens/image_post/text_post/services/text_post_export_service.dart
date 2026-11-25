import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../../../services/ad_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/app_review_service.dart';
import '../../../../utils/image_generator.dart';

/// Handles exporting the Text Post preview canvas to gallery and presenting the result modal.
class TextPostExportService {
  TextPostExportService._();

  static Future<void> savePost({
    required BuildContext context,
    required GlobalKey previewKey,
    required double aspectRatio,
    required VoidCallback onBeforeExport,
    required VoidCallback onAfterExport,
  }) async {
    onBeforeExport();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Saving, please wait...'),
            ],
          ),
        ),
      ),
    );

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

      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: '',
        templateKey: previewKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();
      onAfterExport();

      AppReviewService().incrementExportCount();
      AnalyticsService().logSaveAction(feature: 'text_post', type: 'image');
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
        AdService().showInterstitialAd();
        int fileSizeKb = 0;
        try {
          final file = File(savedPath);
          if (await file.exists()) {
            fileSizeKb = (await file.length() / 1024).round();
          }
        } catch (_) {}

        if (!context.mounted) return;
        _showSuccessDialog(
          context: context,
          savedPath: savedPath,
          exportWidth: exportWidth,
          exportHeight: exportHeight,
          fileSizeKb: fileSizeKb,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      onAfterExport();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  static void _showSuccessDialog({
    required BuildContext context,
    required String savedPath,
    required int exportWidth,
    required int exportHeight,
    required int fileSizeKb,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 48,
                  ),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            savedPath,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Resolution',
                      '${exportWidth}x${exportHeight}px',
                    ),
                    if (fileSizeKb > 0)
                      _buildDetailRow('File size', '$fileSizeKb KB'),
                  ],
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
        );
      },
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

