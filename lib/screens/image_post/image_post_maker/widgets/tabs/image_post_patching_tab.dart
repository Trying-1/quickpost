import 'package:flutter/material.dart';
import '../../../../../config/app_theme.dart';
import '../../models/image_post_overlays.dart';
import '../image_post_shared_controls.dart';

/// Patches Overlay tab panel (index 7): add, select, layer-order, style, and remove shape patches.
class ImagePostPatchingTab extends StatelessWidget {
  final List<ImagePostPatch> patches;
  final int? selectedPatchIndex;
  final ValueChanged<int?> onSelectedIndexChanged;
  final VoidCallback onStateChanged;

  const ImagePostPatchingTab({
    super.key,
    required this.patches,
    required this.selectedPatchIndex,
    required this.onSelectedIndexChanged,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Patches Overlay (Shapes)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: () {
                patches.add(
                  ImagePostPatch(x: 0.25, y: 0.25, width: 0.5, height: 0.1),
                );
                onSelectedIndexChanged(patches.length - 1);
                onStateChanged();
              },
              icon: const Icon(Icons.add_box, size: 18),
              label: const Text('Add Patch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (patches.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No patches added. Use them to mask or highlight areas.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (patches.isNotEmpty) ...[
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: patches.length,
              itemBuilder: (context, idx) {
                final isSelected = selectedPatchIndex == idx;
                return GestureDetector(
                  onTap: () => onSelectedIndexChanged(idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Patch #${idx + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (selectedPatchIndex != null &&
            selectedPatchIndex! >= 0 &&
            selectedPatchIndex! < patches.length)
          _buildActivePatchControls(
            patches[selectedPatchIndex!],
            selectedPatchIndex!,
          )
        else if (patches.isNotEmpty)
          const Text(
            'Select a patch on preview to edit',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildActivePatchControls(ImagePostPatch p, int index) {
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
                'Patch #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () {
                  patches.removeAt(index);
                  onSelectedIndexChanged(null);
                  onStateChanged();
                },
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
              ),
            ],
          ),
          ImagePostControlSlider(
            label: 'Width',
            value: p.width,
            min: 0.01,
            max: 1.0,
            onChanged: (v) {
              p.width = v;
              onStateChanged();
            },
          ),
          ImagePostControlSlider(
            label: 'Height',
            value: p.height,
            min: 0.01,
            max: 1.0,
            onChanged: (v) {
              p.height = v;
              onStateChanged();
            },
          ),
          const SizedBox(height: 12),
          const Text('Color'),
          const SizedBox(height: 8),
          ImagePostColorPicker(
            currentColor: p.color,
            onPick: (c) {
              p.color = c;
              onStateChanged();
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(
              'Keep on Top',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Render patch above main image frame',
              style: TextStyle(fontSize: 11),
            ),
            value: p.isTop,
            onChanged: (v) {
              p.isTop = v;
              onStateChanged();
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          ImagePostControlSlider(
            label: 'Opacity',
            value: p.opacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) {
              p.opacity = v;
              onStateChanged();
            },
          ),
          ImagePostControlSlider(
            label: 'Radius',
            value: p.radius,
            min: 0.0,
            max: 200.0,
            onChanged: (v) {
              p.radius = v;
              onStateChanged();
            },
          ),
        ],
      ),
    );
  }
}

