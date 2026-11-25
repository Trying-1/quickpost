import 'package:flutter/material.dart';
import '../../../../utils/font_selector.dart';

/// Aspect ratio preset option for Quote Card posts.
class QuoteCardAspectOption {
  final String label;
  final int index;
  final double aspectRatio;
  final int exportWidth;
  final int exportHeight;

  const QuoteCardAspectOption({
    required this.label,
    required this.index,
    required this.aspectRatio,
    required this.exportWidth,
    required this.exportHeight,
  });
}

/// Supported aspect ratio presets (`0: 4:5`, `1: 1:1`, `2: 9:16`, `3: 16:9`).
const List<QuoteCardAspectOption> quoteCardAspectOptions = [
  QuoteCardAspectOption(
    label: '4:5',
    index: 0,
    aspectRatio: 4 / 5,
    exportWidth: 1080,
    exportHeight: 1350,
  ),
  QuoteCardAspectOption(
    label: '1:1',
    index: 1,
    aspectRatio: 1 / 1,
    exportWidth: 1080,
    exportHeight: 1080,
  ),
  QuoteCardAspectOption(
    label: '9:16',
    index: 2,
    aspectRatio: 9 / 16,
    exportWidth: 1080,
    exportHeight: 1920,
  ),
  QuoteCardAspectOption(
    label: '16:9',
    index: 3,
    aspectRatio: 16 / 9,
    exportWidth: 1920,
    exportHeight: 1080,
  ),
];

/// Returns the [QuoteCardAspectOption] for [index], defaulting to `4:5`.
QuoteCardAspectOption quoteCardAspectForIndex(int index) {
  for (final option in quoteCardAspectOptions) {
    if (option.index == index) return option;
  }
  return quoteCardAspectOptions.first;
}

/// Converts [TextAlign] to persisted template index (`0: left`, `1: center`, `2: right`).
int textAlignToIndex(TextAlign align) {
  switch (align) {
    case TextAlign.left:
      return 0;
    case TextAlign.right:
      return 2;
    case TextAlign.center:
    case TextAlign.justify:
    case TextAlign.start:
    case TextAlign.end:
      return 1;
  }
}

/// Converts a persisted template index back into [TextAlign].
TextAlign indexToTextAlign(int index) {
  switch (index) {
    case 0:
      return TextAlign.left;
    case 2:
      return TextAlign.right;
    case 1:
    default:
      return TextAlign.center;
  }
}

/// Looks up a [FontInfo] matching [family] across built-in and custom fonts.
FontInfo? fontInfoFromFamily(String? family) {
  if (family == null) return null;
  for (final f in getAllFonts()) {
    if (f.family == family) return f;
  }
  return null;
}

/// Default quote font used when initializing a Quote Card post.
FontInfo defaultQuoteCardFont() {
  return const FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
}

