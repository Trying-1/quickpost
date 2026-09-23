import 'package:flutter/material.dart';
import '../utils/custom_font_manager.dart';
import '../utils/font_selector.dart';

class WordToken {
  String text;
  Alignment position;
  Alignment? originalPosition; // Stores the position right after splitting
  double fontSize;
  Color color;
  FontInfo? font;
  double rotation; // degrees
  
  double strokeWidth;
  Color strokeColor;
  bool textFill;
  bool strokeOverForeground;
  bool fgStrokeOnly;

  // Text effects (inherited from slide defaults)
  bool enableShadow;
  double shadowBlur;
  Offset shadowOffset;
  Color shadowColor;
  bool enableGlow;
  double glowRadius;
  Color glowColor;

  WordToken({
    required this.text,
    this.position = Alignment.center,
    this.originalPosition,
    this.fontSize = 28.0,
    this.color = Colors.white,
    this.font,
    this.rotation = 0.0,
    this.strokeWidth = 0.0,
    this.strokeColor = Colors.black,
    this.textFill = true,
    this.strokeOverForeground = false,
    this.fgStrokeOnly = false,
    this.enableShadow = true,
    this.shadowBlur = 4.0,
    this.shadowOffset = const Offset(2, 2),
    this.shadowColor = Colors.black54,
    this.enableGlow = false,
    this.glowRadius = 10.0,
    this.glowColor = Colors.white70,
  });
}
