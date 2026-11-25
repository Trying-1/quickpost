import 'package:flutter/material.dart';
import '../../../../../utils/font_selector.dart';
import '../../models/text_post_overlays.dart';
import '../../models/text_post_presets.dart';
import '../text_post_shared_controls.dart';

/// Text tab (index 0): compact layer switcher chips, My Quotes import/save, and editor.
class TextPostTextTab extends StatefulWidget {
  final int selectedTextIndex;
  final TextEditingController mainController;
  final List<TextPostTextOverlay> textOverlays;
  final FontInfo? defaultFont;
  final Color defaultColor;
  final VoidCallback onImportFromMyQuotes;
  final ValueChanged<String> onSaveToMyQuotes;
  final ValueChanged<int> onSelectLayer;
  final ValueChanged<int> onAddLayer;
  final ValueChanged<TextPostTextCase> onTransformCase;
  final VoidCallback? onDuplicateLayer;
  final VoidCallback onStateChanged;

  const TextPostTextTab({
    super.key,
    required this.selectedTextIndex,
    required this.mainController,
    required this.textOverlays,
    required this.defaultFont,
    required this.defaultColor,
    required this.onImportFromMyQuotes,
    required this.onSaveToMyQuotes,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onTransformCase,
    this.onDuplicateLayer,
    required this.onStateChanged,
  });

  @override
  State<TextPostTextTab> createState() => _TextPostTextTabState();
}

class _TextPostTextTabState extends State<TextPostTextTab> {
  late final TextEditingController _overlayController;

  bool get _isMain => widget.selectedTextIndex == -1;

  bool get _hasValidOverlay =>
      !_isMain &&
      widget.selectedTextIndex >= 0 &&
      widget.selectedTextIndex < widget.textOverlays.length;

