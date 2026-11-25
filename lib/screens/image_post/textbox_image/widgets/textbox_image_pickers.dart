import 'dart:io';

import 'package:flutter/material.dart';

/// Image picker tab for Single Image mode in [TextboxImageScreen].
class SingleTextboxImagePickerTab extends StatelessWidget {
  final File? selectedImage;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  const SingleTextboxImagePickerTab({
    super.key,
    required this.selectedImage,
    required this.onPickImage,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: selectedImage != null
                    ? Image.file(
                        selectedImage!,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            Icons.add_photo_alternate,
                            color: Colors.grey[600],
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            if (selectedImage != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onClearImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 2x2 grid slot picker + bulk pick/clear actions for Grid mode in [TextboxImageScreen].
class GridTextboxImagesPickerTab extends StatelessWidget {
  final List<File?> gridImages;
  final ValueChanged<int> onPickGridImage;
  final ValueChanged<int> onClearGridSlot;
  final VoidCallback onPickAllGridImages;
  final VoidCallback onClearAllGridImages;

  const GridTextboxImagesPickerTab({
    super.key,
    required this.gridImages,
    required this.onPickGridImage,
    required this.onClearGridSlot,
    required this.onPickAllGridImages,
    required this.onClearAllGridImages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 4,
            itemBuilder: (_, index) {
              final image = gridImages[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => onPickGridImage(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: image != null
                            ? Image.file(
                                image,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.grey[600],
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (image != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onClearGridSlot(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}',
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
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                onPressed: onPickAllGridImages,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  elevation: 0,
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, size: 24),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                onPressed: onClearAllGridImages,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[700],
                  elevation: 0,
                ),
                child: const Icon(Icons.delete_outline, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

