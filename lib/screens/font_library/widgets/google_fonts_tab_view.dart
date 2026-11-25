import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/google_font_model.dart';
import '../../../services/google_font_service.dart';
import '../../../services/favorite_fonts_manager.dart';
import 'google_font_card.dart';

class GoogleFontsTabView extends StatefulWidget {
  final String searchQuery;
  final String previewText;
  final Color textColor;
  final Color cardBg;
  final ValueChanged<GoogleFontItem>? onFontSelected;

  const GoogleFontsTabView({
    super.key,
    required this.searchQuery,
    required this.previewText,
    this.textColor = Colors.black87,
    this.cardBg = Colors.white,
    this.onFontSelected,
  });

  @override
  State<GoogleFontsTabView> createState() => _GoogleFontsTabViewState();
}

class _GoogleFontsTabViewState extends State<GoogleFontsTabView> {
  String _selectedCategory = 'All';
  bool _showOnlyDownloaded = false;
  bool _showOnlyFavorites = false;

  final List<String> _categories = [
    'All',
    'Display',
    'Gaming',
    'Sans',
    'Script',
    'Serif',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GoogleFontService(),
      builder: (context, _) {
        final fontService = GoogleFontService();
        final allCatalog = fontService.catalog;

        final filtered = allCatalog.where((item) {
          // Category filter
          if (_selectedCategory != 'All' &&
              item.category.toLowerCase() != _selectedCategory.toLowerCase()) {
            return false;
          }
          // Downloaded filter
          if (_showOnlyDownloaded && !fontService.isDownloaded(item.family)) {
            return false;
          }
          // Favorites filter
          if (_showOnlyFavorites && !FavoriteFontsManager().isFavorite(item.family)) {
            return false;
          }
          // Search query
          if (widget.searchQuery.isNotEmpty) {
            final q = widget.searchQuery.toLowerCase();
            final matchesFamily = item.family.toLowerCase().contains(q);
            final matchesCategory = item.category.toLowerCase().contains(q);
            final matchesTags = item.tags.any((t) => t.toLowerCase().contains(q));
            if (!matchesFamily && !matchesCategory && !matchesTags) {
              return false;
            }
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Category & Downloaded toggle filters
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Favorites toggle chip
                    AnimatedBuilder(
                      animation: FavoriteFontsManager(),
                      builder: (context, _) {
                        final favCount = FavoriteFontsManager().count;
                        return FilterChip(
                          selected: _showOnlyFavorites,
                          label: Text(
                            'Favorites ($favCount)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _showOnlyFavorites ? Colors.redAccent : Colors.black87,
                            ),
                          ),
                          avatar: Icon(
                            _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
                            size: 15,
                            color: _showOnlyFavorites ? Colors.redAccent : Colors.grey[600],
                          ),
                          backgroundColor: Colors.grey[100],
                          selectedColor: Colors.red[50],
                          checkmarkColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(
                            color: _showOnlyFavorites ? Colors.redAccent : Colors.grey[300]!,
                          ),
                          onSelected: (val) {
                            setState(() => _showOnlyFavorites = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Downloaded Only toggle chip
                    FilterChip(
                      selected: _showOnlyDownloaded,
                      label: Text(
                        'Downloaded (${fontService.downloadedFonts.length})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _showOnlyDownloaded ? AppColors.primary : Colors.black87,
                        ),
                      ),
                      avatar: Icon(
                        _showOnlyDownloaded ? Icons.check_circle : Icons.cloud_done_outlined,
                        size: 15,
                        color: _showOnlyDownloaded ? AppColors.primary : Colors.grey[600],
                      ),
                      backgroundColor: Colors.grey[100],
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(
                        color: _showOnlyDownloaded ? AppColors.primary : Colors.grey[300]!,
                      ),
                      onSelected: (val) {
                        setState(() => _showOnlyDownloaded = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    // Categories
                    ..._categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : Colors.black87,
                            ),
                          ),
                          backgroundColor: Colors.grey[100],
                          selectedColor: AppColors.primaryLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedCategory = cat);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Action bar with font count and Download All button
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} fonts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (fontService.isBatchDownloading) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Downloading ${fontService.batchCompleted}/${fontService.batchTotal}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: fontService.cancelBatchDownload,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ] else if (filtered.any((f) => !fontService.isDownloaded(f.family))) ...[
                    ElevatedButton.icon(
                      onPressed: () => fontService.downloadAll(fontList: filtered),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_for_offline_outlined, size: 15),
                      label: Text(
                        'Download All (${filtered.where((f) => !fontService.isDownloaded(f.family)).length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'All Downloaded',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (fontService.isBatchDownloading)
              LinearProgressIndicator(
                value: fontService.batchTotal > 0
                    ? fontService.batchCompleted / fontService.batchTotal
                    : null,
                minHeight: 2.5,
                backgroundColor: AppColors.primaryLight,
                color: AppColors.primary,
              ),

            // Content list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.font_download_off_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            _showOnlyDownloaded ? 'No downloaded Google Fonts yet' : 'No matching Google Fonts',
                            style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _showOnlyDownloaded
                                ? 'Tap "Download" on any font to install it on-demand.'
                                : 'Try searching for another style (e.g. bold, handwriting, comic)',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final font = filtered[index];
                        return GoogleFontCard(
                          font: font,
                          previewText: widget.previewText,
                          textColor: widget.textColor,
                          cardBg: widget.cardBg,
                          onSelect: widget.onFontSelected != null
                              ? () => widget.onFontSelected!(font)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

