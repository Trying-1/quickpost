import 'package:flutter/material.dart';

import '../../../../services/ad_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/app_review_service.dart';
import '../../../../utils/image_generator.dart';
import '../models/quote_card_config.dart';

/// Handles gallery export for single and bulk Quote Card posts.
class QuoteCardExportService {
  const QuoteCardExportService._();

  /// Renders and saves either the active bulk batch or the current single quote post.
  static Future<void> saveAsImage({
    required BuildContext context,
    required GlobalKey previewKey,
    required int selectedAspectIndex,
    required bool isBulkMode,
    required List<Map<String, String>> bulkQuotes,
    required void Function(int index) onSelectBulkIndex,
  }) async {
    final aspect = quoteCardAspectForIndex(selectedAspectIndex);

    try {
      if (isBulkMode && bulkQuotes.isNotEmpty) {
        final int total = bulkQuotes.length;
        final ValueNotifier<int> savedCount = ValueNotifier<int>(0);

        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ValueListenableBuilder<int>(
            valueListenable: savedCount,
            builder: (__, count, _) => AlertDialog(
              title: const Text('Generating Posts'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: count / total),
                  const SizedBox(height: 16),
                  Text('Generated $count of $total posts...'),
                ],
              ),
            ),
          ),
        );

        try {
          for (int i = 0; i < total; i++) {
            onSelectBulkIndex(i);
            await Future<void>.delayed(const Duration(milliseconds: 150));
            await ImageGenerator.savePostToGallery(
              text: '',
              templateKey: previewKey,
              outputWidth: aspect.exportWidth,
              outputHeight: aspect.exportHeight,
            );
            savedCount.value = i + 1;
          }
        } finally {
          savedCount.dispose();
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        if (!context.mounted) return;
        _showSuccessSnackBar(context, '$total posts saved to gallery!');
        AnalyticsService().logSaveAction(
          feature: 'quote_card_bulk',
          type: 'image',
        );
        AdService().showInterstitialAd();
        AppReviewService().requestReview();
        return;
      }

      final result = await ImageGenerator.savePostToGallery(
        text: '',
        templateKey: previewKey,
        outputWidth: aspect.exportWidth,
        outputHeight: aspect.exportHeight,
      );
      if (result != null && context.mounted) {
        _showSuccessSnackBar(context, 'Saved to gallery!');
        AnalyticsService().logSaveAction(
          feature: 'quote_card',
          type: 'image',
        );
        AdService().showInterstitialAd();
        AppReviewService().requestReview();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

