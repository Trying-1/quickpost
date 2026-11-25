import 'package:flutter/material.dart';
import '../../../../../config/app_theme.dart';
import '../../models/image_post_overlays.dart';
import '../image_post_shared_controls.dart';

/// Gradient Mask tab panel (index 10) for ImagePostMakerScreen.
class ImagePostMaskTab extends StatelessWidget {
  final int maskType;
  final double maskStart;
  final double maskEnd;
  final double maskOpacity;
  final Color maskColor;
  final ValueChanged<int> onMaskTypeChanged;
  final ValueChanged<double> onMaskStartChanged;
  final ValueChanged<double> onMaskEndChanged;
  final ValueChanged<double> onMaskOpacityChanged;
  final ValueChanged<Color> onMaskColorChanged;

  const ImagePostMaskTab({
    super.key,
    required this.maskType,
    required this.maskStart,
    required this.maskEnd,
    required this.maskOpacity,
    required this.maskColor,
    required this.onMaskTypeChanged,
    required this.onMaskStartChanged,
    required this.onMaskEndChanged,
    required this.onMaskOpacityChanged,
    required this.onMaskColorChanged,
  });

  static const _maskTypes = [
    (0, Icons.block, 'None'),
    (1, Icons.vertical_align_bottom, 'Bottom'),
    (2, Icons.vertical_align_top, 'Top'),
    (4, Icons.align_horizontal_left_rounded, 'Left'),
    (5, Icons.align_horizontal_right_rounded, 'Right'),
    (3, Icons.format_color_fill, 'Full'),
  ];

  @override
  Widget build(BuildContext context) {
    final maskHex =
        '#${maskColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ImagePostSectionHeader(
          title: 'Mask Type',
          icon: Icons.gradient,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _maskTypes
                .map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildMaskTypeOption(opt.$1, opt.$2, opt.$3),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        ImagePostControlSlider(
          label: 'Mask Range Start',
          value: maskStart,
          min: 0.0,
          max: 1.0,
          onChanged: onMaskStartChanged,
        ),
        const SizedBox(height: 16),
        ImagePostControlSlider(
          label: 'Mask Range End',
          value: maskEnd,
          min: 0.0,
          max: 1.0,
          onChanged: onMaskEndChanged,
        ),
        const SizedBox(height: 16),
        ImagePostControlSlider(
          label: 'Mask Opacity',
          value: maskOpacity,
          min: 0.0,
          max: 1.0,
          onChanged: onMaskOpacityChanged,
        ),
        const SizedBox(height: 24),
        const ImagePostSectionHeader(
          title: 'Mask Color',
          icon: Icons.color_lens,
        ),
        const SizedBox(height: 12),
        ImagePostColorPicker(
          currentColor: maskHex,
          onPick: (hex) => onMaskColorChanged(parseImagePostColor(hex)),
        ),
      ],
    );
  }

  Widget _buildMaskTypeOption(int type, IconData icon, String label) {
    final bool isSelected = maskType == type;
    return GestureDetector(
      onTap: () => onMaskTypeChanged(type),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey[200]!,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

