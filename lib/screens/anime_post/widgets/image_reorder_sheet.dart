import 'dart:io';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../models/anime_carousel_slide.dart';

/// Modal bottom sheet allowing visual drag-and-drop rearrangement of background images
/// across all carousel slides when images are mismatched.
class ImageReorderSheet extends StatefulWidget {
  final List<AnimeCarouselSlide> slides;
  final ValueChanged<List<String?>> onApplyReorderedImages;

  const ImageReorderSheet({
    super.key,
    required this.slides,
    required this.onApplyReorderedImages,
  });

  static Future<void> show({
    required BuildContext context,
    required List<AnimeCarouselSlide> slides,
    required ValueChanged<List<String?>> onApplyReorderedImages,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImageReorderSheet(
        slides: slides,
        onApplyReorderedImages: onApplyReorderedImages,
      ),
    );
  }

  @override
  State<ImageReorderSheet> createState() => _ImageReorderSheetState();
}

class _ImageReorderSheetState extends State<ImageReorderSheet> {
  late List<String?> _imagePaths;

  @override
  void initState() {
    super.initState();
    _imagePaths = widget.slides.map((s) => s.imagePath).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _imagePaths.removeAt(oldIndex);
      _imagePaths.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rearrange Slide Images',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Drag images up/down to match respective slides',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onApplyReorderedImages(_imagePaths);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                  ),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1),

          // Reorderable list
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: widget.slides.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final slide = widget.slides[index];
                final imagePath = _imagePaths[index];
                final hasImage = imagePath != null && File(imagePath).existsSync();

                String slideTitle;
                if (slide.type == SlideType.cover) {
                  slideTitle = 'Slide ${index + 1}: Cover (${slide.coverTitle})';
                } else if (slide.type == SlideType.cta) {
                  slideTitle = 'Slide ${index + 1}: CTA Outro';
                } else {
                  slideTitle = 'Slide ${index + 1}: #${slide.rank} ${slide.animeName}';
                }

                return Card(
                  key: ValueKey('reorder_${slide.id}_$index'),
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        // Drag Handle
                        ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Image Preview Thumbnail
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasImage
                              ? Image.file(
                                  File(imagePath),
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey.shade400,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),

                        // Slide Name & Assigned Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slideTitle,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hasImage
                                    ? 'Image assigned: ${imagePath.split('/').last}'
                                    : 'No image assigned',
                                style: TextStyle(
                                  color: hasImage ? AppColors.primary : Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Quick Clear / Remove button
                        if (hasImage)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            tooltip: 'Clear image',
                            onPressed: () {
                              setState(() {
                                _imagePaths[index] = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
