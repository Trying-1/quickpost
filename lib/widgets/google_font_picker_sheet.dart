import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/google_font_model.dart';
import '../services/google_font_service.dart';
import '../screens/font_library/widgets/google_font_card.dart';

/// Modal bottom sheet allowing users to browse, search, and download
/// Google fonts on-demand directly from any font picker interface.
class GoogleFontPickerSheet extends StatefulWidget {
  final ValueChanged<GoogleFontItem> onFontSelected;
  final String previewText;

  const GoogleFontPickerSheet({
    super.key,
    required this.onFontSelected,
    this.previewText = '',
  });

  static Future<GoogleFontItem?> show(BuildContext context, {String previewText = ''}) {
    return showModalBottomSheet<GoogleFontItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoogleFontPickerSheet(
        previewText: previewText,
        onFontSelected: (font) => Navigator.pop(ctx, font),
      ),
    );
  }

  @override
  State<GoogleFontPickerSheet> createState() => _GoogleFontPickerSheetState();
}

class _GoogleFontPickerSheetState extends State<GoogleFontPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Display',
    'Gaming',
    'Sans',
    'Script',
    'Serif',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontService = GoogleFontService();

    return AnimatedBuilder(
      animation: fontService,
      builder: (context, _) {
        final catalog = fontService.catalog;
        final filtered = catalog.where((item) {
          if (_selectedCategory != 'All' &&
              item.category.toLowerCase() != _selectedCategory.toLowerCase()) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchesFamily = item.family.toLowerCase().contains(q);
            final matchesCategory = item.category.toLowerCase().contains(q);
            final matchesTags = item.tags.any((t) => t.toLowerCase().contains(q));
            if (!matchesFamily && !matchesCategory && !matchesTags) {
              return false;
            }
          }
          return true;
        }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.font_download_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Google Fonts Library',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Download 90+ curated fonts on demand (${fontService.downloadedFonts.length} installed)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by font name or tag (e.g. bold, retro)...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // Categories row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primary : Colors.black87,
                          ),
                        ),
                        backgroundColor: Colors.grey[100],
                        selectedColor: AppColors.primaryLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(height: 12),

              // Action bar with count & Download All
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} fonts',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    if (fontService.isBatchDownloading) ...[
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      const SizedBox(width: 6),
                      Text(
                        '${fontService.batchCompleted}/${fontService.batchTotal}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: fontService.cancelBatchDownload,
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ] else if (filtered.any((f) => !fontService.isDownloaded(f.family))) ...[
                      ElevatedButton.icon(
                        onPressed: () => fontService.downloadAll(fontList: filtered),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.download_for_offline_outlined, size: 14),
                        label: Text(
                          'Download All (${filtered.where((f) => !fontService.isDownloaded(f.family)).length})',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 13, color: Colors.green),
                          SizedBox(width: 4),
                          Text('All Downloaded', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (fontService.isBatchDownloading)
                LinearProgressIndicator(
                  value: fontService.batchTotal > 0 ? fontService.batchCompleted / fontService.batchTotal : null,
                  minHeight: 2,
                  backgroundColor: AppColors.primaryLight,
                  color: AppColors.primary,
                ),

              // Fonts list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No fonts found',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final font = filtered[index];
                          final isDownloaded = fontService.isDownloaded(font.family);

                          return GoogleFontCard(
                            font: font,
                            previewText: widget.previewText,
                            textColor: Colors.black87,
                            cardBg: Colors.white,
                            onSelect: isDownloaded
                                ? () => widget.onFontSelected(font)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

