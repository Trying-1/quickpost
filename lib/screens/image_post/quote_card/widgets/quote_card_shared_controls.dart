import 'package:flutter/material.dart';

import '../../../../widgets/advanced_color_picker.dart';

/// Opens the HSV/palette dialog backed by [AdvancedColorPicker].
Future<Color?> showQuoteCardColorPickerDialog({
  required BuildContext context,
  required String title,
  required Color initialColor,
}) async {
  Color selectedColor = initialColor;
  return showDialog<Color>(
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
                onPressed: () => Navigator.pop(dialogContext, selectedColor),
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

/// Shared card container with icon header used inside Quote Card tabs.
class QuoteCardSectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? headerTrailing;
  final Widget child;

  const QuoteCardSectionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Shared labeled color swatch row that triggers a color picker dialog.
class QuoteCardColorSwatchRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool circle;
  final double size;
  final double fontSize;
  final Widget? trailing;

  const QuoteCardColorSwatchRow({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.circle = false,
    this.size = 28,
    this.fontSize = 14,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: fontSize)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circle ? null : BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Expanded(child: trailing!),
        ],
      ],
    );
  }
}

/// Shared labeled slider row used in Effects and Background options.
class QuoteCardSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double labelWidth;
  final double fontSize;
  final bool boldLabel;

  const QuoteCardSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.labelWidth = 76,
    this.fontSize = 12,
    this.boldLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: boldLabel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 35,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Shared alignment presets + directional nudge pad for positioning Quote or Identity bar.
class QuoteCardPositionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Alignment position;
  final Alignment resetAlignment;
  final ValueChanged<Alignment> onPositionChanged;

  const QuoteCardPositionSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.position,
    required this.resetAlignment,
    required this.onPositionChanged,
  });

  static const _presets = <Map<String, Object>>[
    {'label': 'Center', 'alignment': Alignment.center},
    {'label': 'Top', 'alignment': Alignment.topCenter},
    {'label': 'Bottom', 'alignment': Alignment.bottomCenter},
    {'label': 'Left', 'alignment': Alignment.centerLeft},
    {'label': 'Right', 'alignment': Alignment.centerRight},
  ];

  void _nudge(double dx, double dy) {
    final newX = (position.x + dx).clamp(-1.0, 1.0);
    final newY = (position.y + dy).clamp(-1.0, 1.0);
    onPositionChanged(Alignment(newX, newY));
  }

  @override
  Widget build(BuildContext context) {
    const double step = 0.1;
    return QuoteCardSectionCard(
      icon: icon,
      iconColor: accentColor,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Presets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presets.map((preset) {
                final target = preset['alignment']! as Alignment;
                final isSelected = position == target;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onPositionChanged(target),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? accentColor : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        preset['label']! as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? accentColor : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fine tune',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'x: ${position.x.toStringAsFixed(2)}, y: ${position.y.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  IconButton(
                    onPressed: () => _nudge(0, -step),
                    icon: const Icon(Icons.keyboard_arrow_up),
                    iconSize: 22,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _nudge(-step, 0),
                        icon: const Icon(Icons.keyboard_arrow_left),
                        iconSize: 22,
                      ),
                      IconButton(
                        onPressed: () => onPositionChanged(resetAlignment),
                        icon: const Icon(Icons.adjust),
                        iconSize: 20,
                      ),
                      IconButton(
                        onPressed: () => _nudge(step, 0),
                        icon: const Icon(Icons.keyboard_arrow_right),
                        iconSize: 22,
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _nudge(0, step),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    iconSize: 22,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

