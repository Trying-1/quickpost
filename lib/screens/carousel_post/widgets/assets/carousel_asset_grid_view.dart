import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/carousel_image_asset.dart';
import '../../services/carousel_asset_storage_service.dart';

/// Grid view displaying image assets with action menus and thumbnail previews.
class CarouselAssetGridView extends StatelessWidget {
  final List<CarouselImageAsset> assets;
  final ValueChanged<CarouselImageAsset> onSelectAsset;
  final VoidCallback onRefresh;
  final VoidCallback onUploadPressed;
  final List<String> allCategories;

  const CarouselAssetGridView({
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
                'Upload images from gallery and organize them by topic/category.',
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
            final file = File(asset.localPath);

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
                      if (file.existsSync())
                        Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(Icons.image_not_supported_rounded, size: 28, color: Colors.grey),
                        ),
                      // Top gradient with category tag
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black54, Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Text(
                            asset.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Bottom gradient with name and delete button
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  asset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await CarouselAssetStorageService.instance.deleteAsset(asset.id);
                                  onRefresh();
                                },
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
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
}

