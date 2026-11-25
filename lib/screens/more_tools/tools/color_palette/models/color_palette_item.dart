import 'dart:convert';
import 'package:flutter/material.dart';
import 'palette_color.dart';

/// Domain model representing a complete color palette.
class ColorPaletteItem {
  final String id;
  final String title;
  final List<PaletteColor> colors;
  final String? sourceImagePath;
  final String category;
  final DateTime createdAt;

  ColorPaletteItem({
    required this.id,
    required this.title,
    required this.colors,
    this.sourceImagePath,
    this.category = 'Custom',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ColorPaletteItem copyWith({
    String? id,
    String? title,
    List<PaletteColor>? colors,
    String? sourceImagePath,
    String? category,
    DateTime? createdAt,
  }) {
    return ColorPaletteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      colors: colors ?? List.from(this.colors),
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Comma-separated list of HEX strings
  String toHexListString() {
    return colors.map((c) => c.hexCode).join(', ');
  }

  /// CSS root variables format
  String toCssVariables() {
    final buffer = StringBuffer(':root {\n');
    for (int i = 0; i < colors.length; i++) {
      final nameSlug = colors[i].name.toLowerCase().replaceAll(' ', '-');
      buffer.writeln('  --color-${i + 1}-$nameSlug: ${colors[i].hexCode};');
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Flutter Color code snippet
  String toFlutterCode() {
    final buffer = StringBuffer('// Quick Post Palette: $title\nconst palette = [\n');
    for (final c in colors) {
      final hex = c.color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
      buffer.writeln('  Color(0x$hex), // ${c.name} (${c.role})');
    }
    buffer.write('];');
    return buffer.toString();
  }

  /// JSON export format
  String toJsonExport() {
    final list = colors.map((c) => {
      'name': c.name,
      'hex': c.hexCode,
      'rgb': {
        'r': c.red,
        'g': c.green,
        'b': c.blue,
      },
      'role': c.role,
      'luminance': double.parse(c.relativeLuminance.toStringAsFixed(3)),
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'title': title,
      'category': category,
      'created': createdAt.toIso8601String(),
      'colors': list,
    });
  }
}

