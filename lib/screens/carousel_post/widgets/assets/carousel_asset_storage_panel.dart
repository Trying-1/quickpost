import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/carousel_slide.dart';
import '../../models/carousel_image_asset.dart';
import '../../services/carousel_asset_storage_service.dart';
import 'carousel_asset_category_ribbon.dart';
import 'carousel_asset_library_sheet.dart';
import 'carousel_asset_upload_dialog.dart';

/// Dedicated bottom dock panel for Image Asset Storage.
/// Provides fast 1-tap image selection, category filtering, search,
/// upload, and expand-to-fullscreen library inside the drawer.
class CarouselAssetStoragePanel extends StatefulWidget {
  final CarouselSlide activeSlide;
  final ValueChanged<String> onSelectImage;
  final VoidCallback onOpenFullLibrary;
  final void Function(String message, {bool isError, bool isSuccess})? onShowToast;

  const CarouselAssetStoragePanel({
    super.key,
    required this.activeSlide,
    required this.onSelectImage,
    required this.onOpenFullLibrary,
    this.onShowToast,
  });

  @override
  State<CarouselAssetStoragePanel> createState() => _CarouselAssetStoragePanelState();
}

class _CarouselAssetStoragePanelState extends State<CarouselAssetStoragePanel> {
  final TextEditingController _searchController = TextEditingController();
  List<CarouselImageAsset> _allAssets = [];
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
    final service = CarouselAssetStorageService.instance;
    final categories = await service.loadCategories();
    final assets = await service.loadAssets();

    final Map<String, int> counts = {'All': assets.length};
    for (final a in assets) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _counts = counts;
        _allAssets = assets;
        _isLoading = false;
      });
    }
  }

  List<CarouselImageAsset> get _filteredAssets {
    return _allAssets.where((asset) {
      if (_selectedCategory != 'All' &&
          asset.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesCat = asset.category.toLowerCase().contains(query);
        final matchesName = asset.name.toLowerCase().contains(query);
        if (!matchesCat && !matchesName) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openUploadDialog() async {
    final imported = await CarouselAssetUploadDialog.show(
      context,
      initialCategory: _selectedCategory == 'All' ? 'General' : _selectedCategory,
    );
    if (imported != null && imported.isNotEmpty) {
      await _loadData();
      widget.onShowToast?.call(
        'Added ${imported.length} image(s) to ${imported.first.category}!',
        isSuccess: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_allAssets.length} Stored Images',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, size: 20),
                tooltip: 'Search',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 20, color: AppColors.primary),
                tooltip: 'Upload Images',
                onPressed: _openUploadDialog,
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, size: 22),
                tooltip: 'Open Full Library',
                onPressed: widget.onOpenFullLibrary,
              ),
            ],
          ),
        ),

        // Search field if visible
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search topic or image...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

        // Category Ribbon
        CarouselAssetCategoryRibbon(
          categories: _categories,
          selectedCategory: _selectedCategory,
          counts: _counts,
          onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
          onAddCategory: _openUploadDialog,
        ),
        const SizedBox(height: 8),

        // Horizontal Image Strip
        SizedBox(
          height: 100,
          child: _filteredAssets.isEmpty
              ? Center(
                  child: Text(
                    'No images in $_selectedCategory',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredAssets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final asset = _filteredAssets[index];
                    final file = File(asset.localPath);
                    final isCurrentSlideImage = widget.activeSlide.imagePath == asset.localPath;

                    return GestureDetector(
                      onTap: () => widget.onSelectImage(asset.localPath),
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrentSlideImage ? AppColors.primary : Colors.grey.shade300,
                            width: isCurrentSlideImage ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (file.existsSync())
                                Image.file(file, fit: BoxFit.cover)
                              else
                                const Center(child: Icon(Icons.broken_image_rounded, size: 20)),
                              if (isCurrentSlideImage)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
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
}

