import 'package:flutter/material.dart';

/// Supported export aspect ratios: Strictly 1:1 (Square) or 3:4 (Portrait).
enum PaletteExportAspectRatio {
  portrait3x4(
    id: '3_4',
    label: '3:4 Portrait',
    width: 1080,
    height: 1440,
    ratio: 3 / 4,
    icon: Icons.portrait_rounded,
  ),
  square1x1(
    id: '1_1',
    label: '1:1 Square',
    width: 1080,
    height: 1080,
    ratio: 1 / 1,
    icon: Icons.crop_square_rounded,
  );

  final String id;
  final String label;
  final int width;
  final int height;
  final double ratio;
  final IconData icon;

  const PaletteExportAspectRatio({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.ratio,
    required this.icon,
  });
}

/// Visual layout styles for exporting color palettes as high-resolution images.
enum PaletteExportCardStyle {
  circularSwatches(
    id: 'circular_swatches',
    label: 'Circular Swatches',
    description: 'Aesthetic round color bubbles with soft glow rings & hex tags',
    icon: Icons.circle_outlined,
  ),
  squareSwatches(
    id: 'square_swatches',
    label: 'Pantone Squares',
    description: 'Iconic designer cards with solid color tops & white label footers',
    icon: Icons.grid_view_rounded,
  ),
  verticalColumns(
    id: 'vertical_columns',
    label: 'Rectangular Columns',
    description: 'Side-by-side vertical rectangular columns with stacked labels',
    icon: Icons.view_column_rounded,
  ),
  horizontalRows(
    id: 'horizontal_rows',
    label: 'Horizontal Rows',
    description: 'Stacked full-width rounded rows with prominent hex & RGB tags',
    icon: Icons.table_rows_rounded,
  ),
  photoCompanion(
    id: 'photo_companion',
    label: 'Photo Companion',
    description: 'Original source photo paired with extracted color swatches',
    icon: Icons.image_rounded,
  ),
  stackedPills(
    id: 'stacked_pills',
    label: 'Cascading Deck',
    description: 'Overlapping 3D pill stack with ambient backlight glow & hex tags',
    icon: Icons.layers_rounded,
  );

  final String id;
  final String label;
  final String description;
  final IconData icon;

  const PaletteExportCardStyle({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}

/// Canvas background theme options for export rendering.
enum PaletteBackgroundTheme {
  obsidian('Obsidian Dark', Color(0xFF0F172A), Colors.white, Color(0xFF94A3B8)),
  pureWhite('Pure White', Color(0xFFFFFFFF), Color(0xFF0F172A), Color(0xFF64748B)),
  slate('Midnight Slate', Color(0xFF1E293B), Colors.white, Color(0xFF94A3B8)),
  warmSand('Warm Sand', Color(0xFFF7F4EE), Color(0xFF292524), Color(0xFF78716C));

  final String label;
  final Color backgroundColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const PaletteBackgroundTheme(
    this.label,
    this.backgroundColor,
    this.primaryTextColor,
    this.secondaryTextColor,
  );
}
