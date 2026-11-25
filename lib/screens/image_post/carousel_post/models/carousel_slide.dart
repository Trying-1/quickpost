import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../models/word_token.dart';
import '../../../../utils/font_selector.dart';

/// Mutable state model for a single slide in [CarouselPostScreen].
class CarouselSlide {
  File? image;
  File? foregroundImage;
  ui.Image? uiForegroundImage;
  String text = '';
  Color bgColor = Colors.black87;
  Color textColor = Colors.white;
  GlobalKey previewKey = GlobalKey();
  TransformationController transformationController =
      TransformationController();

  // Text Effects (defaults for new words)
  bool enableShadow = true;
  double shadowBlur = 4.0;
  Offset shadowOffset = const Offset(2, 2);
  Color shadowColor = Colors.black54;

  bool enableGlow = false;
  double glowRadius = 10.0;
  Color glowColor = Colors.white70;

  // Text Stroke & Fill
  double textStrokeWidth = 0.0;
  Color textStrokeColor = Colors.black;
  bool textFill = true;
  bool strokeOverForeground = false;
  bool fgStrokeOnly = false;

  // Image Adjustments (Background)
  double brightness = 1.0; // 0.0 to 2.0 (multiplicative/gain)
  double saturation = 1.0; // 0.0 to 2.0
  double hue = 0.0; // -3.14 to 3.14

  // Image Adjustments (Foreground)
  double fgBrightness = 1.0;
  double fgSaturation = 1.0;
  double fgHue = 0.0;
  double fgOpacity = 1.0;
  double feathering = 0.0;

  // Typography Adjustments
  double slideFontSize = 28.0;
  double textScale = 1.0;
  double letterSpacing = 0.0;
  double wordSpacing = 0.0;
  double lineHeight = 1.2;

  Alignment textAlignment = Alignment.center;
  FontInfo? font;

  // Mask Settings
  Color maskColor = Colors.black;
  double maskOpacity = 0.5;
  int maskType = 0; // 0: None, 1: Bottom, 2: Top, 3: Full, 4: Left, 5: Right
  double maskStart = 0.0;
  double maskEnd = 1.0;

  // Per-word tokens
  List<WordToken> wordTokens = [];
  bool useWordMode = false;
  bool isLocked = false;

  /// Splits current text into [WordToken]s preserving their exact visual positions.
  void splitTextIntoTokens({
    required double containerWidth,
    required double containerHeight,
    FontInfo? defaultFont,
  }) {
    if (text.trim().isEmpty) return;

    wordTokens = [];
    final double baseX = textAlignment.x;
    final double baseY = textAlignment.y;

    final TextStyle style = TextStyle(
      fontSize: slideFontSize,
      fontFamily: font?.family ?? defaultFont?.family,
      fontWeight: font?.weight ?? defaultFont?.weight ?? FontWeight.bold,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: lineHeight,
    );

    // Classic mode has Padding(16) each side, so maxWidth is containerWidth - 32
    final fullPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: (containerWidth - 32).clamp(0, double.infinity));

    final double fullTextWidth = fullPainter.width;
    final double fullTextHeight = fullPainter.height;

    const double pad = 16.0;
    final double classicChildW = fullTextWidth + pad * 2;
    final double classicChildH = fullTextHeight + pad * 2;

    final double blockLeft = (containerWidth - classicChildW) * (baseX + 1) / 2;
    final double blockTop = (containerHeight - classicChildH) * (baseY + 1) / 2;

    final double textContentLeft = blockLeft + pad;
    final double textContentTop = blockTop + pad;

    final wordRegex = RegExp(r'\S+');
    final matches = wordRegex.allMatches(text);

    const double wordPadH = 6.0;
    const double wordPadV = 2.0;

    for (final match in matches) {
      final String wordStr = match.group(0)!;
      final range =
          TextSelection(baseOffset: match.start, extentOffset: match.end);
      final boxes = fullPainter.getBoxesForSelection(range);

      if (boxes.isEmpty) continue;

      final box = boxes.first;
      final double wordWidgetLeft = textContentLeft + box.left - wordPadH;
      final double wordWidgetTop = textContentTop + box.top - wordPadV;

      final double wordChildW = (box.right - box.left) + wordPadH * 2;
      final double wordChildH = (box.bottom - box.top) + wordPadV * 2;

      double alignX = 0.0;
      final double denomX = containerWidth - wordChildW;
      if (denomX.abs() > 0.1) {
        alignX = (2.0 * wordWidgetLeft / denomX) - 1.0;
      }

      double alignY = 0.0;
      final double denomY = containerHeight - wordChildH;
      if (denomY.abs() > 0.1) {
        alignY = (2.0 * wordWidgetTop / denomY) - 1.0;
      }

      final Alignment pos =
          Alignment(alignX.clamp(-1.0, 1.0), alignY.clamp(-1.0, 1.0));
      wordTokens.add(WordToken(
        text: wordStr,
        position: pos,
        originalPosition: pos,
        fontSize: slideFontSize,
        color: textColor,
        font: font,
        strokeWidth: textStrokeWidth,
        strokeColor: textStrokeColor,
        enableShadow: enableShadow,
        shadowBlur: shadowBlur,
        shadowOffset: shadowOffset,
        shadowColor: shadowColor,
        enableGlow: enableGlow,
        glowRadius: glowRadius,
        glowColor: glowColor,
        textFill: textFill,
        strokeOverForeground: strokeOverForeground,
        fgStrokeOnly: fgStrokeOnly,
      ));
    }

    useWordMode = true;
  }
}

