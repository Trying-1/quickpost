import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/text_post_overlays.dart';
import '../text_post_shared_controls.dart';

/// Image Overlays tab (index 7): sticker strip + compact 2-column transform controls.
class TextPostOverlaysTab extends StatelessWidget {
  final List<TextPostOverlayImage> imageOverlays;
  final int? selectedImageOverlayIndex;
  final ValueChanged<int?> onSelectedIndexChanged;
  final VoidCallback onStateChanged;

  const TextPostOverlaysTab({
    super.key,
    required this.imageOverlays,
    required this.selectedImageOverlayIndex,
    required this.onSelectedIndexChanged,
    required this.onStateChanged,
  });

  Future<void> _pickNewImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    imageOverlays.add(TextPostOverlayImage(path: picked.path));
    onSelectedIndexChanged(imageOverlays.length - 1);
    onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Image Overlays',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _pickNewImage,
              icon: const Icon(Icons.add_photo_alternate, size: 15),
              label: const Text('Add', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (imageOverlays.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No image overlays added.\nPick a sticker or photo to overlay.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageOverlays.length,
              itemBuilder: (_, i) {
                final o = imageOverlays[i];
                final isSelected = selectedImageOverlayIndex == i;
                return GestureDetector(
                  onTap: () => onSelectedIndexChanged(i),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected ? Colors.deepPurple : Colors.grey.shade300,
                        width: isSelected ? 2.2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(o.path), fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (selectedImageOverlayIndex != null &&
              selectedImageOverlayIndex! < imageOverlays.length)
            _buildActiveImageOverlayControls(
              imageOverlays[selectedImageOverlayIndex!],
              selectedImageOverlayIndex!,
            )
          else
            const Center(
              child: Text(
                'Tap an overlay above or on canvas to edit',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActiveImageOverlayControls(
    TextPostOverlayImage o,
    int index,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Overlay #${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final picked =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  o.path = picked.path;
                  onStateChanged();
                }
              },
              icon: const Icon(
                Icons.swap_horiz,
                color: Colors.deepPurple,
                size: 18,
              ),
              tooltip: 'Replace Image',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {
                imageOverlays.removeAt(index);
                onSelectedIndexChanged(null);
                onStateChanged();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Scale',
            value: o.scale,
            min: 0.05,
            max: 1.0,
            onChanged: (v) {
              o.scale = v;
              onStateChanged();
            },
            onReset: () {
              o.scale = 0.2;
              onStateChanged();
            },
            step: 0.01,
          ),
          right: TextPostSimpleSlider(
            label: 'Rotation',
            value: o.rotation,
            min: -180.0,
            max: 180.0,
            onChanged: (v) {
              o.rotation = v;
              onStateChanged();
            },
            onReset: () {
              o.rotation = 0.0;
              onStateChanged();
            },
            step: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        TextPostSimpleSlider(
          label: 'Opacity',
          value: o.opacity,
          min: 0.0,
          max: 1.0,
          onChanged: (v) {
            o.opacity = v;
            onStateChanged();
          },
          onReset: () {
            o.opacity = 1.0;
            onStateChanged();
          },
          step: 0.05,
        ),
      ],
    );
  }
}

/// Shapes/Patches tab (index 8): shape chips, top-layer switch, color swatch, and 2-col size sliders.
class TextPostShapesTab extends StatelessWidget {
  final List<TextPostOverlayPatch> patches;
  final int? selectedPatchIndex;
  final ValueChanged<int?> onSelectedIndexChanged;
  final VoidCallback onStateChanged;

  const TextPostShapesTab({
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
          children: [
            const Text(
              'Backdrop Shapes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                patches.add(
                  TextPostOverlayPatch(
                    x: 0.25,
                    y: 0.25,
                    width: 0.5,
                    height: 0.2,
                  ),
                );
                onSelectedIndexChanged(patches.length - 1);
                onStateChanged();
              },
              icon: const Icon(Icons.add_box, size: 15),
              label: const Text('Add Shape', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (patches.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No shapes added. Add backdrops behind or above your text.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: patches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final isSelected = selectedPatchIndex == i;
                return GestureDetector(
                  onTap: () => onSelectedIndexChanged(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.pink : Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? Colors.pink : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Shape #${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (selectedPatchIndex != null &&
              selectedPatchIndex! < patches.length)
            _buildActivePatchControls(
              context,
              patches[selectedPatchIndex!],
              selectedPatchIndex!,
            )
          else
            const Center(
              child: Text(
                'Select a shape above or on preview to edit',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActivePatchControls(
    BuildContext context,
    TextPostOverlayPatch p,
    int index,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => showTextPostColorPickerDialog(
                context: context,
                title: 'Shape Color',
                initialColor: p.color,
                onColorSelected: (c) {
                  p.color = c;
                  onStateChanged();
                },
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Color:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: p.color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ChoiceChip(
              label: const Text('Top Layer', style: TextStyle(fontSize: 10)),
              selected: p.isTop,
              onSelected: (v) {
                p.isTop = v;
                onStateChanged();
              },
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                patches.removeAt(index);
                onSelectedIndexChanged(null);
                onStateChanged();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Width',
            value: p.width,
            min: 0.05,
            max: 1.0,
            onChanged: (v) {
              p.width = v;
              onStateChanged();
            },
            onReset: () {
              p.width = 0.5;
              onStateChanged();
            },
            step: 0.01,
          ),
          right: TextPostSimpleSlider(
            label: 'Height',
            value: p.height,
            min: 0.05,
            max: 1.0,
            onChanged: (v) {
              p.height = v;
              onStateChanged();
            },
            onReset: () {
              p.height = 0.2;
              onStateChanged();
            },
            step: 0.01,
          ),
        ),
        const SizedBox(height: 4),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Opacity',
            value: p.opacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) {
              p.opacity = v;
              onStateChanged();
            },
            onReset: () {
              p.opacity = 0.5;
              onStateChanged();
            },
            step: 0.05,
          ),
          right: TextPostSimpleSlider(
            label: 'Radius',
            value: p.radius,
            min: 0.0,
            max: 100.0,
            onChanged: (v) {
              p.radius = v;
              onStateChanged();
            },
            onReset: () {
              p.radius = 8.0;
              onStateChanged();
            },
            step: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Text Layers tab (index 9): reorder, add, select, or remove extra text layers.
class TextPostLayersTab extends StatelessWidget {
  final List<TextPostTextOverlay> textOverlays;
  final int selectedTextIndex;
  final ValueChanged<int> onSelectTextIndex;
  final VoidCallback onAddLayer;
  final VoidCallback onStateChanged;

  const TextPostLayersTab({
    super.key,
    required this.textOverlays,
    required this.selectedTextIndex,
    required this.onSelectTextIndex,
    required this.onAddLayer,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Text Layers',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onAddLayer,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Layer', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildLayerItem(
          title: 'Main Post Text',
          isSelected: selectedTextIndex == -1,
          onTap: () => onSelectTextIndex(-1),
          isMain: true,
        ),
        ...textOverlays.asMap().entries.map((entry) {
          return _buildLayerItem(
            title: entry.value.text.isEmpty ? 'Empty Layer' : entry.value.text,
            index: entry.key,
            isSelected: selectedTextIndex == entry.key,
            onTap: () => onSelectTextIndex(entry.key),
            onDuplicate: () {
              final clone = entry.value.copy()
                ..x = (entry.value.x + 0.04).clamp(0.0, 1.0)
                ..y = (entry.value.y + 0.04).clamp(0.0, 1.0);
              textOverlays.insert(entry.key + 1, clone);
              onSelectTextIndex(entry.key + 1);
              onStateChanged();
            },
            onDelete: () {
              textOverlays.removeAt(entry.key);
              onSelectTextIndex(-1);
              onStateChanged();
            },
            onMoveUp: entry.key > 0
                ? () {
                    final t = textOverlays.removeAt(entry.key);
                    textOverlays.insert(entry.key - 1, t);
                    onSelectTextIndex(entry.key - 1);
                    onStateChanged();
                  }
                : null,
            onMoveDown: entry.key < textOverlays.length - 1
                ? () {
                    final t = textOverlays.removeAt(entry.key);
                    textOverlays.insert(entry.key + 1, t);
                    onSelectTextIndex(entry.key + 1);
                    onStateChanged();
                  }
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildLayerItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onDuplicate,
    VoidCallback? onDelete,
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
    bool isMain = false,
    int? index,
  }) {
    final Color activeColor = isMain ? Colors.teal : Colors.indigo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? activeColor.withValues(alpha: 0.08)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.5)
                    : Colors.grey[200]!,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isMain ? 'M' : '${(index ?? 0) + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.black87 : Colors.grey[700],
                    ),
                  ),
                ),
                if (!isMain) ...[
                  if (onDuplicate != null) ...[
                    GestureDetector(
                      onTap: onDuplicate,
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: Colors.teal[600],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (onMoveUp != null)
                    GestureDetector(
                      onTap: onMoveUp,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ),
                  if (onMoveDown != null)
                    GestureDetector(
                      onTap: onMoveDown,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
