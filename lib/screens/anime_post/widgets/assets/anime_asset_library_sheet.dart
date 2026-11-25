import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_image_asset.dart';
import '../../services/anime_asset_storage_service.dart';
import 'anime_asset_category_ribbon.dart';
import 'anime_asset_grid_view.dart';
import 'anime_asset_tagging_tab.dart';
import 'anime_asset_upload_dialog.dart';

/// Modal bottom sheet providing a full-featured Image Asset Storage interface:
/// - "All Images" view with total counts and instant search
/// - "By Anime" categorized view with custom anime groups
/// - Import and Export of labeled image assets to .zip (surviving uninstall & reinstall)
/// - 1-tap image selection for Anime Post slides
class AnimeAssetLibrarySheet extends StatefulWidget {
  final String? initialCategory;
  final List<String>? suggestedAnimeNames;

  const AnimeAssetLibrarySheet({
    super.key,
    this.initialCategory,
    this.suggestedAnimeNames,
  });

  /// Opens the Anime Asset Storage library sheet and returns the selected image path (or null)
  static Future<String?> show(
    BuildContext context, {
    String? initialCategory,
    List<String>? suggestedAnimeNames,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimeAssetLibrarySheet(
        initialCategory: initialCategory,
        suggestedAnimeNames: suggestedAnimeNames,
      ),
    );
  }

  @override
  State<AnimeAssetLibrarySheet> createState() => _AnimeAssetLibrarySheetState();
}

