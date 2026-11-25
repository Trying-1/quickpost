import 'dart:io';

import 'package:flutter/material.dart';

import '../quote_card_shared_controls.dart';

/// Shadow and glow effect toggles/controls for Quote and Author text.
class QuoteCardEffectsTab extends StatelessWidget {
  final bool enableQuoteShadow;
  final Color quoteShadowColor;
  final double quoteShadowOffsetX;
  final double quoteShadowOffsetY;
  final double quoteShadowBlur;
  final ValueChanged<bool> onEnableQuoteShadowChanged;
  final ValueChanged<Color> onQuoteShadowColorChanged;
  final ValueChanged<double> onQuoteShadowOffsetXChanged;
  final ValueChanged<double> onQuoteShadowOffsetYChanged;
  final ValueChanged<double> onQuoteShadowBlurChanged;

  final bool enableAuthorShadow;
  final Color authorShadowColor;
  final double authorShadowOffsetX;
  final double authorShadowOffsetY;
  final double authorShadowBlur;
  final ValueChanged<bool> onEnableAuthorShadowChanged;
  final ValueChanged<Color> onAuthorShadowColorChanged;
  final ValueChanged<double> onAuthorShadowOffsetXChanged;
  final ValueChanged<double> onAuthorShadowOffsetYChanged;
  final ValueChanged<double> onAuthorShadowBlurChanged;

  final bool enableQuoteGlow;
  final Color quoteGlowColor;
  final double quoteGlowRadius;
  final ValueChanged<bool> onEnableQuoteGlowChanged;
  final ValueChanged<Color> onQuoteGlowColorChanged;
  final ValueChanged<double> onQuoteGlowRadiusChanged;

  final bool enableAuthorGlow;
  final Color authorGlowColor;
  final double authorGlowRadius;
  final ValueChanged<bool> onEnableAuthorGlowChanged;
  final ValueChanged<Color> onAuthorGlowColorChanged;
  final ValueChanged<double> onAuthorGlowRadiusChanged;

  const QuoteCardEffectsTab({
    super.key,
    required this.enableQuoteShadow,
    required this.quoteShadowColor,
    required this.quoteShadowOffsetX,
    required this.quoteShadowOffsetY,
    required this.quoteShadowBlur,
    required this.onEnableQuoteShadowChanged,
    required this.onQuoteShadowColorChanged,
    required this.onQuoteShadowOffsetXChanged,
    required this.onQuoteShadowOffsetYChanged,
    required this.onQuoteShadowBlurChanged,
    required this.enableAuthorShadow,
    required this.authorShadowColor,
    required this.authorShadowOffsetX,
    required this.authorShadowOffsetY,
    required this.authorShadowBlur,
    required this.onEnableAuthorShadowChanged,
    required this.onAuthorShadowColorChanged,
    required this.onAuthorShadowOffsetXChanged,
    required this.onAuthorShadowOffsetYChanged,
    required this.onAuthorShadowBlurChanged,
    required this.enableQuoteGlow,
    required this.quoteGlowColor,
    required this.quoteGlowRadius,
    required this.onEnableQuoteGlowChanged,
    required this.onQuoteGlowColorChanged,
    required this.onQuoteGlowRadiusChanged,
    required this.enableAuthorGlow,
    required this.authorGlowColor,
    required this.authorGlowRadius,
    required this.onEnableAuthorGlowChanged,
    required this.onAuthorGlowColorChanged,
    required this.onAuthorGlowRadiusChanged,
  });

  Future<void> _pickColor(
    BuildContext context,
    String dialogTitle,
    Color current,
    ValueChanged<Color> onChanged,
  ) async {
    final picked = await showQuoteCardColorPickerDialog(
      context: context,
      title: dialogTitle,
      initialColor: current,
    );
    if (picked != null) onChanged(picked);
  }

