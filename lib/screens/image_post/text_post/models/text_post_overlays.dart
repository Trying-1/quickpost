import 'package:flutter/material.dart';
import '../../../../utils/font_selector.dart';

/// Draggable rectangular color/shape overlay patch on the Text Post canvas.
class TextPostOverlayPatch {
  double x; // Normalized 0..1
  double y; // Normalized 0..1
  double width; // Normalized 0..1
  double height; // Normalized 0..1
  Color color;
  double opacity;
  double radius;
  bool isTop;

  TextPostOverlayPatch({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color = Colors.black,
    this.opacity = 0.5,
    this.radius = 8.0,
    this.isTop = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color.toARGB32(),
      'opacity': opacity,
      'radius': radius,
      'isTop': isTop,
    };
  }

  factory TextPostOverlayPatch.fromMap(Map<String, dynamic> map) {
    return TextPostOverlayPatch(
      x: map['x']?.toDouble() ?? 0.5,
      y: map['y']?.toDouble() ?? 0.5,
      width: map['width']?.toDouble() ?? 0.2,
      height: map['height']?.toDouble() ?? 0.2,
      color: Color(map['color'] ?? Colors.black.toARGB32()),
      opacity: map['opacity']?.toDouble() ?? 0.5,
      radius: map['radius']?.toDouble() ?? 8.0,
      isTop: map['isTop'] ?? false,
    );
  }

  TextPostOverlayPatch copy() =>
      TextPostOverlayPatch.fromMap(Map<String, dynamic>.from(toMap()));
}

/// Draggable/rotatable sticker or image overlay on the Text Post canvas.
class TextPostOverlayImage {
  String path;
  double x; // Normalized 0..1
  double y; // Normalized 0..1
  double scale;
  double opacity;
  double rotation;

  TextPostOverlayImage({
    required this.path,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.2,
    this.opacity = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'x': x,
      'y': y,
      'scale': scale,
      'opacity': opacity,
      'rotation': rotation,
    };
  }

  factory TextPostOverlayImage.fromMap(Map<String, dynamic> map) {
    return TextPostOverlayImage(
      path: map['path'] ?? '',
      x: map['x']?.toDouble() ?? 0.5,
      y: map['y']?.toDouble() ?? 0.5,
      scale: map['scale']?.toDouble() ?? 0.2,
      opacity: map['opacity']?.toDouble() ?? 1.0,
      rotation: map['rotation']?.toDouble() ?? 0.0,
    );
  }

  TextPostOverlayImage copy() =>
      TextPostOverlayImage.fromMap(Map<String, dynamic>.from(toMap()));
}

/// Independent draggable text layer on the Text Post canvas.
class TextPostTextOverlay {
  String text;
  double x;
  double y;
  double fontSize;
  Color color;
  FontInfo? font;
  bool showShadow;
  Color shadowColor;
  double shadowBlur;
  double shadowOffsetX;
  double shadowOffsetY;
  TextAlign textAlign;
  double scale;

  double letterSpacing;
  double lineHeight;
  bool showGlow;
  Color glowColor;
  double glowRadius;

  // Box properties
  bool showBox;
  Color boxColor;
  double boxOpacity;
  double boxRadius;

  // Warp properties ('none', 'arc', 'cylinder', 'bulge')
  String warpType;
  double warpIntensity;

  // Opacity, rotation, and stroke properties
  double opacity;
  double rotation;
  bool textFill;
  bool showStroke;
  Color strokeColor;
  double strokeWidth;

  TextPostTextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSize = 24.0,
    this.color = Colors.white,
    this.font,
    this.showShadow = true,
    this.shadowColor = Colors.black,
    this.shadowBlur = 0.0,
    this.shadowOffsetX = 1.0,
    this.shadowOffsetY = 1.0,
    this.textAlign = TextAlign.center,
    this.scale = 1.0,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.0,
    this.showGlow = true,
    this.glowColor = Colors.white,
    this.glowRadius = 10.0,
    this.showBox = false,
    this.boxColor = Colors.white,
    this.boxOpacity = 0.8,
    this.boxRadius = 8.0,
    this.warpType = 'none',
    this.warpIntensity = 0.0,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.textFill = true,
    this.showStroke = false,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color.toARGB32(),
      'font': font?.toMap(),
      'showShadow': showShadow,
      'shadowColor': shadowColor.toARGB32(),
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'textAlign': textAlign.index,
      'scale': scale,
      'letterSpacing': letterSpacing,
      'lineHeight': lineHeight,
      'showGlow': showGlow,
      'glowColor': glowColor.toARGB32(),
      'glowRadius': glowRadius,
      'showBox': showBox,
      'boxColor': boxColor.toARGB32(),
      'boxOpacity': boxOpacity,
      'boxRadius': boxRadius,
      'warpType': warpType,
      'warpIntensity': warpIntensity,
      'opacity': opacity,
      'rotation': rotation,
      'textFill': textFill,
      'showStroke': showStroke,
      'strokeColor': strokeColor.toARGB32(),
      'strokeWidth': strokeWidth,
    };
  }

  factory TextPostTextOverlay.fromMap(Map<String, dynamic> map) {
    return TextPostTextOverlay(
      text: map['text'] ?? '',
      x: map['x']?.toDouble() ?? 0.5,
      y: map['y']?.toDouble() ?? 0.5,
      fontSize: map['fontSize']?.toDouble() ?? 24.0,
      color: Color(map['color'] ?? Colors.white.toARGB32()),
      font: map['font'] != null
          ? FontInfo.fromMap(Map<String, dynamic>.from(map['font']))
          : null,
      showShadow: map['showShadow'] ?? true,
      shadowColor: Color(map['shadowColor'] ?? Colors.black.toARGB32()),
      shadowBlur: map['shadowBlur']?.toDouble() ?? 0.0,
      shadowOffsetX: map['shadowOffsetX']?.toDouble() ?? 1.0,
      shadowOffsetY: map['shadowOffsetY']?.toDouble() ?? 1.0,
      textAlign: map['textAlign'] != null
          ? TextAlign.values[map['textAlign']]
          : TextAlign.center,
      scale: map['scale']?.toDouble() ?? 1.0,
      letterSpacing: map['letterSpacing']?.toDouble() ?? 0.0,
      lineHeight: map['lineHeight']?.toDouble() ?? 1.0,
      showGlow: map['showGlow'] ?? true,
      glowColor: Color(map['glowColor'] ?? Colors.white.toARGB32()),
      glowRadius: map['glowRadius']?.toDouble() ?? 10.0,
      showBox: map['showBox'] ?? false,
      boxColor: Color(map['boxColor'] ?? Colors.white.toARGB32()),
      boxOpacity: map['boxOpacity']?.toDouble() ?? 0.8,
      boxRadius: map['boxRadius']?.toDouble() ?? 8.0,
      warpType: map['warpType'] ?? 'none',
      warpIntensity: map['warpIntensity']?.toDouble() ?? 0.0,
      opacity: map['opacity']?.toDouble() ?? 1.0,
      rotation: map['rotation']?.toDouble() ?? 0.0,
      textFill: map['textFill'] ?? true,
      showStroke: map['showStroke'] ?? false,
      strokeColor: Color(map['strokeColor'] ?? Colors.black.toARGB32()),
      strokeWidth: map['strokeWidth']?.toDouble() ?? 2.0,
    );
  }

  TextPostTextOverlay copy() =>
      TextPostTextOverlay.fromMap(Map<String, dynamic>.from(toMap()));
}

