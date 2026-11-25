import 'package:flutter/material.dart';

/// Renders text with optional outline/stroke styling, supporting:
/// 1. Outline Only (No fill / hollow text - transparent center with stroke)
/// 2. Solid Fill with Outline (Stroke rendered around/behind the fill)
/// 3. Standard Solid Fill (normal text)
class OutlinedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color? fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool strokeOnly;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final List<Shadow>? shadows;

  const OutlinedText({
    super.key,
    required this.text,
    required this.style,
    this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 0.0,
    this.strokeOnly = false,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final effectiveFillColor = fillColor ?? style.color ?? Colors.white;
    final effectiveStrokeWidth = strokeWidth > 0 ? strokeWidth : (strokeOnly ? 1.5 : 0.0);

    // Case 1: Outline Only (No fill / Hollow text)
    if (strokeOnly) {
      return Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: style.copyWith(
          color: null,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = effectiveStrokeWidth
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = strokeColor,
          shadows: shadows,
        ),
      );
    }

    // Case 2: Solid Fill WITH Outline Stroke behind it
    if (effectiveStrokeWidth > 0) {
      Alignment alignment = Alignment.centerLeft;
      if (textAlign == TextAlign.center) {
        alignment = Alignment.center;
      } else if (textAlign == TextAlign.right || textAlign == TextAlign.end) {
        alignment = Alignment.centerRight;
      }

      return Stack(
        alignment: alignment,
        children: [
          // Background Stroke (rendered at double width so stroke expands outward)
          Text(
            text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            style: style.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = effectiveStrokeWidth * 2
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..color = strokeColor,
              shadows: shadows,
            ),
          ),
          // Foreground Solid Fill
          Text(
            text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            style: style.copyWith(
              color: effectiveFillColor,
              foreground: null,
            ),
          ),
        ],
      );
    }

    // Case 3: Standard Solid Fill (no outline)
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style.copyWith(
        color: effectiveFillColor,
        shadows: shadows,
      ),
    );
  }
}

