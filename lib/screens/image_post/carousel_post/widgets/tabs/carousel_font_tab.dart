import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../../utils/custom_font_manager.dart';
import '../../../../../utils/font_selector.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';
import '../carousel_word_selector.dart';

/// Font tab panel: font selector with custom TTF/OTF import, plus global or
/// per-word font size and text scale sliders.
class CarouselFontTab extends StatelessWidget {
  final CarouselSlide slide;
  final FontInfo? selectedFont;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final ValueChanged<bool> onMultiSelectChanged;
  final ValueChanged<Set<int>> onSelectedWordsChanged;
  final VoidCallback onStateChanged;

  const CarouselFontTab({
    super.key,
    required this.slide,
    required this.selectedFont,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    required this.onMultiSelectChanged,
    required this.onSelectedWordsChanged,
    required this.onStateChanged,
  });

  Future<void> _pickCustomFonts(BuildContext context, bool wordMode) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    CustomFontEntry? lastEntry;
    for (final xFile in result.files) {
      if (xFile.path == null) continue;
      final path = xFile.path!;
      if (!path.toLowerCase().endsWith('.ttf') &&
          !path.toLowerCase().endsWith('.otf')) {
        continue;
      }
      final entry = await CustomFontManager().addFont(File(path));
      if (entry != null) lastEntry = entry;
    }

    if (lastEntry != null && context.mounted) {
      final newFont = FontInfo(
        family: lastEntry.familyName,
        displayName: lastEntry.displayName,
        isCustom: true,
        filePath: lastEntry.filePath,
      );
      if (wordMode) {
        for (final idx in selectedWordIndices) {
          slide.wordTokens[idx].font = newFont;
        }
      } else {
        slide.font = newFont;
      }
      onStateChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Custom font "${newFont.displayName}" added and applied!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool wordMode =
        slide.useWordMode && selectedWordIndices.isNotEmpty;
    final FontInfo? activeFont = (wordMode
            ? slide.wordTokens[selectedWordIndices.first].font
            : slide.font) ??
        selectedFont;
    final double activeFontSize = wordMode
        ? slide.wordTokens[selectedWordIndices.first].fontSize
        : slide.slideFontSize;

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
              ? 'Font for ${selectedWordIndices.length} words'
              : 'Typography',
        ),
        HorizontalFontSelector(
          selectedFont: activeFont,
          onFontSelected: (font) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].font = font;
              }
            } else {
              slide.font = font;
            }
            onStateChanged();
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickCustomFonts(context, wordMode),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload Custom Font'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
              side: const BorderSide(color: Color(0xFF6C63FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const Divider(height: 32),
        const CarouselSectionHeader(title: 'Sizing & Scale'),
        CarouselControlSlider(
          label: wordMode ? 'Font Size (Selected)' : 'Font Size',
          value: activeFontSize.clamp(10.0, 100.0),
          min: 10.0,
          max: 100.0,
          onChanged: (val) {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].fontSize = val;
              }
            } else {
              slide.slideFontSize = val;
            }
            onStateChanged();
          },
        ),
        const SizedBox(height: 8),
        CarouselControlSlider(
          label: 'Text Scale',
          value: slide.textScale.clamp(0.1, 3.0),
          min: 0.1,
          max: 3.0,
          onChanged: (val) {
            slide.textScale = val;
            onStateChanged();
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            if (wordMode) {
              for (final idx in selectedWordIndices) {
                slide.wordTokens[idx].fontSize = 28.0;
              }
            } else {
              slide.slideFontSize = 28.0;
            }
            slide.textScale = 1.0;
            onStateChanged();
          },
          child: const Text('Reset Text Sizes'),
        ),
      ],
    );
  }
}
