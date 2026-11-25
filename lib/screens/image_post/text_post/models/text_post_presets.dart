import 'package:flutter/material.dart';

/// Curated 2-color background gradient preset for Simple Text Post.
class TextPostGradientPreset {
  final String name;
  final Color color1;
  final Color color2;
  final double angle;

  const TextPostGradientPreset({
    required this.name,
    required this.color1,
    required this.color2,
    this.angle = 135.0,
  });
}

/// Curated 1-tap aesthetic style preset for Simple Text Post.
class TextPostStylePreset {
  final String name;
  final Color textColor;
  final Color bgColor1;
  final Color bgColor2;
  final bool useGradient;
  final double gradientAngle;
  final bool showBox;
  final Color boxColor;
  final double boxOpacity;
  final double boxRadius;
  final bool showShadow;
  final Color shadowColor;
  final double shadowBlur;
  final bool showGlow;
  final Color glowColor;
  final double glowRadius;
  final bool showStroke;
  final Color strokeColor;
  final double strokeWidth;

  const TextPostStylePreset({
    required this.name,
    required this.textColor,
    required this.bgColor1,
    required this.bgColor2,
    this.useGradient = true,
    this.gradientAngle = 135.0,
    this.showBox = false,
    this.boxColor = Colors.white,
    this.boxOpacity = 0.85,
    this.boxRadius = 10.0,
    this.showShadow = true,
    this.shadowColor = Colors.black,
    this.shadowBlur = 4.0,
    this.showGlow = false,
    this.glowColor = Colors.white,
    this.glowRadius = 12.0,
    this.showStroke = false,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
  });
}

enum TextPostTextCase { upper, lower, title, sentence }

/// Transforms text casing without changing anything else.
String applyTextPostCase(String input, TextPostTextCase targetCase) {
  switch (targetCase) {
    case TextPostTextCase.upper:
      return input.toUpperCase();
    case TextPostTextCase.lower:
      return input.toLowerCase();
    case TextPostTextCase.title:
      return input.replaceAllMapped(
        RegExp(r'(\S+)'),
        (m) {
          final w = m.group(0)!;
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        },
      );
    case TextPostTextCase.sentence:
      final trimmed = input.toLowerCase();
      if (trimmed.isEmpty) return trimmed;
      return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}

class TextPostPresets {
  TextPostPresets._();

  static const List<TextPostGradientPreset> gradients = [
    TextPostGradientPreset(
      name: 'Midnight',
      color1: Color(0xFF0F2027),
      color2: Color(0xFF2C5364),
      angle: 135,
    ),
    TextPostGradientPreset(
      name: 'Sunset',
      color1: Color(0xFFFF512F),
      color2: Color(0xFFDD2476),
      angle: 135,
    ),
    TextPostGradientPreset(
      name: 'Violet',
      color1: Color(0xFF4776E6),
      color2: Color(0xFF8E54E9),
      angle: 135,
    ),
    TextPostGradientPreset(
      name: 'Emerald',
      color1: Color(0xFF134E5E),
      color2: Color(0xFF71B280),
      angle: 135,
    ),
    TextPostGradientPreset(
      name: 'Peach',
      color1: Color(0xFFFFECD2),
      color2: Color(0xFFFCB69F),
      angle: 135,
    ),
    TextPostGradientPreset(
      name: 'Noir Gold',
      color1: Color(0xFF1A1A1D),
      color2: Color(0xFF4E4E50),
      angle: 160,
    ),
    TextPostGradientPreset(
      name: 'Ocean',
      color1: Color(0xFF2193B0),
      color2: Color(0xFF6DD5ED),
      angle: 135,
    ),
    TextPostGradientPreset(
      name: 'Berry',
      color1: Color(0xFF833AB4),
      color2: Color(0xFFFD1D1D),
      angle: 120,
    ),
  ];

  static const List<TextPostStylePreset> styles = [
    TextPostStylePreset(
      name: 'Noir Clean',
      textColor: Colors.white,
      bgColor1: Color(0xFF111114),
      bgColor2: Color(0xFF25252B),
      useGradient: true,
      gradientAngle: 145,
      showShadow: true,
      shadowBlur: 6.0,
    ),
    TextPostStylePreset(
      name: 'Warm Paper',
      textColor: Color(0xFF1F1D1A),
      bgColor1: Color(0xFFF6F1E7),
      bgColor2: Color(0xFFEDE2CE),
      useGradient: true,
      gradientAngle: 135,
      showShadow: false,
    ),
    TextPostStylePreset(
      name: 'Neon Cyber',
      textColor: Color(0xFF7DF9FF),
      bgColor1: Color(0xFF0B0C1E),
      bgColor2: Color(0xFF1E1348),
      useGradient: true,
      gradientAngle: 135,
      showShadow: false,
      showGlow: true,
      glowColor: Color(0xFF00E5FF),
      glowRadius: 14.0,
    ),
    TextPostStylePreset(
      name: 'Boxed Quote',
      textColor: Color(0xFF18181B),
      bgColor1: Color(0xFFFF512F),
      bgColor2: Color(0xFFDD2476),
      useGradient: true,
      gradientAngle: 135,
      showBox: true,
      boxColor: Colors.white,
      boxOpacity: 0.92,
      boxRadius: 14.0,
      showShadow: false,
    ),
    TextPostStylePreset(
      name: 'Bold Stroke',
      textColor: Color(0xFFFFEB3B),
      bgColor1: Color(0xFF1B1F3B),
      bgColor2: Color(0xFF1B1F3B),
      useGradient: false,
      showShadow: true,
      shadowBlur: 0.0,
      showStroke: true,
      strokeColor: Colors.black,
      strokeWidth: 3.5,
    ),
    TextPostStylePreset(
      name: 'Sage Editorial',
      textColor: Color(0xFFF4F7F5),
      bgColor1: Color(0xFF283D3B),
      bgColor2: Color(0xFF197278),
      useGradient: true,
      gradientAngle: 150,
      showShadow: true,
      shadowBlur: 4.0,
    ),
  ];
}

