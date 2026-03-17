import 'dart:io';

import 'package:flutter/material.dart';

class ImageTemplateSection extends StatelessWidget {
  final bool isGridMode;
  final bool isPreviewReady;
  final File? selectedImage;
  final List<File?> gridImages;
  final VoidCallback onSave;
  final VoidCallback onPickSingleImage;
  final VoidCallback onPickAllGridImages;
  final VoidCallback onClearAllGridImages;
  final Widget singlePreview;
  final Widget gridPreview;

  const ImageTemplateSection({
    super.key,
    required this.isGridMode,
    required this.isPreviewReady,
    required this.selectedImage,
    required this.gridImages,
    required this.onSave,
    required this.onPickSingleImage,
    required this.onPickAllGridImages,
    required this.onClearAllGridImages,
    required this.singlePreview,
    required this.gridPreview,
  });

  bool get _hasAnyImage =>
      selectedImage != null || gridImages.any((img) => img != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: Colors.blue[600], size: 24),
              const SizedBox(width: 12),
              Text(
                isGridMode ? '2x2 Grid' : 'Image',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _hasAnyImage && isPreviewReady ? onSave : null,
                icon: const Icon(Icons.save, size: 18),
                label: Text(
                  _hasAnyImage && !isPreviewReady ? 'Loading...' : 'Save',
                ),
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return Colors.green.shade600;
                  }),
                  foregroundColor:
                      MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade600;
                    }
                    return Colors.white;
                  }),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid action buttons (only for grid mode)
          if (isGridMode) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickAllGridImages,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Import All (4)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[300]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        gridImages.any((img) => img != null) ? onClearAllGridImages : null,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Image Preview
          isGridMode ? gridPreview : singlePreview,
        ],
      ),
    );
  }
}
