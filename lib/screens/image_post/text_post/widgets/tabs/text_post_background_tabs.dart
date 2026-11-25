import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../text_post_shared_controls.dart';

/// Unified Background Image & Color Tune tab (index 5).
class TextPostBackgroundPhotoTab extends StatelessWidget {
  final bool hasImage;
  final double brightness;
  final double saturation;
  final double hue;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onResetTransform;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onHueChanged;
  final VoidCallback onResetAdjustments;

  const TextPostBackgroundPhotoTab({
    super.key,
    required this.hasImage,
    required this.brightness,
    required this.saturation,
    required this.hue,
    required this.onPickImage,
    required this.onClearImage,
    required this.onResetTransform,
    required this.onBrightnessChanged,
    required this.onSaturationChanged,
    required this.onHueChanged,
    required this.onResetAdjustments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action buttons row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: Text(
                  hasImage ? 'Change Photo' : 'Pick Photo',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[800],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: onResetTransform,
                tooltip: 'Reset Zoom & Pan',
                icon: const Icon(Icons.center_focus_strong, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[800],
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: onClearImage,
                tooltip: 'Remove Image',
                icon: const Icon(Icons.delete_outline, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[700],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (!hasImage)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Text(
              'Pick a background photo to unlock pinch-to-zoom, brightness, saturation, and hue adjustments.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Row(
            children: [
              const Text(
                'Color Adjustments',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onResetAdjustments,
                icon: const Icon(Icons.refresh, size: 13),
                label: const Text('Reset', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          TextPostTwoCol(
            left: TextPostSimpleSlider(
              label: 'Brightness',
              value: brightness,
              min: 0.0,
              max: 2.0,
              onChanged: onBrightnessChanged,
              onReset: () => onBrightnessChanged(1.0),
              step: 0.05,
            ),
            right: TextPostSimpleSlider(
              label: 'Saturation',
              value: saturation,
              min: 0.0,
              max: 2.0,
              onChanged: onSaturationChanged,
              onReset: () => onSaturationChanged(1.0),
              step: 0.05,
            ),
          ),
          const SizedBox(height: 4),
          TextPostSimpleSlider(
            label: 'Hue',
            value: hue,
            min: -math.pi,
            max: math.pi,
            onChanged: onHueChanged,
            onReset: () => onHueChanged(0.0),
            step: 0.1,
          ),
        ],
      ],
    );
  }
}

/// Overlay Mask tab (index 6): mask direction chips, inline color swatch, 2-col stops.
class TextPostMaskTab extends StatelessWidget {
  final int maskType;
  final Color maskColor;
  final double maskOpacity;
  final double maskStart;
  final double maskEnd;
  final ValueChanged<int> onMaskTypeChanged;
  final VoidCallback onPickMaskColor;
  final ValueChanged<double> onMaskOpacityChanged;
  final ValueChanged<double> onMaskStartChanged;
  final ValueChanged<double> onMaskEndChanged;

  const TextPostMaskTab({
    super.key,
    required this.maskType,
    required this.maskColor,
    required this.maskOpacity,
    required this.maskStart,
    required this.maskEnd,
    required this.onMaskTypeChanged,
    required this.onPickMaskColor,
    required this.onMaskOpacityChanged,
    required this.onMaskStartChanged,
    required this.onMaskEndChanged,
  });

  static const _maskTypes = [
    ('None', Icons.block, 0),
    ('Bottom', Icons.expand_less, 1),
    ('Top', Icons.expand_more, 2),
    ('Full', Icons.stop, 3),
    ('Left', Icons.chevron_left, 4),
    ('Right', Icons.chevron_right, 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Gradient Mask',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const Spacer(),
            if (maskType != 0)
              GestureDetector(
                onTap: onPickMaskColor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Color', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: maskColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _maskTypes.map((m) {
              final isSelected = maskType == m.$3;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(m.$1, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(
                    m.$2,
                    size: 14,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                  selected: isSelected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (val) {
                    if (val) onMaskTypeChanged(m.$3);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (maskType != 0) ...[
          const SizedBox(height: 10),
          TextPostSimpleSlider(
            label: 'Opacity',
            value: maskOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: onMaskOpacityChanged,
            onReset: () => onMaskOpacityChanged(0.5),
            step: 0.05,
          ),
          if (maskType != 3) ...[
            const SizedBox(height: 4),
            TextPostTwoCol(
              left: TextPostSimpleSlider(
                label: 'Start Stop',
                value: maskStart,
                min: 0.0,
                max: 1.0,
                onChanged: onMaskStartChanged,
                onReset: () => onMaskStartChanged(0.0),
                step: 0.05,
              ),
              right: TextPostSimpleSlider(
                label: 'End Stop',
                value: maskEnd,
                min: 0.0,
                max: 1.0,
                onChanged: onMaskEndChanged,
                onReset: () => onMaskEndChanged(1.0),
                step: 0.05,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