  Widget _buildShadowBlock({
    required BuildContext context,
    required String title,
    required String colorDialogTitle,
    required bool enabled,
    required Color color,
    required double offsetX,
    required double offsetY,
    required double blur,
    required ValueChanged<bool> onToggle,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<double> onOffsetXChanged,
    required ValueChanged<double> onOffsetYChanged,
    required ValueChanged<double> onBlurChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          value: enabled,
          onChanged: onToggle,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuoteCardColorSwatchRow(
                  label: 'Shadow color',
                  color: color,
                  circle: true,
                  size: 24,
                  fontSize: 12,
                  onTap: () => _pickColor(
                    context,
                    colorDialogTitle,
                    color,
                    onColorChanged,
                  ),
                ),
                const SizedBox(height: 8),
                QuoteCardSliderRow(
                  label: 'X Offset',
                  value: offsetX,
                  min: -20,
                  max: 20,
                  onChanged: onOffsetXChanged,
                ),
                QuoteCardSliderRow(
                  label: 'Y Offset',
                  value: offsetY,
                  min: -20,
                  max: 20,
                  onChanged: onOffsetYChanged,
                ),
                QuoteCardSliderRow(
                  label: 'Blur Radius',
                  value: blur,
                  min: 0,
                  max: 20,
                  onChanged: onBlurChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGlowBlock({
    required BuildContext context,
    required String title,
    required String colorDialogTitle,
    required bool enabled,
    required Color color,
    required double radius,
    required ValueChanged<bool> onToggle,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<double> onRadiusChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          value: enabled,
          onChanged: onToggle,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuoteCardColorSwatchRow(
                  label: 'Glow color',
                  color: color,
                  circle: true,
                  size: 24,
                  fontSize: 12,
                  onTap: () => _pickColor(
                    context,
                    colorDialogTitle,
                    color,
                    onColorChanged,
                  ),
                ),
                const SizedBox(height: 8),
                QuoteCardSliderRow(
                  label: 'Glow radius',
                  value: radius,
                  min: 0,
                  max: 30,
                  onChanged: onRadiusChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShadowBlock(
          context: context,
          title: 'Quote shadow',
          colorDialogTitle: 'Quote Shadow Color',
          enabled: enableQuoteShadow,
          color: quoteShadowColor,
          offsetX: quoteShadowOffsetX,
          offsetY: quoteShadowOffsetY,
          blur: quoteShadowBlur,
          onToggle: onEnableQuoteShadowChanged,
          onColorChanged: onQuoteShadowColorChanged,
          onOffsetXChanged: onQuoteShadowOffsetXChanged,
          onOffsetYChanged: onQuoteShadowOffsetYChanged,
          onBlurChanged: onQuoteShadowBlurChanged,
        ),
        const Divider(),
        _buildShadowBlock(
          context: context,
          title: 'Author shadow',
          colorDialogTitle: 'Author Shadow Color',
          enabled: enableAuthorShadow,
          color: authorShadowColor,
          offsetX: authorShadowOffsetX,
          offsetY: authorShadowOffsetY,
          blur: authorShadowBlur,
          onToggle: onEnableAuthorShadowChanged,
          onColorChanged: onAuthorShadowColorChanged,
          onOffsetXChanged: onAuthorShadowOffsetXChanged,
          onOffsetYChanged: onAuthorShadowOffsetYChanged,
          onBlurChanged: onAuthorShadowBlurChanged,
        ),
        const Divider(),
        _buildGlowBlock(
          context: context,
          title: 'Quote glow',
          colorDialogTitle: 'Quote Glow Color',
          enabled: enableQuoteGlow,
          color: quoteGlowColor,
          radius: quoteGlowRadius,
          onToggle: onEnableQuoteGlowChanged,
          onColorChanged: onQuoteGlowColorChanged,
          onRadiusChanged: onQuoteGlowRadiusChanged,
        ),
        const Divider(),
        _buildGlowBlock(
          context: context,
          title: 'Author glow',
          colorDialogTitle: 'Author Glow Color',
          enabled: enableAuthorGlow,
          color: authorGlowColor,
          radius: authorGlowRadius,
          onToggle: onEnableAuthorGlowChanged,
          onColorChanged: onAuthorGlowColorChanged,
          onRadiusChanged: onAuthorGlowRadiusChanged,
        ),
      ],
    );
  }
}

/// Letter spacing, line height, and scale-multiplier controls.
class QuoteCardSpacingTab extends StatelessWidget {
  final double letterSpacing;
  final double lineHeight;
  final double fontSize;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onFontSizeChanged;

  const QuoteCardSpacingTab({
    super.key,
    required this.letterSpacing,
    required this.lineHeight,
    required this.fontSize,
    required this.onLetterSpacingChanged,
    required this.onLineHeightChanged,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Letter Spacing: ${letterSpacing.toStringAsFixed(1)}'),
        Slider(
          value: letterSpacing,
          min: -2.0,
          max: 10.0,
          onChanged: onLetterSpacingChanged,
        ),
        const SizedBox(height: 4),
        Text('Line Height: ${lineHeight.toStringAsFixed(2)}'),
        Slider(
          value: lineHeight,
          min: 0.8,
          max: 2.0,
          onChanged: onLineHeightChanged,
        ),
        const SizedBox(height: 4),
        Text('Font Size: ${(fontSize * 100).toInt()}%'),
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

/// Text alignment selector tab (`Left`, `Center`, `Right`).
class QuoteCardAlignmentTab extends StatelessWidget {
  final TextAlign textAlign;
  final ValueChanged<TextAlign> onChanged;

  const QuoteCardAlignmentTab({
    super.key,
    required this.textAlign,
    required this.onChanged,
  });

  static const _options = <Map<String, Object>>[
    {'icon': Icons.format_align_left, 'align': TextAlign.left, 'label': 'Left'},
    {
      'icon': Icons.format_align_center,
      'align': TextAlign.center,
      'label': 'Center',
    },
    {
      'icon': Icons.format_align_right,
      'align': TextAlign.right,
      'label': 'Right',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return QuoteCardSectionCard(
      icon: Icons.format_align_center,
      iconColor: Colors.blueGrey.shade600,
      title: 'Text Align',
      child: Row(
        children: _options.map((opt) {
          final align = opt['align']! as TextAlign;
          final isSelected = textAlign == align;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(align),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueGrey.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blueGrey : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opt['icon']! as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.blueGrey
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        opt['label']! as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.blueGrey
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Background image fit and color filter tab.
class QuoteCardBackgroundTab extends StatelessWidget {
  final File? backgroundImage;
  final BoxFit backgroundFit;
  final double backgroundScale;
  final double backgroundBlur;
  final double backgroundBrightness;
  final double backgroundSaturation;
  final ValueChanged<BoxFit> onFitChanged;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<double> onBlurChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onSaturationChanged;
  final VoidCallback onResetAll;

  const QuoteCardBackgroundTab({
    super.key,
    required this.backgroundImage,
    required this.backgroundFit,
    required this.backgroundScale,
    required this.backgroundBlur,
    required this.backgroundBrightness,
    required this.backgroundSaturation,
    required this.onFitChanged,
    required this.onScaleChanged,
    required this.onBlurChanged,
    required this.onBrightnessChanged,
    required this.onSaturationChanged,
    required this.onResetAll,
  });

  static const _fits = <Map<String, Object>>[
    {'label': 'Cover', 'fit': BoxFit.cover},
    {'label': 'Contain', 'fit': BoxFit.contain},
    {'label': 'Fill', 'fit': BoxFit.fill},
    {'label': 'Fit Width', 'fit': BoxFit.fitWidth},
    {'label': 'Fit Height', 'fit': BoxFit.fitHeight},
    {'label': 'None', 'fit': BoxFit.none},
  ];

  @override
  Widget build(BuildContext context) {
    if (backgroundImage == null) {
      return const Center(
        child: Text('Add a background image first to see options'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image Fit', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _fits.map((f) {
            final fit = f['fit']! as BoxFit;
            return ChoiceChip(
              label: Text(f['label']! as String),
              selected: backgroundFit == fit,
              onSelected: (selected) {
                if (selected) onFitChanged(fit);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        QuoteCardSliderRow(
          label: 'Scale',
          value: backgroundScale,
          min: 0.5,
          max: 3.0,
          labelWidth: 80,
          fontSize: 14,
          boldLabel: true,
          onChanged: onScaleChanged,
        ),
        QuoteCardSliderRow(
          label: 'Blur',
          value: backgroundBlur,
          min: 0.0,
          max: 15.0,
          labelWidth: 80,
          fontSize: 14,
          boldLabel: true,
          onChanged: onBlurChanged,
        ),
        QuoteCardSliderRow(
          label: 'Brightness',
          value: backgroundBrightness,
          min: 0.0,
          max: 2.0,
          labelWidth: 80,
          fontSize: 14,
          boldLabel: true,
          onChanged: onBrightnessChanged,
        ),
        QuoteCardSliderRow(
          label: 'Saturation',
          value: backgroundSaturation,
          min: 0.0,
          max: 2.0,
          labelWidth: 80,
          fontSize: 14,
          boldLabel: true,
          onChanged: onSaturationChanged,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: onResetAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset All Filters'),
          ),
        ),
        const Text(
          'Tip: Drag the background image in the preview to adjust its position.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

