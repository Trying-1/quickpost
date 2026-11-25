import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../models/carousel_slide.dart';

/// Modal bottom sheet allowing visual drag-and-drop rearrangement of background images
/// across all carousel slides when images are mismatched.
class ImageReorderSheet extends StatefulWidget {
  final List<CarouselSlide> slides;
  final ValueChanged<List<String?>> onApplyReorderedImages;

  const ImageReorderSheet({
    super.key,
    required this.slides,
    required this.onApplyReorderedImages,
  });

  static Future<void> show({
    required BuildContext context,
    required List<CarouselSlide> slides,
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
                  ),
                  child: const Text('Apply Changes'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Reorderable List
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.slides.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final slide = widget.slides[index];
                final imgPath = _imagePaths[index];
                final hasImage = imgPath != null && File(imgPath).existsSync();

                return Container(
                  key: ValueKey('slide_reorder_${slide.id}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Slide badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Image preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: hasImage
                            ? Image.file(
                                File(imgPath),
                                width: 45,
                                height: 45,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 45,
                                height: 45,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported_rounded, size: 20, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Slide Title info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.type == SlideType.cover
                                  ? (slide.coverTitle.isNotEmpty ? slide.coverTitle : 'Cover Slide')
                                  : (slide.type == SlideType.cta
                                      ? (slide.ctaHeadline.isNotEmpty ? slide.ctaHeadline : 'CTA Outro')
                                      : (slide.title.isNotEmpty ? slide.title : 'Slide #${slide.slideNumber}')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              hasImage ? 'Image assigned' : 'No image assigned',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasImage ? Colors.green.shade700 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                    ],
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

