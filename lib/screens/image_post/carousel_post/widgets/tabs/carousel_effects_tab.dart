import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';
import '../carousel_word_selector.dart';

/// Effects tab panel: text fill, stroke over cutout, foreground outline-only,
/// stroke width & color, drop shadow blur/offset/color, and outer glow radius.
class CarouselEffectsTab extends StatelessWidget {
  final CarouselSlide slide;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final ValueChanged<bool> onMultiSelectChanged;
  final ValueChanged<Set<int>> onSelectedWordsChanged;
  final VoidCallback onPickStrokeColor;
  final VoidCallback onPickShadowColor;
  final VoidCallback onStateChanged;

  const CarouselEffectsTab({
    super.key,
    required this.slide,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    required this.onMultiSelectChanged,
    required this.onSelectedWordsChanged,
    required this.onPickStrokeColor,
    required this.onPickShadowColor,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool wordMode =
        slide.useWordMode && selectedWordIndices.isNotEmpty;

    final bool enableShadow = wordMode
        ? slide.wordTokens[selectedWordIndices.first].enableShadow
        : slide.enableShadow;
    final double shadowBlur = wordMode
        ? slide.wordTokens[selectedWordIndices.first].shadowBlur
        : slide.shadowBlur;
    final Offset shadowOffset = wordMode
        ? slide.wordTokens[selectedWordIndices.first].shadowOffset
        : slide.shadowOffset;
    final Color activeShadowColor = wordMode
        ? slide.wordTokens[selectedWordIndices.first].shadowColor
        : slide.shadowColor;

    final bool enableGlow = wordMode
        ? slide.wordTokens[selectedWordIndices.first].enableGlow
        : slide.enableGlow;
    final double glowRadius = wordMode
        ? slide.wordTokens[selectedWordIndices.first].glowRadius
        : slide.glowRadius;

    final double strokeWidth = wordMode
        ? slide.wordTokens[selectedWordIndices.first].strokeWidth
        : slide.textStrokeWidth;
    final Color activeStrokeColor = wordMode
        ? slide.wordTokens[selectedWordIndices.first].strokeColor
        : slide.textStrokeColor;

    final bool textFill = wordMode
        ? slide.wordTokens[selectedWordIndices.first].textFill
        : slide.textFill;
    final bool strokeOverForeground = wordMode
        ? slide.wordTokens[selectedWordIndices.first].strokeOverForeground
        : slide.strokeOverForeground;
    final bool fgStrokeOnly = wordMode
        ? slide.wordTokens[selectedWordIndices.first].fgStrokeOnly
        : slide.fgStrokeOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.useWordMode && slide.wordTokens.isNotEmpty) ...[
          CarouselWordSelector(
            slide: slide,
            selectedWordIndices: selectedWordIndices,
            multiSelectMode: multiSelectMode,
            onMultiSelectChanged: onMultiSelectChanged,
            onSelectedWordsChanged: onSelectedWordsChanged,
            onStateChanged: onStateChanged,
          ),
          const Divider(height: 32),
        ],
        CarouselSectionHeader(
          title: wordMode
              ? 'Effects for ${selectedWordIndices.length} words'
              : 'Text Styling',
        ),
        _buildSwitchRow(
          label: 'Text Fill',
          value: textFill,
          onChanged: (v) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].textFill = v;
              }
            } else {
              slide.textFill = v;
            }
            onStateChanged();
          },
        ),
        _buildSwitchRow(
          label: 'Stroke Over Cutout',
          value: strokeOverForeground,
          onChanged: (v) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].strokeOverForeground = v;
              }
            } else {
              slide.strokeOverForeground = v;
            }
            onStateChanged();
          },
        ),
        _buildSwitchRow(
          label: 'Foreground Stroke Only',
          value: fgStrokeOnly,
          onChanged: (v) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].fgStrokeOnly = v;
              }
            } else {
              slide.fgStrokeOnly = v;
            }
            onStateChanged();
          },
        ),
        CarouselInlineSlider(
          label: 'Stroke Width',
          value: strokeWidth.clamp(0.0, 10.0),
          min: 0,
          max: 10,
          onChanged: (v) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].strokeWidth = v;
              }
            } else {
              slide.textStrokeWidth = v;
            }
            onStateChanged();
          },
        ),
        if (strokeWidth > 0) ...[
          const SizedBox(height: 12),
          const CarouselSectionHeader(title: 'Stroke Color'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CarouselCircularCustomColorOption(
                  rightPadding: 16,
                  onTap: onPickStrokeColor,
                ),
                _strokeSwatch(
                  Colors.black,
                  'Black',
                  activeStrokeColor,
                  wordMode,
                ),
                _strokeSwatch(
                  Colors.white,
                  'White',
                  activeStrokeColor,
                  wordMode,
                ),
                _strokeSwatch(
                  const Color(0xFF6C63FF),
                  'Royal',
                  activeStrokeColor,
                  wordMode,
                ),
                _strokeSwatch(
                  Colors.red.shade900,
                  'Ruby',
                  activeStrokeColor,
                  wordMode,
                ),
                _strokeSwatch(
                  Colors.green.shade900,
                  'Forest',
                  activeStrokeColor,
                  wordMode,
                ),
              ],
            ),
          ),
          const Divider(),
        ],
        SwitchListTile(
          title: const Text('Drop Shadow', style: TextStyle(fontSize: 12)),
          value: enableShadow,
          onChanged: (v) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].enableShadow = v;
              }
            } else {
              slide.enableShadow = v;
            }
            onStateChanged();
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (enableShadow) ...[
          CarouselInlineSlider(
            label: 'Blur',
            value: shadowBlur.clamp(0.0, 20.0),
            min: 0,
            max: 20,
            onChanged: (v) {
              if (wordMode) {
                for (final idx in selectedWordIndices) {
                  slide.wordTokens[idx].shadowBlur = v;
                }
              } else {
                slide.shadowBlur = v;
              }
              onStateChanged();
            },
          ),
          CarouselInlineSlider(
            label: 'Offset X',
            value: shadowOffset.dx.clamp(-10.0, 10.0),
            min: -10,
            max: 10,
            onChanged: (v) {
              if (wordMode) {
                for (final idx in selectedWordIndices) {
                  final prev = slide.wordTokens[idx].shadowOffset;
                  slide.wordTokens[idx].shadowOffset = Offset(v, prev.dy);
                }
              } else {
                slide.shadowOffset = Offset(v, slide.shadowOffset.dy);
              }
              onStateChanged();
            },
          ),
          CarouselInlineSlider(
            label: 'Offset Y',
            value: shadowOffset.dy.clamp(-10.0, 10.0),
            min: -10,
            max: 10,
            onChanged: (v) {
              if (wordMode) {
                for (final idx in selectedWordIndices) {
                  final prev = slide.wordTokens[idx].shadowOffset;
                  slide.wordTokens[idx].shadowOffset = Offset(prev.dx, v);
                }
              } else {
                slide.shadowOffset = Offset(slide.shadowOffset.dx, v);
              }
              onStateChanged();
            },
          ),
          const SizedBox(height: 12),
          const CarouselSectionHeader(title: 'Shadow Color'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CarouselCircularCustomColorOption(
                  rightPadding: 16,
                  onTap: onPickShadowColor,
                ),
                _shadowSwatch(
                  Colors.black,
                  'Black',
                  activeShadowColor,
                  wordMode,
                ),
                _shadowSwatch(
                  Colors.white,
                  'White',
                  activeShadowColor,
                  wordMode,
                ),
                _shadowSwatch(
                  const Color(0xFF424242),
                  'Grey',
                  activeShadowColor,
                  wordMode,
                ),
                _shadowSwatch(
                  Colors.red.shade900,
                  'Ruby',
                  activeShadowColor,
                  wordMode,
                ),
                _shadowSwatch(
                  Colors.indigo.shade900,
                  'Indigo',
                  activeShadowColor,
                  wordMode,
                ),
                _shadowSwatch(
                  const Color(0xFF6C63FF),
                  'Royal',
                  activeShadowColor,
                  wordMode,
                ),
              ],
            ),
          ),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Glow Effect', style: TextStyle(fontSize: 12)),
          value: enableGlow,
          onChanged: (v) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].enableGlow = v;
              }
            } else {
              slide.enableGlow = v;
            }
            onStateChanged();
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (enableGlow)
          CarouselInlineSlider(
            label: 'Radius',
            value: glowRadius.clamp(0.0, 30.0),
            min: 0,
            max: 30,
            onChanged: (v) {
              if (wordMode) {
                for (final idx in selectedWordIndices) {
                  slide.wordTokens[idx].glowRadius = v;
                }
              } else {
                slide.glowRadius = v;
              }
              onStateChanged();
            },
          ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Switch(
          value: value,
          activeThumbColor: const Color(0xFF6C63FF),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _strokeSwatch(
    Color color,
    String label,
    Color activeColor,
    bool wordMode,
  ) {
    return CarouselCircularColorOption(
      color: color,
      label: label,
      isSelected: activeColor == color,
      onTap: () {
        if (wordMode) {
          for (final idx in selectedWordIndices) {
            slide.wordTokens[idx].strokeColor = color;
          }
        } else {
          slide.textStrokeColor = color;
        }
        onStateChanged();
      },
    );
  }

  Widget _shadowSwatch(
    Color color,
    String label,
    Color activeColor,
    bool wordMode,
  ) {
    return CarouselCircularColorOption(
      color: color,
      label: label,
      isSelected: activeColor == color,
      onTap: () {
        if (wordMode) {
          for (final idx in selectedWordIndices) {
            slide.wordTokens[idx].shadowColor = color;
          }
        } else {
          slide.shadowColor = color;
        }
        onStateChanged();
      },
    );
  }
}
