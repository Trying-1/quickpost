import 'package:flutter/material.dart';

/// Uppercase section header used across Carousel editor tabs.
class CarouselSectionHeader extends StatelessWidget {
  final String title;

  const CarouselSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Compact labeled slider shared across image filters, sizing, and mask tabs.
class CarouselControlSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int decimals;

  const CarouselControlSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text(value.toStringAsFixed(decimals),
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        SizedBox(
          height: 32,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFF6C63FF),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: const Color(0xFF6C63FF),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact inline row slider used in the Effects & Spacing panels.
class CarouselInlineSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const CarouselInlineSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

/// Reusable compact tinted action chip button used in Carousel tabs.
class CarouselActionPill extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const CarouselActionPill({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Uniform circular color swatch button shared across Style, Effects, and Mask tabs.
class CarouselColorSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CarouselColorSwatch({
    super.key,
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF6C63FF) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom color picker trigger button shared across Style, Effects, and Mask tabs.
class CarouselCustomColorButton extends StatelessWidget {
  final VoidCallback onTap;

  const CarouselCustomColorButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.colorize, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Custom',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aspect ratio selector chips (`4:5`, `1:1`, `9:16`, `16:9`).
class CarouselAspectRatioSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const CarouselAspectRatioSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      ('4:5', 0),
      ('1:1', 1),
      ('9:16', 2),
      ('16:9', 3),
    ];

    return Row(
      children: options.map((opt) {
        final bool isSel = selectedIndex == opt.$2;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(opt.$1, style: const TextStyle(fontSize: 11)),
            selected: isSel,
            onSelected: (val) {
              if (val) onChanged(opt.$2);
            },
          ),
        );
      }).toList(),
    );
  }
}


/// Circular 32x32 color swatch with checkmark and caption underneath,
/// shared across Style and Effects tabs.
class CarouselCircularColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final double rightPadding;
  final VoidCallback onTap;

  const CarouselCircularColorOption({
    super.key,
    required this.color,
    required this.label,
    required this.isSelected,
    this.rightPadding = 16,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(right: rightPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFF6C63FF) : Colors.grey[200]!,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular 32x32 custom color picker trigger button with "Custom" label.
class CarouselCircularCustomColorOption extends StatelessWidget {
  final double rightPadding;
  final VoidCallback onTap;

  const CarouselCircularCustomColorOption({
    super.key,
    this.rightPadding = 12,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(right: rightPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.colorize_rounded,
                size: 16,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Custom',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
