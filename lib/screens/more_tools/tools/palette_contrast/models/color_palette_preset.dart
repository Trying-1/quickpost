import 'package:flutter/material.dart';

/// Domain model for tested high-contrast color palettes.
class ColorPalettePreset {
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final String complianceRating;

  const ColorPalettePreset({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    required this.complianceRating,
  });

  static const List<ColorPalettePreset> defaultPalettes = [
    ColorPalettePreset(
      name: 'Obsidian Minimal',
      backgroundColor: Color(0xFF0A0A0C),
      textColor: Colors.white,
      accentColor: Color(0xFF00E5FF),
      complianceRating: 'AAA High Contrast',
    ),
    ColorPalettePreset(
      name: 'Porcelain Clean',
      backgroundColor: Color(0xFFF8FAFC),
      textColor: Color(0xFF0F172A),
      accentColor: Color(0xFF2563EB),
      complianceRating: 'AAA High Contrast',
    ),
    ColorPalettePreset(
      name: 'Nordic Slate',
      backgroundColor: Color(0xFF1E293B),
      textColor: Colors.white,
      accentColor: Color(0xFF38BDF8),
      complianceRating: 'AAA High Contrast',
    ),
    ColorPalettePreset(
      name: 'Warm Sand',
      backgroundColor: Color(0xFFF5EBE0),
      textColor: Color(0xFF3E2723),
      accentColor: Color(0xFFD97706),
      complianceRating: 'AAA Verified',
    ),
    ColorPalettePreset(
      name: 'Botanical Forest',
      backgroundColor: Color(0xFF064E3B),
      textColor: Colors.white,
      accentColor: Color(0xFF34D399),
      complianceRating: 'AAA Verified',
    ),
  ];
}

