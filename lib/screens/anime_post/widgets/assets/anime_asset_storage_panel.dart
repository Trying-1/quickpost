import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_carousel_slide.dart';
import '../../models/anime_image_asset.dart';
import '../../services/anime_asset_storage_service.dart';
import 'anime_asset_category_ribbon.dart';
import 'anime_asset_library_sheet.dart';
import 'anime_asset_upload_dialog.dart';

/// Dedicated bottom dock panel for Image Asset Storage (Tab 14).
/// Provides fast 1-tap image selection, anime category filtering, search,
/// upload, and expand-to-fullscreen library inside the 230px drawer.
class AnimeAssetStoragePanel extends StatefulWidget {
  final AnimeCarouselSlide activeSlide;
  final List<AnimeCarouselSlide>? allSlides;
  final ValueChanged<String> onSelectImage;
  final VoidCallback onOpenFullLibrary;
  final VoidCallback? onAutoMatchSlides;
  final void Function(String message, {bool isError, bool isSuccess})? onShowToast;

  const AnimeAssetStoragePanel({
    super.key,
    required this.activeSlide,
    this.allSlides,
    required this.onSelectImage,
    required this.onOpenFullLibrary,
    this.onAutoMatchSlides,
    this.onShowToast,
  });

  @override
  State<AnimeAssetStoragePanel> createState() => _AnimeAssetStoragePanelState();
}

class _AnimeAssetStoragePanelState extends State<AnimeAssetStoragePanel> {
  final TextEditingController _searchController = TextEditingController();
  List<AnimeImageAsset> _allAssets = [];
  List<String> _categories = [];
  Map<String, int> _counts = {};
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = AnimeAssetStorageService.instance;
    final categories = await service.getCategories();
    final counts = await service.getCategoryCounts();
    final assets = await service.getAssets();

    if (mounted) {
      setState(() {
        _categories = categories;
        _counts = counts;
        _allAssets = assets;
        _isLoading = false;
      });
    }
  }

  List<AnimeImageAsset> get _filteredAssets {
    return _allAssets.where((asset) {
      if (_selectedCategory != 'All' &&
          asset.animeName.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesAnime = asset.animeName.toLowerCase().contains(query);
        final matchesName = asset.displayName.toLowerCase().contains(query);
        if (!matchesAnime && !matchesName) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openUploadDialog() async {
    final suggestions = widget.allSlides
        ?.where((s) => s.type == SlideType.anime)
        .map((s) => s.animeName)
        .toList();

    final imported = await AnimeAssetUploadDialog.show(
      context,
      initialCategory: _selectedCategory == 'All'
          ? (widget.activeSlide.type == SlideType.anime ? widget.activeSlide.animeName : 'General')
          : _selectedCategory,
      suggestedAnimeNames: suggestions,
    );
    if (imported != null && imported.isNotEmpty) {
      await _loadData();
    }
  }

  Future<void> _exportBackup() async {
    if (_allAssets.isEmpty) {
      widget.onShowToast?.call('No assets to export', isError: true);
      return;
    }
    final path = await AnimeAssetStorageService.instance.exportAssetsToZip(share: true);
    if (path != null) {
      widget.onShowToast?.call('Backup saved to Downloads/Quick Post Backup', isSuccess: true);
    }
  }

  Future<void> _importBackup() async {
    try {
      final count = await AnimeAssetStorageService.instance.importAssetsFromZip();
      if (count > 0) {
        await _loadData();
      }
    } catch (e) {
      // Import error silently handled
    }
  }

  void _addNewCategory() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Anime Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Chainsaw Man, Vinland Saga...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                await AnimeAssetStorageService.instance.addCategory(name);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
                setState(() => _selectedCategory = name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;

    return Column(
      children: [
        // Top Toolbar (Fully responsive)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Assets',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allAssets.length}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Search Toggle Button
              IconButton(
                icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, size: 18),
                tooltip: _showSearch ? 'Close Search' : 'Search Images',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),

              // Auto-Match Slides Button
              if (widget.onAutoMatchSlides != null) ...[
                InkWell(
                  onTap: widget.onAutoMatchSlides,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Auto-Match', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Upload Button
              InkWell(
                onTap: _openUploadDialog,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Upload', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 2),

              // Backup / Restore Menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                tooltip: 'Backup / Restore',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.cloud_download_outlined, size: 16, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text('Export Backup (ZIP)', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Restore from ZIP', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'export') _exportBackup();
                  if (val == 'import') _importBackup();
                },
              ),

              // Fullscreen / Modal expander
              IconButton(
                icon: const Icon(Icons.open_in_full_rounded, size: 16, color: Colors.indigo),
                tooltip: 'Open Full Library',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final path = await AnimeAssetLibrarySheet.show(context, initialCategory: _selectedCategory);
                  if (path != null) {
                    widget.onSelectImage(path);
                  }
                  _loadData();
                },
              ),
            ],
          ),
        ),

        // Search Input Field (when toggled)
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search anime or image name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.clear_rounded, size: 14, color: Colors.grey),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

        // Category Ribbon
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AnimeAssetCategoryRibbon(
            categories: _categories,
            selectedCategory: _selectedCategory,
            counts: _counts,
            onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
            onAddCategory: _addNewCategory,
          ),
        ),

        const Divider(height: 1, thickness: 1),

        // Thumbnails Scroll View (Height adapted for 230px dock drawer)
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      scrollDirection: Axis.horizontal,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final asset = filtered[index];
                        final isApplied = widget.activeSlide.imagePath == asset.filePath;

                        return InkWell(
                          onTap: () => widget.onSelectImage(asset.filePath),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isApplied ? AppColors.primary : Colors.grey.shade300,
                                width: isApplied ? 2.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6.5),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(asset.filePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                    ),
                                  ),
                                  if (isApplied)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 3),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [Colors.black87, Colors.transparent],
                                        ),
                                      ),
                                      child: Text(
                                        asset.animeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 24, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'No images in ${_selectedCategory == 'All' ? 'library' : _selectedCategory}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _openUploadDialog,
              icon: const Icon(Icons.add, size: 12),
              label: const Text('Add Images', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
