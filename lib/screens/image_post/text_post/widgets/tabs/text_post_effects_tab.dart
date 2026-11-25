import 'package:flutter/material.dart';
import '../text_post_shared_controls.dart';

/// Effects tab (index 3): Warp, Text Shadow, Text Glow, and Box Backdrop arranged compactly.
class TextPostEffectsTab extends StatelessWidget {
  final bool isMain;
  final String warpType;
  final double warpIntensity;
  final bool showShadow;
  final Color shadowColor;
  final double shadowX;
  final double shadowY;
  final double shadowBlur;
  final bool showGlow;
  final Color glowColor;
  final double glowRadius;
  final bool showBox;
  final double boxOpacity;
  final double boxRadius;
  final bool textFill;
  final bool showStroke;
  final Color strokeColor;
  final double strokeWidth;

  final ValueChanged<String> onWarpTypeChanged;
  final ValueChanged<double> onWarpIntensityChanged;
  final ValueChanged<bool> onShowShadowChanged;
  final VoidCallback onPickShadowColor;
  final ValueChanged<double> onShadowXChanged;
  final ValueChanged<double> onShadowYChanged;
  final ValueChanged<double> onShadowBlurChanged;
  final ValueChanged<bool> onShowGlowChanged;
  final VoidCallback onPickGlowColor;
  final ValueChanged<double> onGlowRadiusChanged;
  final ValueChanged<bool> onShowBoxChanged;
  final ValueChanged<double> onBoxOpacityChanged;
  final ValueChanged<double> onBoxRadiusChanged;
  final ValueChanged<bool> onTextFillChanged;
  final ValueChanged<bool> onShowStrokeChanged;
  final ValueChanged<Color> onStrokeColorSelected;
  final VoidCallback onPickStrokeColor;
  final ValueChanged<double> onStrokeWidthChanged;

  const TextPostEffectsTab({
    super.key,
    required this.isMain,
    required this.warpType,
    required this.warpIntensity,
    required this.showShadow,
    required this.shadowColor,
    required this.shadowX,
    required this.shadowY,
    required this.shadowBlur,
    required this.showGlow,
    required this.glowColor,
    required this.glowRadius,
    required this.showBox,
    required this.boxOpacity,
    required this.boxRadius,
    required this.textFill,
    required this.showStroke,
    required this.strokeColor,
    required this.strokeWidth,
    required this.onWarpTypeChanged,
    required this.onWarpIntensityChanged,
    required this.onShowShadowChanged,
    required this.onPickShadowColor,
    required this.onShadowXChanged,
    required this.onShadowYChanged,
    required this.onShadowBlurChanged,
    required this.onShowGlowChanged,
    required this.onPickGlowColor,
    required this.onGlowRadiusChanged,
    required this.onShowBoxChanged,
    required this.onBoxOpacityChanged,
    required this.onBoxRadiusChanged,
    required this.onTextFillChanged,
    required this.onShowStrokeChanged,
    required this.onStrokeColorSelected,
    required this.onPickStrokeColor,
    required this.onStrokeWidthChanged,
  });

