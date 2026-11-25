import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a single color within a palette with rich color-theory metadata.
class PaletteColor {
  final Color color;
  final String name;
  final String role;
  final bool isLocked;

  const PaletteColor({
    required this.color,
    this.name = '',
    this.role = 'Custom',
    this.isLocked = false,
  });

  /// 6-character hex string uppercase, prefixed with # (e.g. #FF6D00)
  String get hexCode {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}';
  }

  int get red => color.red;
  int get green => color.green;
  int get blue => color.blue;

  String get rgbString => 'RGB($red, $green, $blue)';

  /// Relative luminance according to WCAG 2.1 specs
  double get relativeLuminance {
    double transform(int channel) {
      final v = channel / 255.0;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = transform(red);
    final g = transform(green);
    final b = transform(blue);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  bool get isDark => relativeLuminance < 0.45;

  Color get onColor => isDark ? Colors.white : const Color(0xFF0F172A);

  /// Calculate WCAG contrast ratio against another color (ranges from 1.0 to 21.0)
  double contrastRatioWith(Color other) {
    double l1 = relativeLuminance;
    double l2 = _relativeLuminanceOf(other);
    if (l1 < l2) {
      final tmp = l1;
      l1 = l2;
      l2 = tmp;
    }
    return (l1 + 0.05) / (l2 + 0.05);
  }

  static double _relativeLuminanceOf(Color c) {
    double transform(int channel) {
      final v = channel / 255.0;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * transform(c.red) +
        0.7152 * transform(c.green) +
        0.0722 * transform(c.blue);
  }

  /// Human-readable WCAG compliance label against another color
  String getWcagRating(Color background) {
    final ratio = contrastRatioWith(background);
    if (ratio >= 7.0) return 'AAA';
    if (ratio >= 4.5) return 'AA';
    if (ratio >= 3.0) return 'AA Large';
    return 'Fail';
  }

  PaletteColor copyWith({
    Color? color,
    String? name,
    String? role,
    bool? isLocked,
  }) {
    return PaletteColor(
      color: color ?? this.color,
      name: name ?? this.name,
      role: role ?? this.role,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  /// Looks up closest human-friendly color name
  static String findNearestName(Color c) {
    double minDistance = double.infinity;
    String closestName = 'Custom';

    for (final entry in _namedHues.entries) {
      final target = entry.value;
      final dr = (c.red - target.red).toDouble();
      final dg = (c.green - target.green).toDouble();
      final db = (c.blue - target.blue).toDouble();
      // Weighted Euclidean distance for human perception
      final dist = (2 * dr * dr) + (4 * dg * dg) + (3 * db * db);
      if (dist < minDistance) {
        minDistance = dist;
        closestName = entry.key;
      }
    }
    return closestName;
  }

  static const Map<String, Color> _namedHues = {
    'Obsidian Dark': Color(0xFF0F172A),
    'Slate Shadow': Color(0xFF1E293B),
    'Charcoal Mist': Color(0xFF334155),
    'Graphite Gray': Color(0xFF64748B),
    'Silver Frost': Color(0xFF94A3B8),
    'Platinum Cloud': Color(0xFFCBD5E1),
    'Pure White': Color(0xFFFFFFFF),
    'Crimson Flame': Color(0xFFDC2626),
    'Ruby Red': Color(0xFFE11D48),
    'Rose Bloom': Color(0xFFF43F5E),
    'Sunset Orange': Color(0xFFEA580C),
    'Amber Glow': Color(0xFFD97706),
    'Honey Tangerine': Color(0xFFFF9800),
    'Golden Sun': Color(0xFFFACC15),
    'Lemon Lime': Color(0xFF84CC16),
    'Emerald Jade': Color(0xFF10B981),
    'Forest Pine': Color(0xFF065F46),
    'Mint Breeze': Color(0xFF34D399),
    'Teal Lagoon': Color(0xFF0D9488),
    'Cyber Cyan': Color(0xFF06B6D4),
    'Sky Blue': Color(0xFF0284C7),
    'Cobalt Azure': Color(0xFF2563EB),
    'Royal Indigo': Color(0xFF4F46E5),
    'Deep Violet': Color(0xFF7C3AED),
    'Purple Neon': Color(0xFF9333EA),
    'Orchid Mauve': Color(0xFFC026D3),
    'Electric Fuchsia': Color(0xFFDB2777),
    'Mocha Espresso': Color(0xFF3E2723),
    'Terracotta Clay': Color(0xFF8D6E63),
    'Sand Dune': Color(0xFFD7CCC8),
    'Warm Ivory': Color(0xFFFDFBF7),
  };
}

