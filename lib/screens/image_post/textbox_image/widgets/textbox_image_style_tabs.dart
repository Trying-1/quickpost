import 'package:flutter/material.dart';

import '../../../../utils/font_selector.dart';
import '../../../../widgets/advanced_color_picker.dart';

/// Opens the HSV/palette dialog backed by [AdvancedColorPicker].
Future<Color?> showTextboxImageColorPickerDialog({
  required BuildContext context,
  required String title,
  required Color initialColor,
}) {
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

/// Multi-line text input tab.
class TextboxImageTextTab extends StatelessWidget {
  final TextEditingController textController;

  const TextboxImageTextTab({super.key, required this.textController});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      maxLines: 3,
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(
        hintText: 'Enter your post text here...',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(10),
        isDense: true,
      ),
    );
  }
}

/// Horizontal font selector chip strip.
class TextboxImageFontTab extends StatelessWidget {
  final FontInfo? selectedFont;
  final ValueChanged<FontInfo> onFontSelected;

  const TextboxImageFontTab({
    super.key,
    required this.selectedFont,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fonts = getAllFonts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Font',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length,
            itemBuilder: (_, index) {
              final font = fonts[index];
              final isSelected = selectedFont == font;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: isSelected,
                  label: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: font.weight ?? FontWeight.w400,
                      fontStyle: font.style ?? FontStyle.normal,
                      fontSize: 12,
                    ),
                  ),
                  selectedColor: Colors.green[100],
                  backgroundColor: Colors.grey[100],
                  onSelected: (_) => onFontSelected(font),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorSwatchRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }
}

/// Text color and caption box color picker controls.
class TextboxImageColorsTab extends StatelessWidget {
  final Color textColor;
  final Color textBoxColor;
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<Color> onBoxColorChanged;

  const TextboxImageColorsTab({
    super.key,
    required this.textColor,
    required this.textBoxColor,
    required this.onTextColorChanged,
    required this.onBoxColorChanged,
  });

  Future<void> _pick(
    BuildContext context,
    String title,
    Color current,
    ValueChanged<Color> onChanged,
  ) async {
    final picked = await showTextboxImageColorPickerDialog(
      context: context,
      title: title,
      initialColor: current,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColorSwatchRow(
          label: 'Text Color:',
          color: textColor,
          onTap: () =>
              _pick(context, 'Text Color', textColor, onTextColorChanged),
        ),
        const SizedBox(height: 10),
        _ColorSwatchRow(
          label: 'Box Color:',
          color: textBoxColor,
          onTap: () =>
              _pick(context, 'Box Color', textBoxColor, onBoxColorChanged),
        ),
      ],
    );
  }
}

/// Shadow and glow toggles/sliders for Textbox Image caption text.
class TextboxImageEffectsTab extends StatelessWidget {
  final bool enableTextShadow;
  final Color shadowColor;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double shadowBlurRadius;
  final bool enableTextGlow;
  final Color glowColor;
  final double glowRadius;
  final ValueChanged<bool> onEnableShadowChanged;
  final ValueChanged<Color> onShadowColorChanged;
  final ValueChanged<double> onShadowOffsetXChanged;
  final ValueChanged<double> onShadowOffsetYChanged;
  final ValueChanged<double> onShadowBlurRadiusChanged;
  final ValueChanged<bool> onEnableGlowChanged;
  final ValueChanged<Color> onGlowColorChanged;
  final ValueChanged<double> onGlowRadiusChanged;

  const TextboxImageEffectsTab({
    super.key,
    required this.enableTextShadow,
    required this.shadowColor,
    required this.shadowOffsetX,
    required this.shadowOffsetY,
    required this.shadowBlurRadius,
    required this.enableTextGlow,
    required this.glowColor,
    required this.glowRadius,
    required this.onEnableShadowChanged,
    required this.onShadowColorChanged,
    required this.onShadowOffsetXChanged,
    required this.onShadowOffsetYChanged,
    required this.onShadowBlurRadiusChanged,
    required this.onEnableGlowChanged,
    required this.onGlowColorChanged,
    required this.onGlowRadiusChanged,
  });

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text(
            'Text Shadow',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          value: enableTextShadow,
          onChanged: onEnableShadowChanged,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (enableTextShadow) ...[
          const SizedBox(height: 4),
          _ColorSwatchRow(
            label: 'Shadow Color:',
            color: shadowColor,
            onTap: () async {
              final picked = await showTextboxImageColorPickerDialog(
                context: context,
                title: 'Shadow Color',
                initialColor: shadowColor,
              );
              if (picked != null) onShadowColorChanged(picked);
            },
          ),
          const SizedBox(height: 8),
          _sliderRow(
            'X Offset',
            shadowOffsetX,
            -20,
            20,
            onShadowOffsetXChanged,
          ),
          _sliderRow(
            'Y Offset',
            shadowOffsetY,
            -20,
            20,
            onShadowOffsetYChanged,
          ),
          _sliderRow(
            'Blur',
            shadowBlurRadius,
            0,
            20,
            onShadowBlurRadiusChanged,
          ),
          const SizedBox(height: 10),
        ],
        SwitchListTile(
          title: const Text(
            'Text Glow',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          value: enableTextGlow,
          onChanged: onEnableGlowChanged,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (enableTextGlow) ...[
          const SizedBox(height: 4),
          _ColorSwatchRow(
            label: 'Glow Color:',
            color: glowColor,
            onTap: () async {
              final picked = await showTextboxImageColorPickerDialog(
                context: context,
                title: 'Glow Color',
                initialColor: glowColor,
              );
              if (picked != null) onGlowColorChanged(picked);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Glow Radius: ${glowRadius.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: glowRadius,
            min: 5.0,
            max: 30.0,
            onChanged: onGlowRadiusChanged,
          ),
        ],
      ],
    );
  }
}

/// Letter spacing and font size percentage sliders.
class TextboxImageSpacingTab extends StatelessWidget {
  final double letterSpacing;
  final double fontSize;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<double> onFontSizeChanged;

  const TextboxImageSpacingTab({
    super.key,
    required this.letterSpacing,
    required this.fontSize,
    required this.onLetterSpacingChanged,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Letter Spacing: ${letterSpacing.toStringAsFixed(1)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Slider(
          value: letterSpacing,
          min: -2.0,
          max: 10.0,
          onChanged: onLetterSpacingChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Font Size: ${(fontSize * 100).toInt()}%',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Slider(
          value: fontSize,
          min: 0.5,
          max: 2.0,
          onChanged: onFontSizeChanged,
        ),
      ],
    );
  }
}

