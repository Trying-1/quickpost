import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';
import '../carousel_word_selector.dart';

/// Style/Color tab panel: slide background swatches (with auto contrast text)
/// and text color swatches (supports per-word coloring when in word mode).
class CarouselStyleTab extends StatelessWidget {
  final CarouselSlide slide;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final ValueChanged<bool> onMultiSelectChanged;
  final ValueChanged<Set<int>> onSelectedWordsChanged;
  final VoidCallback onPickCustomBgColor;
  final VoidCallback onPickCustomTextColor;
  final VoidCallback onStateChanged;

  const CarouselStyleTab({
    super.key,
    required this.slide,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    required this.onMultiSelectChanged,
    required this.onSelectedWordsChanged,
    required this.onPickCustomBgColor,
    required this.onPickCustomTextColor,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool wordMode =
        slide.useWordMode && selectedWordIndices.isNotEmpty;
    final Color activeTextColor = wordMode
        ? slide.wordTokens[selectedWordIndices.first].color
        : slide.textColor;

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
        const CarouselSectionHeader(title: 'Slide Background'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              CarouselCircularCustomColorOption(
                rightPadding: 16,
                onTap: onPickCustomBgColor,
              ),
              _bgSwatch(const Color(0xFF121212), Colors.white, 'Ink'),
              _bgSwatch(Colors.white, const Color(0xFF121212), 'Snow'),
              _bgSwatch(const Color(0xFFFF4E50), Colors.white, 'Sunset'),
              _bgSwatch(const Color(0xFF6C63FF), Colors.white, 'Royal'),
              _bgSwatch(const Color(0xFF00D2FF), Colors.white, 'Ocean'),
              _bgSwatch(const Color(0xFFFC67FA), Colors.white, 'Electric'),
              _bgSwatch(
                  const Color(0xFF00F260), const Color(0xFF121212), 'Cyber'),
              _bgSwatch(
                  const Color(0xFFFDC830), const Color(0xFF121212), 'Gold'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CarouselSectionHeader(
          title: wordMode
              ? 'Color for ${selectedWordIndices.length} words'
              : 'Text Color',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              CarouselCircularCustomColorOption(
                rightPadding: 16,
                onTap: onPickCustomTextColor,
              ),
              _textSwatch(Colors.white, 'Bright', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFF121212), 'Dark', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFFFF4E50), 'Sunset', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFF6C63FF), 'Royal', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFF00D2FF), 'Ocean', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFFFC67FA), 'Neon', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFF00F260), 'Cyber', activeTextColor, wordMode),
              _textSwatch(
                  const Color(0xFFFDC830), 'Gold', activeTextColor, wordMode),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bgSwatch(Color bg, Color contrastText, String label) {
    return CarouselCircularColorOption(
      color: bg,
      label: label,
      isSelected: slide.bgColor == bg,
      onTap: () {
        slide.bgColor = bg;
        if (slide.textColor == Colors.white ||
            slide.textColor == const Color(0xFF121212)) {
          slide.textColor = contrastText;
        }
        onStateChanged();
      },
    );
  }

  Widget _textSwatch(
    Color color,
    String label,
    Color activeTextColor,
    bool wordMode,
  ) {
    return CarouselCircularColorOption(
      color: color,
      label: label,
      isSelected: activeTextColor == color,
      onTap: () {
        if (wordMode) {
          for (final idx in selectedWordIndices) {
            slide.wordTokens[idx].color = color;
          }
        } else {
          slide.textColor = color;
        }
        onStateChanged();
      },
    );
  }
}