class _AnimeAssetLibrarySheetState extends State<AnimeAssetLibrarySheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<AnimeImageAsset> _allAssets = [];
  List<String> _categories = [];
  Map<String, int> _counts = {};
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isProcessingBackup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialCategory != null &&
        widget.initialCategory!.isNotEmpty &&
        widget.initialCategory != 'All') {
      _selectedCategory = widget.initialCategory!;
      _tabController.index = 1; // Switch to "By Anime" tab
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
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

  List<AnimeImageAsset> get _allImagesFiltered {
    if (_searchQuery.trim().isEmpty) return _allAssets;
    final query = _searchQuery.trim().toLowerCase();
    return _allAssets.where((asset) {
      final matchesAnime = asset.animeName.toLowerCase().contains(query);
      final matchesName = asset.displayName.toLowerCase().contains(query);
      return matchesAnime || matchesName;
    }).toList();
  }

  List<AnimeImageAsset> get _byAnimeFiltered {
    return _allAssets.where((asset) {
      // Category filter
      if (_selectedCategory != 'All' &&
          asset.animeName.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      // Search filter
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
    final targetCategory = _tabController.index == 1 && _selectedCategory != 'All'
        ? _selectedCategory
        : 'General';

    final imported = await AnimeAssetUploadDialog.show(
      context,
      initialCategory: targetCategory,
      suggestedAnimeNames: widget.suggestedAnimeNames,
    );
    if (imported != null && imported.isNotEmpty) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added ${imported.length} image(s) to ${imported.first.animeName}!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // BACKUP & RESTORE ACTIONS
  // ===========================================================================

  Future<void> _exportBackup() async {
    if (_allAssets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image assets found to export.')),
      );
      return;
    }

    setState(() => _isProcessingBackup = true);
    try {
      final exportPath = await AnimeAssetStorageService.instance.exportAssetsToZip(share: true);
      if (mounted) {
        setState(() => _isProcessingBackup = false);
        if (exportPath != null) {
          final fileName = exportPath.split('/').last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported backup: $fileName to Downloads/Quick Post Backup/Anime Assets/'),
              backgroundColor: Colors.indigo.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingBackup = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importBackup({String? specificZipPath}) async {
    setState(() => _isProcessingBackup = true);
    try {
      final count = await AnimeAssetStorageService.instance.importAssetsFromZip(
        specificZipPath: specificZipPath,
      );
      if (mounted) {
        setState(() => _isProcessingBackup = false);
        if (count > 0) {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restored $count labeled images with anime categories!'),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else if (specificZipPath == null) {
          // User cancelled file picker
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingBackup = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRestoreOptionsDialog() async {
    final existingBackups = await AnimeAssetStorageService.getExistingBackups();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Restore Labeled Images Backup',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_open_rounded, color: AppColors.primary),
                title: const Text('Pick Backup ZIP from Files...'),
                subtitle: const Text('Select a .zip backup from your device or cloud'),
                onTap: () {
                  Navigator.pop(ctx);
                  _importBackup();
                },
              ),
              if (existingBackups.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Found in Downloads/Quick Post Backup:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                ...existingBackups.take(3).map((file) {
                  final name = file.path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.restore_page_rounded, color: Colors.indigo),
                    title: Text(name, style: const TextStyle(fontSize: 12.5)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      _importBackup(specificZipPath: file.path);
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
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

  Future<void> _deleteCategory(String category) async {
    await AnimeAssetStorageService.instance.deleteCategory(category);
    await _loadData();
    if (_selectedCategory == category) {
      setState(() => _selectedCategory = 'All');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Anime Asset Storage',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_allAssets.length} images · ${_categories.length} animes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Upload Button
                ElevatedButton.icon(
                  onPressed: _openUploadDialog,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 13),
                  label: const Text('Upload', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    elevation: 0,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                // Backup & Restore Popup Menu
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: _isProcessingBackup
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                  tooltip: 'Backup & Restore Options',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.cloud_download_outlined, size: 18, color: Colors.indigo),
                          SizedBox(width: 10),
                          Text('Export All (Backup ZIP)', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.green),
                          SizedBox(width: 10),
                          Text('Import from ZIP (Restore)', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'restore_downloads',
                      child: Row(
                        children: [
                          Icon(Icons.folder_zip_outlined, size: 18, color: Colors.deepOrange),
                          SizedBox(width: 10),
                          Text('Restore from Downloads...', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'export') {
                      _exportBackup();
                    } else if (val == 'import') {
                      _importBackup();
                    } else if (val == 'restore_downloads') {
                      _showRestoreOptionsDialog();
                    }
                  },
                ),

                // Close Button
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Top Tab Bar: [All Images] & [By Anime]
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'All Images (${_allAssets.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'By Anime (${_categories.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.label_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Tagging (${_allAssets.where(AnimeAssetTaggingTab.isUntagged).length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onTap: (_) => setState(() {}),
            ),
          ),

          // Universal Search Bar
          if (_tabController.index != 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? 'Search all images across animes...'
                    : 'Search in ${_selectedCategory == 'All' ? 'all animes' : _selectedCategory}...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Category Ribbon (Displayed in "By Anime" Tab)
          if (_tabController.index == 1) ...[
            AnimeAssetCategoryRibbon(
              categories: _categories,
              selectedCategory: _selectedCategory,
              counts: _counts,
              onSelectCategory: (cat) {
                setState(() => _selectedCategory = cat);
              },
              onAddCategory: _addNewCategory,
              onDeleteCategory: _deleteCategory,
            ),
            const SizedBox(height: 6),
          ],

          const Divider(height: 1, thickness: 1),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: ALL IMAGES
                      _buildAllImagesTab(),

                      // TAB 2: BY ANIME CATEGORY
                      _buildByAnimeTab(),

                      // TAB 3: TAGGING
                      AnimeAssetTaggingTab(
                        assets: _allAssets,
                        categories: _categories,
                        suggestedAnimeNames: widget.suggestedAnimeNames ?? const [],
                        onChanged: () => _loadData(silent: true),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllImagesTab() {
    final assets = _allImagesFiltered;

    if (assets.isEmpty && _allAssets.isEmpty) {
      return _buildEmptyState();
    }

    if (assets.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No images matching "$_searchQuery"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Text('Clear Search Filter'),
              ),
            ],
          ),
        ),
      );
    }

    return AnimeAssetGridView(
      assets: assets,
      allCategories: _categories,
      onSelectAsset: (asset) {
        Navigator.of(context).pop(asset.filePath);
      },
      onRefresh: _loadData,
      onUploadPressed: _openUploadDialog,
    );
  }

  Widget _buildByAnimeTab() {
    final assets = _byAnimeFiltered;

    if (assets.isEmpty && _allAssets.isEmpty) {
      return _buildEmptyState();
    }

    return AnimeAssetGridView(
      assets: assets,
      allCategories: _categories,
      onSelectAsset: (asset) {
        Navigator.of(context).pop(asset.filePath);
      },
      onRefresh: _loadData,
      onUploadPressed: _openUploadDialog,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.collections_bookmark_rounded, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Saved Images in Library',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your anime photos from gallery or restore a previous .zip backup after reinstallation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _openUploadDialog,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('Upload Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showRestoreOptionsDialog,
                  icon: const Icon(Icons.restore_page_rounded, size: 16, color: Colors.indigo),
                  label: const Text('Restore ZIP Backup', style: TextStyle(color: Colors.indigo)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    side: BorderSide(color: Colors.indigo.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
