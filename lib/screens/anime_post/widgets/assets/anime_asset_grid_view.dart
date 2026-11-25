import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_image_asset.dart';
import '../../services/anime_asset_storage_service.dart';

/// Grid view displaying anime image assets with action menus and thumbnail previews.
class AnimeAssetGridView extends StatelessWidget {
  final List<AnimeImageAsset> assets;
  final ValueChanged<AnimeImageAsset> onSelectAsset;
  final VoidCallback onRefresh;
  final VoidCallback onUploadPressed;
  final List<String> allCategories;

  const AnimeAssetGridView({
    super.key,
    required this.assets,
    required this.onSelectAsset,
    required this.onRefresh,
    required this.onUploadPressed,
    required this.allCategories,
  });

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.collections_bookmark_outlined, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No images in this category yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload images from gallery and organize them by anime name.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onUploadPressed,
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('Upload Images Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount = width < 340
            ? 2
            : (width > 600 ? (width / 130).floor().clamp(4, 7) : 3);
        final double childAspectRatio = width < 340 ? 0.92 : 0.85;

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final file = File(asset.filePath);

            return InkWell(
              onTap: () => onSelectAsset(asset),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image Preview
                      Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 28, color: Colors.grey),
                          ),
                        ),
                      ),

                      // Bottom Gradient & Category Pill
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black87,
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            asset.animeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 3-dots Menu button
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 15,
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'select',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text('Apply to Slide', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'move',
                                child: Row(
                                  children: [
                                    Icon(Icons.drive_file_move_outlined, size: 16, color: Colors.blueAccent),
                                    SizedBox(width: 8),
                                    Text('Change Anime Category', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete Asset', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (action) {
                              if (action == 'select') {
                                onSelectAsset(asset);
                              } else if (action == 'move') {
                                _showMoveCategoryDialog(context, asset);
                              } else if (action == 'delete') {
                                _confirmDelete(context, asset);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMoveCategoryDialog(BuildContext context, AnimeImageAsset asset) {
    String selectedCategory = asset.animeName;
    final textController = TextEditingController();
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Move Anime Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Move "${asset.displayName}" to another anime group:',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (isCustom)
                TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter anime name...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: allCategories.contains(selectedCategory)
                          ? selectedCategory
                          : (allCategories.isNotEmpty ? allCategories.first : 'General'),
                      items: allCategories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCategory = val);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() => isCustom = !isCustom);
                },
                child: Text(isCustom ? 'Choose existing anime' : '+ Create new anime category',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
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
                final targetName = isCustom ? textController.text.trim() : selectedCategory.trim();
                if (targetName.isNotEmpty) {
                  await AnimeAssetStorageService.instance.updateAssetCategory(asset.id, targetName);
                  if (ctx.mounted) Navigator.pop(ctx);
                  onRefresh();
                }
              },
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AnimeImageAsset asset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Image Asset?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this image from your local asset library? This will delete the permanent file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await AnimeAssetStorageService.instance.deleteAsset(asset.id);
              if (ctx.mounted) Navigator.pop(ctx);
              onRefresh();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
