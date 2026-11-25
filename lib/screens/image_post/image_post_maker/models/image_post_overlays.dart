import 'package:flutter/material.dart';
import '../../../../utils/font_selector.dart';

/// Converts a hex color string and opacity (`0..1`) into an `#AARRGGBB` string.
String colorWithAlphaHex(String hex, double opacity) {
  final int alpha = (opacity * 255).toInt().clamp(0, 255);
  final colorHex = hex.replaceFirst('#', '');
  final rgb =
      colorHex.length >= 6 ? colorHex.substring(colorHex.length - 6) : colorHex;
  return '#${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}$rgb';
}

/// Parses a `#RRGGBB` (or `#AARRGGBB`) hex string into a [Color], falling back to white.
Color parseImagePostColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  } catch (_) {
    return Colors.white;
  }
}

/// Parses a hex string and applies [opacity] (`0..1`).
Color parseImagePostColorWithAlpha(String hex, double opacity) {
  return parseImagePostColor(hex).withValues(alpha: opacity);
}

/// Draggable rectangular color/shape patch overlay in Image Post Maker.
class ImagePostPatch {
  double x; // Normalized
  double y; // Normalized
  double width; // Normalized
  double height; // Normalized
  String color;
  double opacity;
  double radius;
  bool isTop;

  ImagePostPatch({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color = '#000000',
    this.opacity = 1.0,
    this.radius = 0.0,
    this.isTop = true,
  });

  Map<String, dynamic> toMap(double w, double h) {
    return {
      'x': x * w,
      'y': y * h,
      'width': width * w,
      'height': height * h,
      'color': color,
      'opacity': opacity,
      'radius': radius,
      'isTop': isTop,
    };
  }
}

/// Draggable/rotatable sticker or image overlay in Image Post Maker.
class ImagePostOverlayImage {
  String path;
  double x; // Normalized
  double y; // Normalized
  double scale;
  double opacity;
  double rotation;

  ImagePostOverlayImage({
    required this.path,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.2,
    this.opacity = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toMap(double w, double h) {
    return {
      'path': path,
      'x': x * w,
      'y': y * h,
      'scale': scale,
      'opacity': opacity,
      'rotation': rotation,
    };
  }
}

/// Per-word styled segment used when merging split words back into a single text overlay.
class TextSegment {
  String text;
  String color;
  FontInfo? font;

  TextSegment({
    required this.text,
    required this.color,
    this.font,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'color': color,
      'font': font?.toMap(),
    };
  }

  factory TextSegment.fromMap(Map<String, dynamic> map) {
    return TextSegment(
      text: map['text'] ?? '',
      color: map['color'] ?? '#000000',
      font: map['font'] != null
          ? FontInfo.fromMap(Map<String, dynamic>.from(map['font'] as Map))
          : null,
    );
  }
}

/// Draggable text layer (or split word token) in Image Post Maker.
class ImagePostTextOverlay {
  String text;
  double x;
  double y;
  double fontSize;
  String color;
  FontInfo? font;
  bool showShadow;
  String shadowColor;
  double shadowBlur;
  double shadowOffsetX;
  double shadowOffsetY;
  TextAlign textAlign;
  String anchor;
  double scale;
  double lineHeight;
  double letterSpacing;
  double wordSpacing;
  double opacity;
  bool isSplitWord;
  String? groupId;
  String? originalFullText;
  bool isLocked;
  List<TextSegment>? styleSegments;

  ImagePostTextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.25,
    this.fontSize = 30.0,
    this.color = '#000000',
    this.font,
    this.showShadow = false,
    this.shadowColor = '#000000',
    this.shadowBlur = 8.0,
    this.shadowOffsetX = 2.0,
    this.shadowOffsetY = 2.0,
    this.textAlign = TextAlign.center,
    this.anchor = 'center',
    this.scale = 1.0,
    this.lineHeight = 1.2,
    this.letterSpacing = 0.0,
    this.wordSpacing = 0.0,
    this.opacity = 1.0,
    this.isSplitWord = false,
    this.groupId,
    this.originalFullText,
    this.isLocked = false,
    this.styleSegments,
  });

  Map<String, dynamic> toMap(
    double width,
    double height,
    String resolvedFontPath,
  ) {
    return {
      'text': text,
      'x': x * width,
      'y': y * height,
      'fontSize': fontSize * scale,
      'color': colorWithAlphaHex(color, opacity),
      'fontPath': resolvedFontPath,
      'showShadow': showShadow,
      'shadowColor': shadowColor,
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'textAlign': textAlign.name,
      'maxWidth': width * 0.8 * scale,
      'anchor': anchor,
      'scale': scale,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'wordSpacing': wordSpacing,
    };
  }
}