  static const _warpTypes = [
    ('Flat', 'none'),
    ('Arc', 'arc'),
    ('Cylinder', 'cylinder'),
    ('Bulge', 'bulge'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warp chips inline
        Row(
          children: [
            const Text(
              'Warp',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _warpTypes.map((w) {
                    final selected = warpType == w.$2;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(w.$1, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) => onWarpTypeChanged(w.$2),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        if (warpType != 'none') ...[
          const SizedBox(height: 6),
          TextPostSimpleSlider(
            label: 'Warp Intensity',
            value: warpIntensity,
            min: -1.0,
            max: 1.0,
            onChanged: onWarpIntensityChanged,
            onReset: () => onWarpIntensityChanged(0.0),
            step: 0.1,
          ),
        ],
        const Divider(height: 16),

        // Shadow toggle + inline color swatch
        Row(
          children: [
            const Text(
              'Shadow',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 8),
            if (showShadow)
              _InlineColorDot(color: shadowColor, onTap: onPickShadowColor),
            const Spacer(),
            Switch(
              value: showShadow,
              onChanged: onShowShadowChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (showShadow) ...[
          const SizedBox(height: 4),
          TextPostTwoCol(
            left: TextPostSimpleSlider(
              label: 'Offset X',
              value: shadowX,
              min: -20,
              max: 20,
              onChanged: onShadowXChanged,
              onReset: () => onShadowXChanged(2.0),
              step: 1.0,
            ),
            right: TextPostSimpleSlider(
              label: 'Offset Y',
              value: shadowY,
              min: -20,
              max: 20,
              onChanged: onShadowYChanged,
              onReset: () => onShadowYChanged(2.0),
              step: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          TextPostSimpleSlider(
            label: 'Shadow Blur',
            value: shadowBlur,
            min: 0,
            max: 20,
            onChanged: onShadowBlurChanged,
            onReset: () => onShadowBlurChanged(isMain ? 5.0 : 4.0),
            step: 1.0,
          ),
        ],
        const Divider(height: 14),

        // Glow toggle + inline color swatch + size
        Row(
          children: [
            const Text(
              'Glow',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 8),
            if (showGlow)
              _InlineColorDot(color: glowColor, onTap: onPickGlowColor),
            const Spacer(),
            Switch(
              value: showGlow,
              onChanged: onShowGlowChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (showGlow) ...[
          const SizedBox(height: 4),
          TextPostSimpleSlider(
            label: 'Glow Size',
            value: glowRadius,
            min: 0,
            max: 50,
            onChanged: onGlowRadiusChanged,
            onReset: () => onGlowRadiusChanged(10.0),
            step: 1.0,
          ),
        ],
        const Divider(height: 14),

        // Outline / Stroke & Fill
        Row(
          children: [
            const Text(
              'Text Fill',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Text(
              textFill ? '(Solid)' : '(Outline only)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const Spacer(),
            Switch(
              value: textFill,
              onChanged: onTextFillChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        Row(
          children: [
            const Text(
              'Text Outline',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (showStroke) ...[
              const SizedBox(width: 8),
              _InlineColorDot(color: strokeColor, onTap: onPickStrokeColor),
            ],
            const Spacer(),
            Switch(
              value: showStroke,
              onChanged: onShowStrokeChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (showStroke || !textFill) ...[
          const SizedBox(height: 4),
          TextPostSimpleSlider(
            label: warpType == 'none'
                ? 'Outline Width'
                : 'Outline Width (Flat warp only)',
            value: strokeWidth,
            min: 0.5,
            max: 12.0,
            onChanged: onStrokeWidthChanged,
            onReset: () => onStrokeWidthChanged(2.0),
            step: 0.5,
          ),
          const SizedBox(height: 6),
          TextPostColorPickerRow(
            label: 'Outline Color',
            currentColor: strokeColor,
            onColorSelected: onStrokeColorSelected,
            onPickCustom: onPickStrokeColor,
            allowTransparent: false,
          ),
        ],
        const Divider(height: 14),

        // Text Box backdrop
        Row(
          children: [
            const Text(
              'Box Backdrop',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Spacer(),
            Switch(
              value: showBox,
              onChanged: onShowBoxChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (showBox) ...[
          const SizedBox(height: 4),
          TextPostTwoCol(
            left: TextPostSimpleSlider(
              label: 'Opacity',
              value: boxOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: onBoxOpacityChanged,
              onReset: () => onBoxOpacityChanged(0.8),
              step: 0.05,
            ),
            right: TextPostSimpleSlider(
              label: 'Radius',
              value: boxRadius,
              min: 0.0,
              max: 50.0,
              onChanged: onBoxRadiusChanged,
              onReset: () => onBoxRadiusChanged(8.0),
              step: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _InlineColorDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400),
        ),
      ),
    );
  }
}
