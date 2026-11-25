import 'package:flutter/material.dart';
import '../../../../widgets/advanced_color_picker.dart';

/// Shows a modal dialog wrapping [AdvancedColorPicker] for any Text Post color target.
void showTextPostColorPickerDialog({
  required BuildContext context,
  required String title,
  required Color initialColor,
  required ValueChanged<Color> onColorSelected,
}) {
  Color selectedColor = initialColor;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              initialColor: initialColor,
              onColorChanged: (color) => selectedColor = color,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onColorSelected(selectedColor);
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
}

/// Pairs two widgets cleanly side-by-side with consistent spacing for dense control sheets.
class TextPostTwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double gap;

  const TextPostTwoCol({
    super.key,
    required this.left,
    required this.right,
    this.gap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }
}

/// Compact labeled slider with optional reset icon and +/- step buttons.
class TextPostSimpleSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;
  final double step;

  const TextPostSimpleSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onReset,
    this.step = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            if (onReset != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.refresh,
                    size: 11,
                    color: Colors.indigo[400],
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              value.toStringAsFixed(max <= 2 ? 2 : 1),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 28,
          child: Row(
            children: [
              TextPostStepButton(
                icon: Icons.remove,
                onTap: () => onChanged((value - step).clamp(min, max)),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.indigo[400],
                    inactiveTrackColor: Colors.indigo[50],
                    thumbColor: Colors.indigo[600],
                    overlayColor: Colors.indigo.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ),
              TextPostStepButton(
                icon: Icons.add,
                onTap: () => onChanged((value + step).clamp(min, max)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small +/- nudge button flanking [TextPostSimpleSlider].
class TextPostStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const TextPostStepButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 13, color: Colors.indigo[700]),
        ),
      ),
    );
  }
}

/// Horizontal circular preset swatch strip with a Custom color picker trigger.
class TextPostColorPickerRow extends StatelessWidget {
  final String label;
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onPickCustom;
  final bool allowTransparent;

  const TextPostColorPickerRow({
    super.key,
    required this.label,
    required this.currentColor,
    required this.onColorSelected,
    required this.onPickCustom,
    this.allowTransparent = false,
  });

  static const List<Color> _basePresets = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  Widget build(BuildContext context) {
    final presets = [
      ..._basePresets,
      if (allowTransparent) Colors.transparent,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            GestureDetector(
              onTap: onPickCustom,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.colorize, size: 11, color: Colors.black54),
                    SizedBox(width: 4),
                    Text(
                      'Custom',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final color = presets[index];
              final isSelected = currentColor.toARGB32() == color.toARGB32();
              final isDark =
                  color.computeLuminance() < 0.5 && color != Colors.transparent;

              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: isSelected ? 2.2 : 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (color == Colors.transparent)
                        const Icon(
                          Icons.not_interested,
                          size: 16,
                          color: Colors.grey,
                        ),
                      if (isSelected)
                        Icon(
                          Icons.check,
                          size: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
