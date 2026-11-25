import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/image_post_overlays.dart';
import '../image_post_shared_controls.dart';

/// Image Overlays tab panel (index 9): add, select, replace, scale/rotate/position CTA stickers.
class ImagePostOverlaysTab extends StatelessWidget {
  final List<ImagePostOverlayImage> imageOverlays;
  final int? selectedImageOverlayIndex;
  final ValueChanged<int?> onSelectedIndexChanged;
  final VoidCallback onStateChanged;

  const ImagePostOverlaysTab({
    super.key,
    required this.imageOverlays,
    required this.selectedImageOverlayIndex,
    required this.onSelectedIndexChanged,
    required this.onStateChanged,
  });

  Future<void> _addImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    imageOverlays.add(ImagePostOverlayImage(path: picked.path));
    onSelectedIndexChanged(imageOverlays.length - 1);
    onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Image Overlays',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: _addImage,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Add Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add images, GIFs, PNGs, or stickers for CTA overlays.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (imageOverlays.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No image overlays added.\nPick an image, GIF, or sticker to overlay.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (imageOverlays.isNotEmpty) ...[
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageOverlays.length,
              itemBuilder: (context, i) {
                final o = imageOverlays[i];
                final isSelected = selectedImageOverlayIndex == i;
                return GestureDetector(
                  onTap: () => onSelectedIndexChanged(i),
                  child: Container(
                    width: 58,
                    height: 58,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(o.path), fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (selectedImageOverlayIndex != null &&
            selectedImageOverlayIndex! >= 0 &&
            selectedImageOverlayIndex! < imageOverlays.length)
          _buildActiveControls(
            imageOverlays[selectedImageOverlayIndex!],
            selectedImageOverlayIndex!,
          )
        else if (imageOverlays.isNotEmpty)
          const Text(
            'Select an overlay on preview to edit',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildActiveControls(ImagePostOverlayImage o, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overlay #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        o.path = picked.path;
                        onStateChanged();
                      }
                    },
                    icon: const Icon(
                      Icons.swap_horiz,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                    tooltip: 'Replace Image',
                  ),
                  IconButton(
                    onPressed: () {
                      imageOverlays.removeAt(index);
                      onSelectedIndexChanged(null);
                      onStateChanged();
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ImagePostControlSlider(
            label: 'Scale',
            value: o.scale,
            min: 0.02,
            max: 3.0,
            onChanged: (v) {
              o.scale = v;
              onStateChanged();
            },
          ),
          ImagePostControlSlider(
            label: 'Opacity',
            value: o.opacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) {
              o.opacity = v;
              onStateChanged();
            },
          ),
          ImagePostControlSlider(
            label: 'Rotation',
            value: o.rotation,
            min: 0,
            max: 360,
            onChanged: (v) {
              o.rotation = v;
              onStateChanged();
            },
          ),
          const Divider(height: 24),
          const Text(
            'Positioning',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _alignBtn(Icons.align_horizontal_left, 'Left', 0.15, null, o),
              _alignBtn(Icons.align_horizontal_center, 'Center', 0.5, null, o),
              _alignBtn(Icons.align_horizontal_right, 'Right', 0.85, null, o),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _alignBtn(Icons.align_vertical_top, 'Top', null, 0.1, o),
              _alignBtn(Icons.align_vertical_center, 'Mid', null, 0.5, o),
              _alignBtn(Icons.align_vertical_bottom, 'Bottom', null, 0.9, o),
            ],
          ),
          const SizedBox(height: 8),
          ImagePostControlSlider(
            label: 'Horizontal (X)',
            value: o.x,
            min: 0,
            max: 1,
            onChanged: (v) {
              o.x = v;
              onStateChanged();
            },
          ),
          ImagePostControlSlider(
            label: 'Vertical (Y)',
            value: o.y,
            min: 0,
            max: 1,
            onChanged: (v) {
              o.y = v;
              onStateChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _alignBtn(
    IconData icon,
    String label,
    double? x,
    double? y,
    ImagePostOverlayImage o,
  ) {
    return InkWell(
      onTap: () {
        if (x != null) o.x = x;
        if (y != null) o.y = y;
        onStateChanged();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

