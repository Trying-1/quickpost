import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';

/// Slide & image management tab for [CarouselPostScreen].
class CarouselImageTab extends StatelessWidget {
  final CarouselSlide slide;
  final int currentIndex;
  final int totalSlides;
  final bool isRemovingBg;
  final bool editFgAdjustments;
  final ValueChanged<bool> onToggleEditFg;
  final VoidCallback onAddSlide;
  final VoidCallback onImportMultiple;
  final VoidCallback onReplaceImage;
  final VoidCallback onRemoveBackground;
  final VoidCallback onEditCutout;
  final VoidCallback onClearForeground;
  final VoidCallback onDeleteSlide;
  final VoidCallback onStateChanged;

  const CarouselImageTab({
    super.key,
    required this.slide,
    required this.currentIndex,
    required this.totalSlides,
    required this.isRemovingBg,
    required this.editFgAdjustments,
    required this.onToggleEditFg,
    required this.onAddSlide,
    required this.onImportMultiple,
    required this.onReplaceImage,
    required this.onRemoveBackground,
    required this.onEditCutout,
    required this.onClearForeground,
    required this.onDeleteSlide,
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
            const CarouselSectionHeader(title: 'Slide Management'),
            Text(
              'Slide ${currentIndex + 1} of $totalSlides',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              CarouselActionPill(
                onPressed: onAddSlide,
                icon: Icons.add,
                label: 'Add',
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              CarouselActionPill(
                onPressed: onImportMultiple,
                icon: Icons.photo_library,
                label: 'Import',
                color: Colors.teal,
              ),
              const SizedBox(width: 8),
              CarouselActionPill(
                onPressed: onReplaceImage,
                icon: Icons.refresh,
                label: 'Replace',
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              if (slide.image != null) ...[
                isRemovingBg
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (slide.foregroundImage != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CarouselActionPill(
                                onPressed: onEditCutout,
                                icon: Icons.edit,
                                label: 'Edit Cutout',
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 8),
                              CarouselActionPill(
                                onPressed: onClearForeground,
                                icon: Icons.layers_clear,
                                label: 'Clear FG',
                                color: Colors.redAccent,
                              ),
                            ],
                          )
                        : CarouselActionPill(
                            onPressed: onRemoveBackground,
                            icon: Icons.auto_fix_high,
                            label: 'Remove BG',
                            color: Colors.deepPurple,
                          )),
                const SizedBox(width: 8),
              ],
              if (totalSlides > 1)
                CarouselActionPill(
                  onPressed: onDeleteSlide,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                ),
            ],
          ),
        ),
        if (slide.image != null) ...[
          const SizedBox(height: 12),
          const CarouselSectionHeader(title: 'Image Adjustments'),
          Row(
            children: [
              CarouselActionPill(
                onPressed: () {
                  slide.transformationController.value = Matrix4.identity();
                  onStateChanged();
                },
                icon: Icons.center_focus_strong,
                label: 'Reset Transform',
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              CarouselActionPill(
                onPressed: () {
                  slide.brightness = 1.0;
                  slide.saturation = 1.0;
                  slide.hue = 0.0;
                  onStateChanged();
                },
                icon: Icons.settings_backup_restore,
                label: 'Reset Filters',
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              CarouselActionPill(
                onPressed: () {
                  slide.image = null;
                  onStateChanged();
                },
                icon: Icons.close,
                label: 'Clear Image',
                color: Colors.blueGrey,
              ),
            ],
          ),
          if (slide.foregroundImage != null) ...[
            const SizedBox(height: 8),
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Background')),
                  ButtonSegment(value: true, label: Text('Foreground')),
                ],
                selected: {editFgAdjustments},
                onSelectionChanged: (val) => onToggleEditFg(val.first),
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!editFgAdjustments) ...[
            CarouselControlSlider(
              label: 'Brightness',
              value: slide.brightness,
              min: 0.0,
              max: 2.0,
              onChanged: (val) {
                slide.brightness = val;
                onStateChanged();
              },
            ),
            const SizedBox(height: 8),
            CarouselControlSlider(
              label: 'Saturation',
              value: slide.saturation,
              min: 0.0,
              max: 2.0,
              onChanged: (val) {
                slide.saturation = val;
                onStateChanged();
              },
            ),
            const SizedBox(height: 8),
            CarouselControlSlider(
              label: 'Hue',
              value: slide.hue,
              min: -math.pi,
              max: math.pi,
              onChanged: (val) {
                slide.hue = val;
                onStateChanged();
              },
            ),
          ] else ...[
            CarouselControlSlider(
              label: 'FG Brightness',
              value: slide.fgBrightness,
              min: 0.0,
              max: 2.0,
              onChanged: (val) {
                slide.fgBrightness = val;
                onStateChanged();
              },
            ),
            const SizedBox(height: 8),
            CarouselControlSlider(
              label: 'FG Saturation',
              value: slide.fgSaturation,
              min: 0.0,
              max: 2.0,
              onChanged: (val) {
                slide.fgSaturation = val;
                onStateChanged();
              },
            ),
            const SizedBox(height: 8),
            CarouselControlSlider(
              label: 'FG Hue',
              value: slide.fgHue,
              min: -math.pi,
              max: math.pi,
              onChanged: (val) {
                slide.fgHue = val;
                onStateChanged();
              },
            ),
            const SizedBox(height: 8),
            CarouselControlSlider(
              label: 'FG Opacity',
              value: slide.fgOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (val) {
                slide.fgOpacity = val;
                onStateChanged();
              },
            ),
            const SizedBox(height: 8),
            CarouselControlSlider(
              label: 'Feathering (Apply again)',
              value: slide.feathering,
              min: 0.0,
              max: 20.0,
              onChanged: (val) {
                slide.feathering = val;
                onStateChanged();
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Tip: Drag on the image above to adjust its position.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
