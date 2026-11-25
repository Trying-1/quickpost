import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/advanced_color_picker.dart';
import '../models/image_post_overlays.dart';

/// Section header with leading icon for Image Post Maker tabs.
class ImagePostSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const ImagePostSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Slider flanked by `-` / `+` fine-step nudge buttons.
class ImagePostSliderWithButtons extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double? step;
  final Color activeColor;

  const ImagePostSliderWithButtons({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final double range = max - min;
    final double increment = step ??
        (range <= 2
            ? 0.05
            : (range <= 10
                ? 0.5
                : (range / 20).roundToDouble().clamp(1.0, 10.0)));

    return Row(
      children: [
        _PreciseButton(
          icon: Icons.remove,
          onTap: () => onChanged((value - increment).clamp(min, max)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: activeColor,
              inactiveTrackColor: activeColor.withValues(alpha: 0.1),
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        _PreciseButton(
          icon: Icons.add,
          onTap: () => onChanged((value + increment).clamp(min, max)),
        ),
      ],
    );
  }
}

class _PreciseButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PreciseButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: Colors.black87),
      ),
    );
  }
}

/// Labeled slider with value readout and +/- precision buttons.
class ImagePostControlSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double? step;

  const ImagePostControlSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              value.toStringAsFixed(max <= 2 ? 2 : 1),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        ImagePostSliderWithButtons(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          step: step,
        ),
      ],
    );
  }
}

/// Hex color swatch grid with a custom HSV/RGB picker dialog button.
class ImagePostColorPicker extends StatelessWidget {
  final String currentColor;
  final ValueChanged<String> onPick;

  const ImagePostColorPicker({
    super.key,
    required this.currentColor,
    required this.onPick,
  });

  static const _colors = [
    '#FFFFFF',
    '#000000',
    '#FFD700',
    '#FF4444',
    '#00E676',
    '#2979FF',
    '#FF4081',
    '#AA00FF',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            Color selectedColor = parseImagePostColor(currentColor);
            await showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Custom Color',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AdvancedColorPicker(
                        initialColor: selectedColor,
                        onColorChanged: (color) => selectedColor = color,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final hex =
                                '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                            onPick(hex);
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'SELECT COLOR',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: const Icon(
              Icons.colorize_rounded,
              size: 18,
              color: Colors.black54,
            ),
          ),
        ),
        ..._colors.map(
          (c) => GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: parseImagePostColor(c),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable shadow toggle + color + blur + X/Y + optional spread section.
class ImagePostShadowControlSection extends StatelessWidget {
  final String title;
  final bool showShadow;
  final ValueChanged<bool> onToggleShadow;
  final String shadowColor;
  final ValueChanged<String> onColorChanged;
  final double blur;
  final ValueChanged<double> onBlurChanged;
  final double offsetX;
  final ValueChanged<double> onOffsetXChanged;
  final double offsetY;
  final ValueChanged<double> onOffsetYChanged;
  final double? spread;
  final ValueChanged<double>? onSpreadChanged;

  const ImagePostShadowControlSection({
    super.key,
    required this.title,
    required this.showShadow,
    required this.onToggleShadow,
    required this.shadowColor,
    required this.onColorChanged,
    required this.blur,
    required this.onBlurChanged,
    required this.offsetX,
    required this.onOffsetXChanged,
    required this.offsetY,
    required this.onOffsetYChanged,
    this.spread,
    this.onSpreadChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Switch(value: showShadow, onChanged: onToggleShadow),
          ],
        ),
        if (showShadow) ...[
          const SizedBox(height: 8),
          const Text(
            'Color',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          ImagePostColorPicker(
            currentColor: shadowColor,
            onPick: onColorChanged,
          ),
          const SizedBox(height: 16),
          Text(
            'Blur Radius: ${blur.toInt()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          ImagePostSliderWithButtons(
            value: blur,
            min: 0,
            max: 20,
            onChanged: onBlurChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'X',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ImagePostSliderWithButtons(
                        value: offsetX,
                        min: -20,
                        max: 20,
                        onChanged: onOffsetXChanged,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Y',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ImagePostSliderWithButtons(
                        value: offsetY,
                        min: -20,
                        max: 20,
                        onChanged: onOffsetYChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (spread != null && onSpreadChanged != null) ...[
            const SizedBox(height: 8),
            Text(
              'Spread Radius: ${spread!.toInt()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            ImagePostSliderWithButtons(
              value: spread!,
              min: -20,
              max: 20,
              onChanged: onSpreadChanged!,
            ),
          ],
        ],
      ],
    );
  }
}

/// Small bottom-border sub-tab button used inside Style/Fonts tabs.
class ImagePostSubTabButtonSmall extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final String label;
  final IconData icon;
  final ValueChanged<int> onTap;

  const ImagePostSubTabButtonSmall({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