  @override
  void initState() {
    super.initState();
    _overlayController = TextEditingController(
      text: _hasValidOverlay
          ? widget.textOverlays[widget.selectedTextIndex].text
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant TextPostTextTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasValidOverlay) {
      final target = widget.textOverlays[widget.selectedTextIndex].text;
      if (_overlayController.text != target) {
        _overlayController.value = TextEditingValue(
          text: target,
          selection: TextSelection.collapsed(offset: target.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMain && !_hasValidOverlay) {
      return const Center(child: Text('Please select a valid layer'));
    }

    final TextEditingController effectiveController =
        _isMain ? widget.mainController : _overlayController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inline layer chips + quote shortcuts
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _layerChip(
                label: 'Main',
                selected: _isMain,
                onTap: () => widget.onSelectLayer(-1),
              ),
              ...widget.textOverlays.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _layerChip(
                    label: 'L${entry.key + 1}',
                    selected: widget.selectedTextIndex == entry.key,
                    onTap: () => widget.onSelectLayer(entry.key),
                    onDelete: () {
                      widget.textOverlays.removeAt(entry.key);
                      widget.onSelectLayer(-1);
                      widget.onStateChanged();
                    },
                  ),
                );
              }),
              const SizedBox(width: 6),
              _actionPill(
                icon: Icons.add,
                label: 'Layer',
                color: Colors.blueAccent,
                onTap: () {
                  widget.textOverlays.add(
                    TextPostTextOverlay(
                      text: 'New Text',
                      font: widget.defaultFont,
                      color: widget.defaultColor,
                    ),
                  );
                  widget.onAddLayer(widget.textOverlays.length - 1);
                },
              ),
              const SizedBox(width: 6),
              _actionPill(
                icon: Icons.format_quote_rounded,
                label: 'Quotes',
                color: Colors.blueGrey.shade700,
                onTap: widget.onImportFromMyQuotes,
              ),
              const SizedBox(width: 6),
              _actionPill(
                icon: Icons.bookmark_add_outlined,
                label: 'Save Quote',
                color: Colors.green.shade700,
                onTap: () => widget.onSaveToMyQuotes(effectiveController.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: effectiveController,
          maxLines: 3,
          minLines: 2,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText:
                _isMain ? 'Type your post text here...' : 'Edit overlay text...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              onPressed: () {
                effectiveController.clear();
                if (_hasValidOverlay) {
                  widget.textOverlays[widget.selectedTextIndex].text = '';
                }
                widget.onStateChanged();
              },
            ),
          ),
          onChanged: (v) {
            if (_hasValidOverlay) {
              widget.textOverlays[widget.selectedTextIndex].text = v;
            }
            widget.onStateChanged();
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'Case:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 6),
            _caseChip('AA', TextPostTextCase.upper),
            const SizedBox(width: 4),
            _caseChip('aa', TextPostTextCase.lower),
            const SizedBox(width: 4),
            _caseChip('Title', TextPostTextCase.title),
            const SizedBox(width: 4),
            _caseChip('Sent.', TextPostTextCase.sentence),
            const Spacer(),
            if (!_isMain && widget.onDuplicateLayer != null)
              _actionPill(
                icon: Icons.copy,
                label: 'Duplicate',
                color: Colors.teal,
                onTap: widget.onDuplicateLayer!,
              ),
          ],
        ),
      ],
    );
  }

  Widget _caseChip(String label, TextPostTextCase textCase) {
    return InkWell(
      onTap: () => widget.onTransformCase(textCase),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _layerChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: 10,
          right: onDelete != null ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 13,
                  color: selected ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Unified Typography tab (index 1): Font selector, Text Align, Size, Scale, Letter Spacing, Line Height.
class TextPostTypographyTab extends StatelessWidget {
  final bool isMain;
  final FontInfo? selectedFont;
  final TextAlign currentAlign;
  final double fontSize;
  final double textScale;
  final double letterSpacing;
  final double lineHeight;
  final double opacity;
  final double rotation;
  final ValueChanged<FontInfo> onFontSelected;
  final ValueChanged<TextAlign> onAlignChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onTextScaleChanged;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onRotationChanged;

  const TextPostTypographyTab({
    super.key,
    required this.isMain,
    required this.selectedFont,
    required this.currentAlign,
    required this.fontSize,
    required this.textScale,
    required this.letterSpacing,
    required this.lineHeight,
    required this.opacity,
    required this.rotation,
    required this.onFontSelected,
    required this.onAlignChanged,
    required this.onFontSizeChanged,
    required this.onTextScaleChanged,
    required this.onLetterSpacingChanged,
    required this.onLineHeightChanged,
    required this.onOpacityChanged,
    required this.onRotationChanged,
  });

  static const _alignOptions = [
    (Icons.format_align_left_rounded, TextAlign.left),
    (Icons.format_align_center_rounded, TextAlign.center),
    (Icons.format_align_right_rounded, TextAlign.right),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top header row: Font label + compact Align toggles
        Row(
          children: [
            const Text(
              'Font & Alignment',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _alignOptions.map((opt) {
                  final selected = currentAlign == opt.$2;
                  return InkWell(
                    onTap: () => onAlignChanged(opt.$2),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected ? Colors.indigo : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        opt.$1,
                        size: 15,
                        color: selected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        HorizontalFontSelector(
          selectedFont: selectedFont,
          onFontSelected: onFontSelected,
        ),
        const SizedBox(height: 10),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Font Size',
            value: fontSize,
            min: isMain ? 0.5 : 10.0,
            max: isMain ? 2.0 : 200.0,
            onChanged: onFontSizeChanged,
            onReset: () => onFontSizeChanged(isMain ? 0.5 : 24.0),
            step: isMain ? 0.1 : 1.0,
          ),
          right: TextPostSimpleSlider(
            label: 'Text Scale',
            value: textScale,
            min: 0.2,
            max: 4.0,
            onChanged: onTextScaleChanged,
            onReset: () => onTextScaleChanged(1.0),
            step: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Letter Spacing',
            value: letterSpacing,
            min: -2.0,
            max: 10.0,
            onChanged: onLetterSpacingChanged,
            onReset: () => onLetterSpacingChanged(0.0),
            step: 0.5,
          ),
          right: TextPostSimpleSlider(
            label: 'Line Height',
            value: lineHeight,
            min: 0.8,
            max: 2.0,
            onChanged: onLineHeightChanged,
            onReset: () => onLineHeightChanged(1.2),
            step: 0.05,
          ),
        ),
        const SizedBox(height: 6),
        TextPostTwoCol(
          left: TextPostSimpleSlider(
            label: 'Opacity',
            value: opacity,
            min: 0.1,
            max: 1.0,
            onChanged: onOpacityChanged,
            onReset: () => onOpacityChanged(1.0),
            step: 0.05,
          ),
          right: TextPostSimpleSlider(
            label: 'Rotation',
            value: rotation,
            min: -180.0,
            max: 180.0,
            onChanged: onRotationChanged,
            onReset: () => onRotationChanged(0.0),
            step: 5.0,
          ),
        ),
      ],
    );
  }
}

/// Colors tab (index 2): quick style presets, text color, box color, and solid/gradient canvas background.
class TextPostColorsTab extends StatelessWidget {
  final bool isMain;
  final bool showMainBox;
  final Color activeTextColor;
  final Color activeBoxColor;
  final Color canvasBackgroundColor;
  final bool bgUseGradient;
  final Color bgColor2;
  final double bgGradientAngle;
  final ValueChanged<Color> onTextColorSelected;
  final ValueChanged<Color> onBoxColorSelected;
  final ValueChanged<Color> onCanvasBackgroundSelected;
  final VoidCallback onPickCustomTextColor;
  final VoidCallback onPickCustomBoxColor;
  final VoidCallback onPickCustomCanvasBackground;
  final ValueChanged<bool> onBgUseGradientChanged;
  final ValueChanged<Color> onBgColor2Selected;
  final VoidCallback onPickCustomBgColor2;
  final ValueChanged<double> onBgGradientAngleChanged;
  final ValueChanged<TextPostGradientPreset> onApplyGradientPreset;
  final ValueChanged<TextPostStylePreset> onApplyStylePreset;

  const TextPostColorsTab({
    super.key,
    required this.isMain,
    required this.showMainBox,
    required this.activeTextColor,
    required this.activeBoxColor,
    required this.canvasBackgroundColor,
    required this.bgUseGradient,
    required this.bgColor2,
    required this.bgGradientAngle,
    required this.onTextColorSelected,
    required this.onBoxColorSelected,
    required this.onCanvasBackgroundSelected,
    required this.onPickCustomTextColor,
    required this.onPickCustomBoxColor,
    required this.onPickCustomCanvasBackground,
    required this.onBgUseGradientChanged,
    required this.onBgColor2Selected,
    required this.onPickCustomBgColor2,
    required this.onBgGradientAngleChanged,
    required this.onApplyGradientPreset,
    required this.onApplyStylePreset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMain) ...[
          const Text(
            'Quick Style Presets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: TextPostPresets.styles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, idx) {
                final preset = TextPostPresets.styles[idx];
                return InkWell(
                  onTap: () => onApplyStylePreset(preset),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: preset.useGradient
                          ? LinearGradient(
                              colors: [preset.bgColor1, preset.bgColor2],
                            )
                          : null,
                      color: preset.useGradient ? null : preset.bgColor1,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: preset.textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextPostColorPickerRow(
          label: 'Text Color',
          currentColor: activeTextColor,
          onColorSelected: onTextColorSelected,
          onPickCustom: onPickCustomTextColor,
          allowTransparent: false,
        ),
        if (!isMain || showMainBox) ...[
          const SizedBox(height: 10),
          TextPostColorPickerRow(
            label: isMain ? 'Text Box Color' : 'Box Color',
            currentColor: activeBoxColor,
            onColorSelected: onBoxColorSelected,
            onPickCustom: onPickCustomBoxColor,
            allowTransparent: true,
          ),
        ],
        if (isMain) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Canvas Fill',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('Solid')),
                  ButtonSegment(value: true, label: Text('Gradient')),
                ],
                selected: {bgUseGradient},
                onSelectionChanged: (s) => onBgUseGradientChanged(s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextPostColorPickerRow(
            label: bgUseGradient ? 'Gradient Start' : 'Canvas Background',
            currentColor: canvasBackgroundColor,
            onColorSelected: onCanvasBackgroundSelected,
            onPickCustom: onPickCustomCanvasBackground,
            allowTransparent: !bgUseGradient,
          ),
          if (bgUseGradient) ...[
            const SizedBox(height: 8),
            TextPostColorPickerRow(
              label: 'Gradient End',
              currentColor: bgColor2,
              onColorSelected: onBgColor2Selected,
              onPickCustom: onPickCustomBgColor2,
              allowTransparent: false,
            ),
            const SizedBox(height: 6),
            TextPostSimpleSlider(
              label: 'Gradient Angle',
              value: bgGradientAngle,
              min: 0.0,
              max: 360.0,
              onChanged: onBgGradientAngleChanged,
              onReset: () => onBgGradientAngleChanged(135.0),
              step: 15.0,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: TextPostPresets.gradients.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, idx) {
                  final g = TextPostPresets.gradients[idx];
                  return InkWell(
                    onTap: () => onApplyGradientPreset(g),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [g.color1, g.color2]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white54),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        g.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }
}
