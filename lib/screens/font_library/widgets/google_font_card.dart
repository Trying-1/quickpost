import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/google_font_model.dart';
import '../../../services/google_font_service.dart';
import '../../../services/favorite_fonts_manager.dart';

class GoogleFontCard extends StatelessWidget {
  final GoogleFontItem font;
  final String previewText;
  final Color textColor;
  final Color cardBg;
  final VoidCallback? onSelect;

  const GoogleFontCard({
    super.key,
    required this.font,
    required this.previewText,
    this.textColor = Colors.black87,
    this.cardBg = Colors.white,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final fontService = GoogleFontService();
    final isDownloaded = fontService.isDownloaded(font.family);
    final isDownloading = fontService.isDownloading(font.family);
    final progress = fontService.getDownloadProgress(font.family);
    final isDarkBg = ThemeData.estimateBrightnessForColor(cardBg) == Brightness.dark;

    final String displayText = (previewText.trim().isNotEmpty &&
            previewText.trim().toLowerCase() != 'abc - the quick brown fox')
        ? previewText.trim()
        : font.family;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDownloaded
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isDarkBg ? Colors.white10 : Colors.grey[200]!),
          width: isDownloaded ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isDownloaded ? onSelect : () => fontService.downloadFont(font),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Favorite heart toggle button
                AnimatedBuilder(
                  animation: FavoriteFontsManager(),
                  builder: (context, _) {
                    final isFav = FavoriteFontsManager().isFavorite(font.family);
                    return InkWell(
                      onTap: () => FavoriteFontsManager().toggleFavorite(font.family),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFav ? Colors.redAccent : (isDarkBg ? Colors.white38 : Colors.grey[400]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Font family name or custom preview text in same row
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontFamily: isDownloaded ? font.family : 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                // Icon-only download / status action
                _buildActionButton(context, fontService, isDownloaded, isDownloading, progress, isDarkBg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    GoogleFontService fontService,
    bool isDownloaded,
    bool isDownloading,
    double progress,
    bool isDarkBg,
  ) {
    if (isDownloading) {
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 2.2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (isDownloaded) {
      final isPackaged = fontService.isAsset(font.family);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: isDarkBg ? 0.25 : 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.green),
          ),
          if (!isPackaged) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: isDarkBg ? Colors.red[300] : Colors.redAccent,
              ),
              tooltip: 'Remove',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => fontService.deleteFont(font.family),
            ),
          ],
        ],
      );
    }

    // Icon-only Download Button
    return InkWell(
      onTap: () => fontService.downloadFont(font),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.download_rounded,
          size: 19,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
