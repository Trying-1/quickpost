import 'package:flutter/material.dart';
import '../text_post_shared_controls.dart';

/// Position tab (index 4): quick snap presets and side-by-side X/Y sliders.
class TextPostPositionTab extends StatelessWidget {
  final bool isMain;
  final double posX;
  final double posY;
  final double canvasPadding;
  final ValueChanged<Alignment> onPresetSelected;
  final ValueChanged<double> onXChanged;
  final ValueChanged<double> onYChanged;
  final ValueChanged<double> onCanvasPaddingChanged;

  const TextPostPositionTab({
    super.key,
    required this.isMain,
    required this.posX,
    required this.posY,
    required this.canvasPadding,
    required this.onPresetSelected,
    required this.onXChanged,
    required this.onYChanged,
    required this.onCanvasPaddingChanged,
  });

  static const _presets = [
    ('Center', Alignment.center),
    ('Top', Alignment.topCenter),
    ('Bottom', Alignment.bottomCenter),
    ('Left', Alignment.centerLeft),
    ('Right', Alignment.centerRight),
  ];

  bool _matchesPreset(Alignment target) {
    if (isMain) {
      return posX == target.x && posY == target.y;
    }
    final double tx = posX * 2 - 1;
    final double ty = posY * 2 - 1;
    return (tx - target.x).abs() < 0.1 && (ty - target.y).abs() < 0.1;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Snap Position',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => onPresetSelected(Alignment.center),
              icon: const Icon(Icons.filter_center_focus, size: 14),
              label: const Text('Center', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _presets.map((preset) {
              final target = preset.$2;
              final isSelected = _matchesPreset(target);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onPresetSelected(target),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.brown.withValues(alpha: 0.12)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? Colors.brown : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      preset.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.brown : Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Horizontal (X)',
            value: posX,
            min: isMain ? -1.0 : 0.0,
            max: 1.0,
            step: 0.01,
            onChanged: onXChanged,
            onReset: () => onXChanged(isMain ? 0.0 : 0.5),
          ),
          right: TextPostSimpleSlider(
            label: 'Vertical (Y)',
            value: posY,
            min: isMain ? -1.0 : 0.0,
            max: 1.0,
            step: 0.01,
            onChanged: onYChanged,
            onReset: () => onYChanged(isMain ? 0.0 : 0.5),
          ),
        ),
        if (isMain) ...[
          const SizedBox(height: 10),
          TextPostSimpleSlider(
            label: 'Safe Canvas Margin',
            value: canvasPadding,
            min: 0.0,
            max: 64.0,
            step: 2.0,
            onChanged: onCanvasPaddingChanged,
            onReset: () => onCanvasPaddingChanged(16.0),
          ),
        ],
      ],
    );
  }
}
