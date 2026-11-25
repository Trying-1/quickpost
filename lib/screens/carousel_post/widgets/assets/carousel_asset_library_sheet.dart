import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/carousel_image_asset.dart';
import '../../services/carousel_asset_storage_service.dart';
import 'carousel_asset_category_ribbon.dart';
import 'carousel_asset_grid_view.dart';
import 'carousel_asset_upload_dialog.dart';

/// Modal bottom sheet providing a full-featured Image Asset Storage interface:
/// - "All Images" view with total counts and instant search
/// - "By Topic" categorized view with custom topic groups
/// - Import and Export of labeled image assets to .zip (surviving uninstall & reinstall)
/// - 1-tap image selection for Carousel Post slides
class CarouselAssetLibrarySheet extends StatefulWidget {
  final String? initialCategory;

  const CarouselAssetLibrarySheet({
    super.key,
    this.initialCategory,
  });

  static Future<String?> show(BuildContext context, {String? initialCategory}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CarouselAssetLibrarySheet(initialCategory: initialCategory),
    );
  }

  @override
  State<CarouselAssetLibrarySheet> createState() => _CarouselAssetLibrarySheetState();
}

class _CarouselAssetLibrarySheetState extends State<CarouselAssetLibrarySheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<CarouselImageAsset> _allAssets = [];
  List<String> _categories = [];
  Map<String, int> _counts = {};
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isProcessingBackup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialCategory != null &&
        widget.initialCategory!.isNotEmpty &&
        widget.initialCategory != 'All') {
      _selectedCategory = widget.initialCategory!;
      _tabController.index = 1;
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  List<CarouselImageAsset> get _allImagesFiltered {
    if (_searchQuery.trim().isEmpty) return _allAssets;
    final query = _searchQuery.trim().toLowerCase();
    return _allAssets.where((asset) {
      final matchesCat = asset.category.toLowerCase().contains(query);
      final matchesName = asset.name.toLowerCase().contains(query);
      return matchesCat || matchesName;
    }).toList();
  }

  List<CarouselImageAsset> get _byCategoryFiltered {
    return _allAssets.where((asset) {
      if (_selectedCategory != 'All' &&
          asset.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesCat = asset.category.toLowerCase().contains(query);
        final matchesName = asset.name.toLowerCase().contains(query);
        return matchesCat || matchesName;
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
    }
  }

  Future<void> _exportZip() async {
    setState(() => _isProcessingBackup = true);
    try {
      final path = await CarouselAssetStorageService.instance.exportAssetsToZip();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to $path'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _importZip() async {
    setState(() => _isProcessingBackup = true);
    try {
      final count = await CarouselAssetStorageService.instance.importAssetsFromZip();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $count image asset(s) successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Carousel Asset Storage',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Backup to ZIP',
                  icon: const Icon(Icons.upload_file_rounded, size: 20),
                  onPressed: _isProcessingBackup ? null : _exportZip,
                ),
                IconButton(
                  tooltip: 'Restore from ZIP',
                  icon: const Icon(Icons.download_rounded, size: 20),
                  onPressed: _isProcessingBackup ? null : _importZip,
                ),
                IconButton(
                  tooltip: 'Upload Images',
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
                  onPressed: _openUploadDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search topic or image name...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'All Images'),
              Tab(text: 'By Category'),
            ],
          ),
          // Tab Bar View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      CarouselAssetGridView(
                        assets: _allImagesFiltered,
                        allCategories: _categories,
                        onRefresh: _loadData,
                        onUploadPressed: _openUploadDialog,
                        onSelectAsset: (asset) => Navigator.pop(context, asset.localPath),
                      ),
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          CarouselAssetCategoryRibbon(
                            categories: _categories,
                            selectedCategory: _selectedCategory,
                            counts: _counts,
                            onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                            onAddCategory: () async {
                              final imported = await CarouselAssetUploadDialog.show(context);
                              if (imported != null) _loadData();
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: CarouselAssetGridView(
                              assets: _byCategoryFiltered,
                              allCategories: _categories,
                              onRefresh: _loadData,
                              onUploadPressed: _openUploadDialog,
                              onSelectAsset: (asset) => Navigator.pop(context, asset.localPath),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

