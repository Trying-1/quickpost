import 'package:flutter/material.dart';

/// Available Color FX presets for color inversion and black-and-white / monochrome processing.
enum ColorFxType {
  invert(
    id: 'invert',
    title: 'Color Negative',
    subtitle: 'Classic photo negative color inversion',
    category: 'Inversion',
    icon: Icons.invert_colors_rounded,
  ),
  invertMonochrome(
    id: 'invert_mono',
    title: 'Inverted B&W',
    subtitle: 'X-Ray style high-contrast inverted grayscale',
    category: 'Inversion',
    icon: Icons.filter_b_and_w_rounded,
  ),
  classicBw(
    id: 'classic_bw',
    title: 'Classic Monochrome',
    subtitle: 'Pure balanced black & white luminance',
    category: 'Monochrome',
    icon: Icons.monochrome_photos_rounded,
  ),
  noirHighContrast(
    id: 'noir',
    title: 'Noir Dramatic',
    subtitle: 'Deep crushed shadows & punchy film highlights',
    category: 'Monochrome',
    icon: Icons.contrast_rounded,
  ),
  vintageSepia(
    id: 'sepia',
    title: 'Vintage Sepia',
    subtitle: 'Warm golden-brown archival photographic print',
    category: 'Toned B&W',
    icon: Icons.camera_roll_rounded,
  ),
  cyanotype(
    id: 'cyanotype',
    title: 'Cyanotype Blue',
    subtitle: 'Historical Prussian blue monochrome print',
    category: 'Toned B&W',
    icon: Icons.wb_twilight_rounded,
  ),
  silverGelatin(
    id: 'silver',
    title: 'Silver Gelatin',
    subtitle: 'Cool platinum silver tones with soft contrast',
    category: 'Monochrome',
    icon: Icons.auto_awesome_rounded,
  ),
  warmAnalog(
    id: 'warm_analog',
    title: 'Warm Analog Film',
    subtitle: '1970s warm-toned darkroom black & white',
    category: 'Toned B&W',
    icon: Icons.light_mode_rounded,
  ),
  coolSteel(
    id: 'cool_steel',
    title: 'Cool Steel Chrome',
    subtitle: 'Industrial cold-temperature monochrome',
    category: 'Toned B&W',
    icon: Icons.ac_unit_rounded,
  );

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;

  const ColorFxType({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
  });

  /// Computes a 20-element 4x5 color transformation matrix
  /// combining the preset formula with live [brightness], [contrast], and [invertBlend].
  List<double> computeMatrix({
    double brightness = 0.0, // -1.0 to 1.0 (0.0 = neutral)
    double contrast = 0.0,   // -1.0 to 1.0 (0.0 = neutral)
    double invertBlend = 1.0,// 0.0 to 1.0
  }) {
    // 1. Contrast factor: c = 1.0 + contrast (ranges ~0.0 to 2.5)
    final double c = (contrast >= 0) ? (1.0 + contrast * 1.5) : (1.0 + contrast * 0.8).clamp(0.1, 1.0);
    final double cOffset = 128.0 * (1.0 - c);

    // 2. Brightness offset (-255 to 255)
    final double bOffset = brightness * 100.0;

    // 3. Base Preset Matrix Selection
    List<double> base;

    switch (this) {
      case ColorFxType.invert:
        // Full color negative inversion
        base = [
          -1.0,  0.0,  0.0, 0.0, 255.0,
           0.0, -1.0,  0.0, 0.0, 255.0,
           0.0,  0.0, -1.0, 0.0, 255.0,
           0.0,  0.0,  0.0, 1.0,   0.0,
        ];
        break;

      case ColorFxType.invertMonochrome:
        // Grayscale + negative inversion
        base = [
          -0.2126, -0.7152, -0.0722, 0.0, 255.0,
          -0.2126, -0.7152, -0.0722, 0.0, 255.0,
          -0.2126, -0.7152, -0.0722, 0.0, 255.0,
           0.0,     0.0,     0.0,    1.0,   0.0,
        ];
        break;

      case ColorFxType.classicBw:
        // Balanced standard luminance B&W
        base = [
          0.2126, 0.7152, 0.0722, 0.0, 0.0,
          0.2126, 0.7152, 0.0722, 0.0, 0.0,
          0.2126, 0.7152, 0.0722, 0.0, 0.0,
          0.0,    0.0,    0.0,    1.0, 0.0,
        ];
        break;

      case ColorFxType.noirHighContrast:
        // High-contrast noir B&W with crushed blacks
        base = [
          0.28, 0.78, 0.10, 0.0, -22.0,
          0.28, 0.78, 0.10, 0.0, -22.0,
          0.28, 0.78, 0.10, 0.0, -22.0,
          0.0,  0.0,  0.0,  1.0,   0.0,
        ];
        break;

      case ColorFxType.vintageSepia:
        // Warm golden-brown sepia
        base = [
          0.393, 0.769, 0.189, 0.0, 0.0,
          0.349, 0.686, 0.168, 0.0, 0.0,
          0.272, 0.534, 0.131, 0.0, 0.0,
          0.0,   0.0,   0.0,   1.0, 0.0,
        ];
        break;

      case ColorFxType.cyanotype:
        // Prussian blue blueprint monochrome
        base = [
          0.10, 0.22, 0.06, 0.0, -18.0,
          0.20, 0.45, 0.12, 0.0,   8.0,
          0.38, 0.85, 0.22, 0.0,  55.0,
          0.0,  0.0,  0.0,  1.0,   0.0,
        ];
        break;

      case ColorFxType.silverGelatin:
        // Cool platinum silver print
        base = [
          0.22, 0.68, 0.10, 0.0, 6.0,
          0.22, 0.70, 0.11, 0.0, 8.0,
          0.24, 0.74, 0.14, 0.0, 16.0,
          0.0,  0.0,  0.0,  1.0, 0.0,
        ];
        break;

      case ColorFxType.warmAnalog:
        // Warm 1970s darkroom B&W with amber highlight glow
        base = [
          0.25, 0.72, 0.08, 0.0, 16.0,
          0.23, 0.68, 0.08, 0.0,  8.0,
          0.19, 0.60, 0.06, 0.0, -6.0,
          0.0,  0.0,  0.0,  1.0,  0.0,
        ];
        break;

      case ColorFxType.coolSteel:
        // Cold blue-steel monochrome
        base = [
          0.18, 0.65, 0.12, 0.0, -8.0,
          0.20, 0.70, 0.14, 0.0,  2.0,
          0.26, 0.82, 0.18, 0.0, 24.0,
          0.0,  0.0,  0.0,  1.0,  0.0,
        ];
        break;
    }

    // 4. Apply Contrast & Brightness to the Matrix
    final List<double> result = List<double>.from(base);

    // Multiply RGB rows by contrast factor
    for (int row = 0; row < 3; row++) {
      final int rowOffset = row * 5;
      result[rowOffset + 0] *= c;
      result[rowOffset + 1] *= c;
      result[rowOffset + 2] *= c;
      result[rowOffset + 3] *= c;
      // Add contrast shift and brightness offset to column 4
      result[rowOffset + 4] = (result[rowOffset + 4] * c) + cOffset + bOffset;
    }

    return result;
  }
}

