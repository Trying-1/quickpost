import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/color_palette_item.dart';
import '../models/palette_color.dart';
import '../models/palette_export_card_style.dart';

enum HarmonyType {
  complementary('Complementary', 'Opposites on the color wheel for maximum contrast'),
  analogous('Analogous', 'Adjacent colors on the wheel for cohesive, serene vibes'),
  triadic('Triadic', 'Three equidistant colors for vibrant yet balanced energy'),
  splitComplementary('Split-Comp', 'Base color paired with two adjacent to its opposite'),
  monochromatic('Monochromatic', 'Rich tints, shades, and tones of the same hue'),
  tetradic('Tetradic', 'Double complementary rectangle for rich multi-color schemes');

  final String label;
  final String description;
  const HarmonyType(this.label, this.description);
}

/// Service that extracts vibrant palettes from images, generates color harmonies,
/// and renders high-resolution aesthetic swatch cards for gallery export.
class ColorExtractorService {
  static final ColorExtractorService _instance = ColorExtractorService._internal();
  factory ColorExtractorService() => _instance;
  ColorExtractorService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the user's gallery using the standard picker.
  Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Decodes and downsamples [imageFile] to extract a rich, non-redundant palette.
  Future<ColorPaletteItem?> extractPaletteFromImage(File imageFile, {int maxColors = 6}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fullImage = img.decodeImage(bytes);
      if (fullImage == null) return null;

      // 1. Blazing fast downsample (max 120x120 = ~14k pixels) for instant extraction
      final downsampled = img.copyResize(
        fullImage,
        width: 120,
        height: 120,
        interpolation: img.Interpolation.linear,
      );

      // 2. 5-bit RGB Color Quantization bucket map
      final Map<int, int> bucketCounts = {};
      final Map<int, List<int>> bucketRgbSums = {};

      for (int y = 0; y < downsampled.height; y++) {
        for (int x = 0; x < downsampled.width; x++) {
          final pixel = downsampled.getPixel(x, y);
          final a = pixel.a.toInt();
          if (a < 128) continue; // Skip semi-transparent pixels

          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // 5-bit bucket key: (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)
          final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
          bucketCounts[key] = (bucketCounts[key] ?? 0) + 1;

          final sums = bucketRgbSums.putIfAbsent(key, () => [0, 0, 0]);
          sums[0] += r;
          sums[1] += g;
          sums[2] += b;
        }
      }

      // 3. Sort buckets by popularity
      final sortedBuckets = bucketCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 4. Cluster filtering with perceptual distance threshold (delta > 38)
      final List<Color> candidates = [];
      for (final entry in sortedBuckets) {
        final sums = bucketRgbSums[entry.key]!;
        final count = entry.value;
        final c = Color.fromARGB(
          255,
          (sums[0] / count).round(),
          (sums[1] / count).round(),
          (sums[2] / count).round(),
        );

        bool isDistinct = true;
        for (final existing in candidates) {
          final dr = (c.red - existing.red).toDouble();
          final dg = (c.green - existing.green).toDouble();
          final db = (c.blue - existing.blue).toDouble();
          final dist = math.sqrt(dr * dr + dg * dg + db * db);
          if (dist < 38.0) {
            isDistinct = false;
            break;
          }
        }

        if (isDistinct) {
          candidates.add(c);
          if (candidates.length >= 12) break;
        }
      }

      if (candidates.isEmpty) return null;

      // 5. Intelligent Role Assignment (Dominant, Vibrant, Dark, Light, Muted, Secondary)
      final List<PaletteColor> paletteColors = [];

      // Dominant: most popular color
      final dominant = candidates.first;
      paletteColors.add(PaletteColor(
        color: dominant,
        name: PaletteColor.findNearestName(dominant),
        role: 'Dominant',
      ));

      // Vibrant: highest saturation with decent value
      Color? vibrant;
      double maxSat = -1.0;
      for (final c in candidates) {
        final hsv = HSVColor.fromColor(c);
        if (hsv.saturation > maxSat && hsv.value > 0.35 && c != dominant) {
          maxSat = hsv.saturation;
          vibrant = c;
        }
      }
      if (vibrant != null) {
        paletteColors.add(PaletteColor(
          color: vibrant,
          name: PaletteColor.findNearestName(vibrant),
          role: 'Vibrant Accent',
        ));
      }

      // Dark Shade: lowest value/luminance
      Color? darkShade;
      double minVal = 999.0;
      for (final c in candidates) {
        final hsv = HSVColor.fromColor(c);
        if (hsv.value < minVal && !paletteColors.any((p) => p.color == c)) {
          minVal = hsv.value;
          darkShade = c;
        }
      }
      if (darkShade != null) {
        paletteColors.add(PaletteColor(
          color: darkShade,
          name: PaletteColor.findNearestName(darkShade),
          role: 'Dark Shade',
        ));
      }

      // Light Highlight: highest value and lower saturation
      Color? lightShade;
      double maxVal = -1.0;
      for (final c in candidates) {
        final hsv = HSVColor.fromColor(c);
        if (hsv.value > maxVal && !paletteColors.any((p) => p.color == c)) {
          maxVal = hsv.value;
          lightShade = c;
        }
      }
      if (lightShade != null) {
        paletteColors.add(PaletteColor(
          color: lightShade,
          name: PaletteColor.findNearestName(lightShade),
          role: 'Light Highlight',
        ));
      }

      // Fill remaining slots up to maxColors
      for (final c in candidates) {
        if (paletteColors.length >= maxColors) break;
        if (!paletteColors.any((p) => p.color == c)) {
          paletteColors.add(PaletteColor(
            color: c,
            name: PaletteColor.findNearestName(c),
            role: paletteColors.length == 4 ? 'Muted Neutral' : 'Accent',
          ));
        }
      }

      final fileName = imageFile.path.split('/').last;
      final titleBase = fileName.contains('.') ? fileName.split('.').first : fileName;

      return ColorPaletteItem(
        id: 'img_${DateTime.now().millisecondsSinceEpoch}',
        title: '${titleBase.replaceAll(RegExp(r'[_-]'), ' ')} Palette',
        category: 'Image Extracted',
        sourceImagePath: imageFile.path,
        colors: paletteColors,
      );
    } catch (e) {
      debugPrint('extractPaletteFromImage error: $e');
      return null;
    }
  }

  /// Samples exact pixel color from normalized coordinates (0.0 to 1.0) on decoded image
  Color sampleNormalizedPixel(img.Image image, double nx, double ny) {
    final x = (nx * (image.width - 1)).clamp(0, image.width - 1).round();
    final y = (ny * (image.height - 1)).clamp(0, image.height - 1).round();
    final p = image.getPixel(x, y);
    return Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
  }

  /// Generates 5 harmonious palette colors from a base color using color theory
  List<PaletteColor> generateHarmonies(Color baseColor, HarmonyType type) {
    final hsv = HSVColor.fromColor(baseColor);
    final double h = hsv.hue;
    final double s = hsv.saturation;
    final double v = hsv.value;

    List<Color> rawColors = [];

    switch (type) {
      case HarmonyType.complementary:
        rawColors = [
          baseColor,
          HSVColor.fromAHSV(1.0, (h + 180) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 180) % 360, (s * 0.5).clamp(0.1, 1.0), (v * 1.15).clamp(0.0, 1.0)).toColor(),
          HSVColor.fromAHSV(1.0, h, (s * 0.4).clamp(0.1, 1.0), (v * 0.4).clamp(0.1, 1.0)).toColor(),
          HSVColor.fromAHSV(1.0, (h + 180) % 360, 0.15, 0.95).toColor(),
        ];
        break;

      case HarmonyType.analogous:
        rawColors = [
          HSVColor.fromAHSV(1.0, (h - 40 + 360) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h - 20 + 360) % 360, s, v).toColor(),
          baseColor,
          HSVColor.fromAHSV(1.0, (h + 20) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 40) % 360, s, v).toColor(),
        ];
        break;

      case HarmonyType.triadic:
        rawColors = [
          baseColor,
          HSVColor.fromAHSV(1.0, (h + 120) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 240) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 120) % 360, (s * 0.6).clamp(0.1, 1.0), (v * 0.5).clamp(0.1, 1.0)).toColor(),
          HSVColor.fromAHSV(1.0, (h + 240) % 360, 0.15, 0.96).toColor(),
        ];
        break;

      case HarmonyType.splitComplementary:
        rawColors = [
          baseColor,
          HSVColor.fromAHSV(1.0, (h + 150) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 210) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 150) % 360, (s * 0.5).clamp(0.1, 1.0), (v * 0.4).clamp(0.1, 1.0)).toColor(),
          HSVColor.fromAHSV(1.0, h, 0.12, 0.96).toColor(),
        ];
        break;

      case HarmonyType.monochromatic:
        rawColors = [
          HSVColor.fromAHSV(1.0, h, (s * 1.0).clamp(0.1, 1.0), 0.25).toColor(),
          HSVColor.fromAHSV(1.0, h, (s * 0.9).clamp(0.1, 1.0), 0.45).toColor(),
          baseColor,
          HSVColor.fromAHSV(1.0, h, (s * 0.5).clamp(0.1, 1.0), 0.85).toColor(),
          HSVColor.fromAHSV(1.0, h, 0.12, 0.96).toColor(),
        ];
        break;

      case HarmonyType.tetradic:
        rawColors = [
          baseColor,
          HSVColor.fromAHSV(1.0, (h + 60) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 180) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, (h + 240) % 360, s, v).toColor(),
          HSVColor.fromAHSV(1.0, h, 0.12, 0.95).toColor(),
        ];
        break;
    }

    final roles = ['Base Primary', 'Secondary Harmony', 'Accent Color', 'Deep Tone', 'Highlight Tint'];
    return List.generate(rawColors.length, (i) {
      final c = rawColors[i];
      return PaletteColor(
        color: c,
        name: PaletteColor.findNearestName(c),
        role: i < roles.length ? roles[i] : 'Tone',
      );
    });
  }

  /// Renders a crisp aesthetic palette card to PNG byte array matching [style], [aspectRatio], and [theme].
  Future<Uint8List> renderPaletteCardImage({
    required ColorPaletteItem palette,
    required PaletteExportCardStyle style,
    PaletteExportAspectRatio aspectRatio = PaletteExportAspectRatio.portrait3x4,
    PaletteBackgroundTheme theme = PaletteBackgroundTheme.obsidian,
    Uint8List? sourceImageBytes,
    String? userHandle,
  }) async {
    final int width = aspectRatio.width;
    final int height = aspectRatio.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 1. Background Fill (Style stackedPills renders custom ambient background)
    if (style != PaletteExportCardStyle.stackedPills) {
      final bgPaint = Paint()..color = theme.backgroundColor;
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

      // Subtle ambient glow on dark themes
      if (palette.colors.isNotEmpty && theme == PaletteBackgroundTheme.obsidian) {
        final glowPaint = Paint()
          ..color = palette.colors.first.color.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
        canvas.drawCircle(Offset(width * 0.8, height * 0.15), 300, glowPaint);
      }
    }

    // 2. Dispatch to specific style renderer
    switch (style) {
      case PaletteExportCardStyle.circularSwatches:
        await _renderCircularSwatches(canvas, width, height, palette, theme);
        break;
      case PaletteExportCardStyle.squareSwatches:
        await _renderSquareSwatches(canvas, width, height, palette, theme);
        break;
      case PaletteExportCardStyle.verticalColumns:
        await _renderVerticalColumns(canvas, width, height, palette, theme);
        break;
      case PaletteExportCardStyle.horizontalRows:
        await _renderHorizontalRows(canvas, width, height, palette, theme);
        break;
      case PaletteExportCardStyle.photoCompanion:
        await _renderPhotoCompanion(canvas, width, height, palette, theme, sourceImageBytes);
        break;
      case PaletteExportCardStyle.stackedPills:
        await _renderStackedPills(canvas, width, height, palette, theme, userHandle: userHandle);
        break;
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    uiImage.dispose();

    return byteData!.buffer.asUint8List();
  }

  // ─── Style 1: Circular Swatches (Zero Overlap Guaranteed) ───
  Future<void> _renderCircularSwatches(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme,
  ) async {
    final double headerHeight = _drawStandardHeader(canvas, width, height, palette, theme);

    final swatches = palette.colors;
    final int count = swatches.length;
    final double startY = headerHeight + 20;
    final double availableH = height - startY - 90;

    // Grid layout: 1 row if count <= 4, 2 rows if count >= 5
    final int cols = count <= 4 ? count : (count <= 6 ? 3 : 4);
    final int rows = (count / cols).ceil();
    final double colWidth = (width - 128) / cols;
    final double rowHeight = availableH / rows;
    final double circleRadius = math.min(colWidth * 0.30, rowHeight * 0.26).clamp(32.0, 68.0);

    for (int i = 0; i < count; i++) {
      final item = swatches[i];
      final int r = i ~/ cols;
      final int c = i % cols;

      final double centerX = 64 + (c * colWidth) + (colWidth / 2);
      final double centerY = startY + (r * rowHeight) + (circleRadius + 10);

      // Shadow
      final shadowPaint = Paint()
        ..color = item.color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(centerX, centerY + 6), circleRadius, shadowPaint);

      // Circle Fill
      final fillPaint = Paint()..color = item.color;
      canvas.drawCircle(Offset(centerX, centerY), circleRadius, fillPaint);

      // Ring border
      final ringPaint = Paint()
        ..color = item.isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(centerX, centerY), circleRadius, ringPaint);

      // Text labels below circle with strict width bounds
      final double textY = centerY + circleRadius + 14;
      final double maxLabelWidth = colWidth - 12;

      _drawCenteredText(
        canvas: canvas,
        text: item.hexCode,
        centerX: centerX,
        y: textY,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: theme.primaryTextColor,
        letterSpacing: 1.0,
        maxWidth: maxLabelWidth,
      );

      _drawCenteredText(
        canvas: canvas,
        text: item.name.toUpperCase(),
        centerX: centerX,
        y: textY + 26,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: theme.secondaryTextColor,
        maxWidth: maxLabelWidth,
      );

      _drawCenteredText(
        canvas: canvas,
        text: item.role.toUpperCase(),
        centerX: centerX,
        y: textY + 44,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF00E5FF),
        maxWidth: maxLabelWidth,
      );
    }

    _drawFooter(canvas, width, height, theme);
  }

  // ─── Style 2: Pantone Square Swatches ───
  Future<void> _renderSquareSwatches(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme,
  ) async {
    final double headerHeight = _drawStandardHeader(canvas, width, height, palette, theme);

    final swatches = palette.colors;
    final int count = swatches.length;
    final double startY = headerHeight + 16;
    final double availableH = height - startY - 90;

    final int cols = count <= 3 ? count : (count <= 6 ? 3 : 4);
    final int rows = (count / cols).ceil();
    final double cardSpacing = 16.0;
    final double cardW = ((width - 128) - (cols - 1) * cardSpacing) / cols;
    final double cardH = (availableH - (rows - 1) * cardSpacing) / rows;

    for (int i = 0; i < count; i++) {
      final item = swatches[i];
      final int r = i ~/ cols;
      final int c = i % cols;

      final double cardX = 64 + c * (cardW + cardSpacing);
      final double cardY = startY + r * (cardH + cardSpacing);
      final cardRect = Rect.fromLTWH(cardX, cardY, cardW, cardH);
      final cardRRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(16));

      // Card Background (Slate or White)
      final cardBgColor = theme == PaletteBackgroundTheme.obsidian || theme == PaletteBackgroundTheme.slate
          ? const Color(0xFF1E293B)
          : Colors.white;
      canvas.drawRRect(cardRRect, Paint()..color = cardBgColor);

      // Card stroke
      canvas.drawRRect(
        cardRRect,
        Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Upper 66%: Solid Color Swatch
      final double swatchH = cardH * 0.66;
      final swatchRect = Rect.fromLTWH(cardX, cardY, cardW, swatchH);
      final swatchRRect = RRect.fromRectAndCorners(
        swatchRect,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      );
      canvas.drawRRect(swatchRRect, Paint()..color = item.color);

      // Lower 34%: Pantone-style Typography
      final double labelY = cardY + swatchH + 10;
      final double labelMaxW = cardW - 24;

      _drawText(
        canvas: canvas,
        text: item.hexCode,
        x: cardX + 12,
        y: labelY,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: theme.primaryTextColor,
        letterSpacing: 1.0,
        maxWidth: labelMaxW,
      );

      _drawText(
        canvas: canvas,
        text: item.name.toUpperCase(),
        x: cardX + 12,
        y: labelY + 24,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: theme.secondaryTextColor,
        maxWidth: labelMaxW,
      );

      _drawText(
        canvas: canvas,
        text: item.role.toUpperCase(),
        x: cardX + 12,
        y: labelY + 40,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF00E5FF),
        maxWidth: labelMaxW,
      );
    }

    _drawFooter(canvas, width, height, theme);
  }

  // ─── Style 3: Rectangular Box Columns ───
  Future<void> _renderVerticalColumns(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme,
  ) async {
    final double headerHeight = _drawStandardHeader(canvas, width, height, palette, theme);

    final swatches = palette.colors;
    final int count = swatches.length;
    final double startY = headerHeight + 16;
    final double availableH = height - startY - 90;

    final double colSpacing = 12.0;
    final double colW = ((width - 128) - (count - 1) * colSpacing) / count;

    for (int i = 0; i < count; i++) {
      final item = swatches[i];
      final double colX = 64 + i * (colW + colSpacing);
      final colRect = Rect.fromLTWH(colX, startY, colW, availableH);
      final colRRect = RRect.fromRectAndRadius(colRect, const Radius.circular(18));

      // Background card
      final cardBgColor = theme == PaletteBackgroundTheme.obsidian || theme == PaletteBackgroundTheme.slate
          ? const Color(0xFF1E293B)
          : Colors.white;
      canvas.drawRRect(colRRect, Paint()..color = cardBgColor);

      // Upper 74%: Color fill
      final double fillH = availableH * 0.74;
      final fillRect = Rect.fromLTWH(colX, startY, colW, fillH);
      final fillRRect = RRect.fromRectAndCorners(
        fillRect,
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
      );
      canvas.drawRRect(fillRRect, Paint()..color = item.color);

      // Lower 26%: Label footer
      final double labelY = startY + fillH + 12;
      final double centerX = colX + colW / 2;

      _drawCenteredText(
        canvas: canvas,
        text: item.hexCode,
        centerX: centerX,
        y: labelY,
        fontSize: math.min(18.0, colW * 0.16).clamp(12.0, 18.0),
        fontWeight: FontWeight.w800,
        color: theme.primaryTextColor,
        maxWidth: colW - 8,
      );

      _drawCenteredText(
        canvas: canvas,
        text: item.name.toUpperCase(),
        centerX: centerX,
        y: labelY + 24,
        fontSize: math.min(11.0, colW * 0.11).clamp(9.0, 11.5),
        fontWeight: FontWeight.w600,
        color: theme.secondaryTextColor,
        maxWidth: colW - 8,
      );
    }

    _drawFooter(canvas, width, height, theme);
  }

  // ─── Style 4: Horizontal Rows ───
  Future<void> _renderHorizontalRows(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme,
  ) async {
    final double headerHeight = _drawStandardHeader(canvas, width, height, palette, theme);

    final swatches = palette.colors;
    final int count = swatches.length;
    final double contentTop = headerHeight + 16;
    final double availableHeight = (height - contentTop - 90).toDouble();
    final double swatchSpacing = 12.0;
    final double swatchHeight = ((availableHeight - (count - 1) * swatchSpacing) / count).clamp(54.0, 140.0);

    for (int i = 0; i < count; i++) {
      final item = swatches[i];
      final double top = contentTop + i * (swatchHeight + swatchSpacing);
      final swatchRect = Rect.fromLTWH(64, top, width - 128, swatchHeight);
      final rrect = RRect.fromRectAndRadius(swatchRect, const Radius.circular(16));

      // 1. Swatch Block Fill
      canvas.drawRRect(rrect, Paint()..color = item.color);

      // 2. Subtle border
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = item.isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // 3. Content
      final textColor = item.onColor;
      final double centerY = top + swatchHeight / 2;

      // Left text: Color Name & Role with maxWidth protection so it NEVER hits the right pill
      final double leftMaxW = (width - 128) * 0.55;

      _drawText(
        canvas: canvas,
        text: item.name.toUpperCase(),
        x: 92,
        y: centerY - 20,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: 1.0,
        maxWidth: leftMaxW,
      );

      _drawText(
        canvas: canvas,
        text: item.role.toUpperCase(),
        x: 92,
        y: centerY + 6,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textColor.withOpacity(0.75),
        letterSpacing: 0.8,
        maxWidth: leftMaxW,
      );

      // Right text: HEX Code & RGB
      final double hexRight = width - 96;
      final double rightMaxW = (width - 128) * 0.35;

      _drawText(
        canvas: canvas,
        text: item.hexCode,
        x: hexRight - 150,
        y: centerY - 20,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: 1.2,
        maxWidth: rightMaxW,
      );

      _drawText(
        canvas: canvas,
        text: item.rgbString,
        x: hexRight - 150,
        y: centerY + 6,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textColor.withOpacity(0.75),
        maxWidth: rightMaxW,
      );
    }

    _drawFooter(canvas, width, height, theme);
  }

  // ─── Style 5: Photo Companion ───
  Future<void> _renderPhotoCompanion(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme,
    Uint8List? sourceImageBytes,
  ) async {
    final double headerHeight = _drawStandardHeader(canvas, width, height, palette, theme);
    double contentTop = headerHeight + 14;

    // Photo Preview
    if (sourceImageBytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(sourceImageBytes);
        final frame = await codec.getNextFrame();
        final ui.Image photo = frame.image;

        // Dynamic photo height based on 1:1 vs 3:4 canvas
        final double photoHeight = height > 1200 ? 560.0 : 420.0;
        final double photoWidth = width - 128;
        final photoRect = Rect.fromLTWH(64, contentTop, photoWidth, photoHeight);
        final rrect = RRect.fromRectAndRadius(photoRect, const Radius.circular(20));

        canvas.save();
        canvas.clipRRect(rrect);
        final srcRect = Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble());
        canvas.drawImageRect(photo, srcRect, photoRect, Paint()..filterQuality = FilterQuality.high);
        canvas.restore();

        // Border
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = Colors.white.withOpacity(0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );

        contentTop += photoHeight + 28;
        photo.dispose();
      } catch (e) {
        debugPrint('photoCompanion render error: $e');
      }
    }

    // Circular Swatches with Connectors underneath photo
    final swatches = palette.colors;
    final int count = swatches.length;
    final double swatchW = (width - 128) / count;
    final double circleRadius = (swatchW * 0.30).clamp(24.0, 46.0);
    final double circleCenterY = contentTop + circleRadius + 8;

    for (int i = 0; i < count; i++) {
      final item = swatches[i];
      final double centerX = 64 + (i * swatchW) + (swatchW / 2);

      // Connector line from photo to circle
      if (sourceImageBytes != null) {
        canvas.drawLine(
          Offset(centerX, contentTop - 18),
          Offset(centerX, circleCenterY - circleRadius),
          Paint()
            ..color = item.color.withOpacity(0.4)
            ..strokeWidth = 2,
        );
      }

      // Circle Fill
      canvas.drawCircle(Offset(centerX, circleCenterY), circleRadius, Paint()..color = item.color);
      canvas.drawCircle(
        Offset(centerX, circleCenterY),
        circleRadius,
        Paint()
          ..color = item.isDark ? Colors.white24 : Colors.black12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Hex code & name badge below circle with strict width bounds
      final double maxW = swatchW - 8;

      _drawCenteredText(
        canvas: canvas,
        text: item.hexCode,
        centerX: centerX,
        y: circleCenterY + circleRadius + 12,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: theme.primaryTextColor,
        maxWidth: maxW,
      );

      _drawCenteredText(
        canvas: canvas,
        text: item.name.toUpperCase(),
        centerX: centerX,
        y: circleCenterY + circleRadius + 32,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: theme.secondaryTextColor,
        maxWidth: maxW,
      );
    }

    _drawFooter(canvas, width, height, theme);
  }

  // ─── Style 6: Cascading Deck (Stacked Overlapping 3D Pills like pref2.jpg) ───
  Future<void> _renderStackedPills(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme, {
    String? userHandle,
  }) async {
    final swatches = palette.colors;
    final int count = swatches.length;
    if (count == 0) return;

    // 1. Ambient Background & Spotlight Flares
    // Compute dominant tones for the ambient backlight
    final Color dominantColor = swatches.first.color;
    final Color accentColor = swatches.length > 2 ? swatches[count ~/ 2].color : dominantColor;

    // Base background tone based on selected theme
    final Color baseBg = theme == PaletteBackgroundTheme.pureWhite
        ? const Color(0xFFF1F5F9)
        : (theme == PaletteBackgroundTheme.warmSand
            ? const Color(0xFF1C1917)
            : const Color(0xFF090D16)); // deep sleek obsidian/space black

    // Draw base background
    final bgPaint = Paint()..color = baseBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    // Warm radial spotlight right behind the card deck
    final spotlightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.5, height * 0.46),
        width * 0.65,
        [
          accentColor.withOpacity(0.28),
          dominantColor.withOpacity(0.12),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), spotlightPaint);

    // Side edge light flares (Left flare & Right flare like pref2.jpg)
    final leftFlarePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(0, height * 0.44),
        width * 0.45,
        [
          accentColor.withOpacity(0.35),
          Colors.transparent,
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(Offset(0, height * 0.44), width * 0.45, leftFlarePaint);

    final rightFlarePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width.toDouble(), height * 0.48),
        width * 0.45,
        [
          dominantColor.withOpacity(0.30),
          Colors.transparent,
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(Offset(width.toDouble(), height * 0.48), width * 0.45, rightFlarePaint);

    // 2. Top Minimalist Page / Palette Indicator Badge (e.g., "1/5" or "5 COLORS" in top-right)
    final double topBadgeY = 70.0;
    final String pageIndicator = '${count} COLORS';
    final pageBadgePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final pageBadgeBorder = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double badgeW = 100.0;
    const double badgeH = 34.0;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(width - 64.0 - badgeW, topBadgeY, badgeW, badgeH),
      const Radius.circular(17),
    );
    canvas.drawRRect(badgeRect, pageBadgePaint);
    canvas.drawRRect(badgeRect, pageBadgeBorder);

    _drawCenteredText(
      canvas: canvas,
      text: pageIndicator,
      centerX: width - 64.0 - (badgeW / 2),
      y: topBadgeY + 8,
      fontSize: 12.0,
      fontWeight: FontWeight.w700,
      color: Colors.white.withOpacity(0.85),
      letterSpacing: 1.2,
    );

    // Also draw title subtly in the top left
    _drawText(
      canvas: canvas,
      text: palette.title.toUpperCase(),
      x: 64.0,
      y: topBadgeY + 6,
      fontSize: 16.0,
      fontWeight: FontWeight.w800,
      color: Colors.white.withOpacity(0.85),
      letterSpacing: 2.0,
      maxWidth: width - 200,
    );

    // 3. Compute Stack Layout Dimensions
    // Deck cards should take up the central vertical region with smooth overlap
    final bool isCompact = height <= 1100; // 1:1 Square
    final double pillWidth = (width * 0.68).clamp(580.0, 740.0);
    final double pillLeft = (width - pillWidth) / 2;

    // Calculate vertical step and height
    // Each pill overlaps with the next. The visible vertical step between pills:
    final double pillHeight = isCompact
        ? (560.0 / (count + 1.2)).clamp(75.0, 110.0)
        : (760.0 / (count + 1.2)).clamp(95.0, 130.0);
    final double cornerRadius = pillHeight / 2; // Stadium shape!

    // Overlap step: around 60% of pill height so 40% remains visible for the label
    final double verticalStep = pillHeight * 0.60;
    final double totalDeckHeight = pillHeight + (count - 1) * verticalStep;
    final double deckStartY = (height - totalDeckHeight) / 2 + (isCompact ? 10.0 : 0.0);

    // 4. Render Stack of Pills (Top to bottom, so top pill is drawn first,
    // and subsequent pills are drawn under or over). In pref2.jpg:
    // Notice the top card overlaps the second card, second card overlaps third card, etc.
    // So earlier pills cast shadow downwards onto the later pills!
    // To achieve downward overlapping shadows:
    // We draw from bottom (index count - 1) up to top (index 0) so the top card sits on top of all.
    for (int i = count - 1; i >= 0; i--) {
      final item = swatches[i];
      final double pillTop = deckStartY + (i * verticalStep);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
        Radius.circular(cornerRadius),
      );

      // Deep, soft downward drop shadow onto the card below & canvas
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pillLeft, pillTop + 14, pillWidth, pillHeight),
          Radius.circular(cornerRadius),
        ),
        shadowPaint,
      );

      // Pill solid color fill
      final fillPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, fillPaint);

      // Subtle inner rim/specular highlight at the top edge of each pill
      final rimPaint = Paint()
        ..color = Colors.white.withOpacity(item.isDark ? 0.15 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(rrect, rimPaint);

      // Pill Text Content:
      // Left-aligned uppercase Hex Code in clean, prominent font
      // Color is high contrast `item.onColor`
      final textColor = item.onColor;
      final double textX = pillLeft + 42.0;
      // In cascading stack, the top visible portion is between pillTop and (pillTop + verticalStep)
      // When it's the last (bottom) pill, the entire pill height is visible
      final double visibleH = (i == count - 1) ? pillHeight : verticalStep;
      final double textY = pillTop + (visibleH / 2) - 12.0;

      _drawText(
        canvas: canvas,
        text: item.hexCode,
        x: textX,
        y: textY,
        fontSize: (pillHeight * 0.23).clamp(18.0, 24.0),
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: 1.5,
      );

      // Color name on the right side if space permits
      final double nameX = pillLeft + pillWidth - 42.0;
      final namePainter = TextPainter(
        text: TextSpan(
          text: item.name.toUpperCase(),
          style: TextStyle(
            color: textColor.withOpacity(0.70),
            fontSize: (pillHeight * 0.16).clamp(12.0, 15.0),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontFamily: 'Poppins',
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: pillWidth * 0.40);
      namePainter.paint(canvas, Offset(nameX - namePainter.width, textY + 2));
    }

    // 5. Footer Attribution Line (e.g. "— @username —" with thin horizontal accent dashes)
    final String handle = (userHandle != null && userHandle.isNotEmpty)
        ? (userHandle.startsWith('@') ? userHandle : '@$userHandle')
        : '@quickpost';

    final double footerY = height - (isCompact ? 56.0 : 72.0);
    final footerColor = Colors.white.withOpacity(0.70);

    // Draw handle in center
    final handlePainter = TextPainter(
      text: TextSpan(
        text: handle,
        style: TextStyle(
          color: footerColor,
          fontSize: 16.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double handleX = (width - handlePainter.width) / 2;
    handlePainter.paint(canvas, Offset(handleX, footerY));

    // Draw aesthetic dashes / lines on left and right of handle
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.5;

    const double lineLength = 48.0;
    const double lineSpacing = 16.0;

    // Left dash
    final double leftLineEnd = handleX - lineSpacing;
    final double leftLineStart = leftLineEnd - lineLength;
    canvas.drawLine(
      Offset(leftLineStart, footerY + (handlePainter.height / 2)),
      Offset(leftLineEnd, footerY + (handlePainter.height / 2)),
      linePaint,
    );

    // Right dash
    final double rightLineStart = handleX + handlePainter.width + lineSpacing;
    final double rightLineEnd = rightLineStart + lineLength;
    canvas.drawLine(
      Offset(rightLineStart, footerY + (handlePainter.height / 2)),
      Offset(rightLineEnd, footerY + (handlePainter.height / 2)),
      linePaint,
    );
  }

  // ─── Shared Header & Footer Helpers (Poppins Typography) ───
  double _drawStandardHeader(
    Canvas canvas,
    int width,
    int height,
    ColorPaletteItem palette,
    PaletteBackgroundTheme theme,
  ) {
    final bool isCompact = height <= 1100;
    final double topMargin = isCompact ? 44.0 : 56.0;

    _drawText(
      canvas: canvas,
      text: 'QUICK POST PALETTE STUDIO',
      x: 64,
      y: topMargin,
      fontSize: isCompact ? 18 : 20,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF00E5FF),
      letterSpacing: 3.5,
      maxWidth: width - 128,
    );

    _drawText(
      canvas: canvas,
      text: palette.title,
      x: 64,
      y: topMargin + (isCompact ? 28 : 34),
      fontSize: isCompact ? 38 : 44,
      fontWeight: FontWeight.bold,
      color: theme.primaryTextColor,
      maxWidth: width - 128,
    );

    _drawText(
      canvas: canvas,
      text: '${palette.category.toUpperCase()} • ${palette.colors.length} HARMONIC SHADES',
      x: 64,
      y: topMargin + (isCompact ? 76 : 88),
      fontSize: isCompact ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: theme.secondaryTextColor,
      letterSpacing: 1.5,
      maxWidth: width - 128,
    );

    return topMargin + (isCompact ? 104 : 120);
  }

  void _drawFooter(Canvas canvas, int width, int height, PaletteBackgroundTheme theme) {
    _drawText(
      canvas: canvas,
      text: 'CREATED WITH QUICK POST • CREATOR STUDIO',
      x: 64,
      y: height - 52,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: theme.secondaryTextColor,
      letterSpacing: 2.5,
      maxWidth: width - 128,
    );
  }

  static void _drawCenteredText({
    required Canvas canvas,
    required String text,
    required double centerX,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0.0,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, Offset(centerX - (tp.width / 2), y));
  }

  static void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0.0,
    double? maxWidth,
    int? maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: overflow == TextOverflow.ellipsis ? '...' : null,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, Offset(x, y));
  }

  /// Saves the rendered palette card into the Android MediaStore under "Pictures/Quick Post Palettes".
  Future<String?> savePaletteImageToGallery(Uint8List pngBytes, String title) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'Palette_${safeName}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post Palettes',
      });
    } catch (e) {
      debugPrint('saveImageToGallery channel error: $e');
    }

    // Trigger MediaScanner for immediate visibility in Gallery/Photos
    if (finalSavedPath != null && finalSavedPath.startsWith('/')) {
      try {
        await _channel.invokeMethod('scanMediaFile', {
          'filePath': finalSavedPath,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    // Only fallback if MediaStore saving failed completely
    final bool mediaStoreSuccess = finalSavedPath != null &&
        (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

    if (!mediaStoreSuccess) {
      try {
        final dcimDir = Directory('/storage/emulated/0/Pictures/Quick Post Palettes');
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }
        final file = File('${dcimDir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;

        await _channel.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    // App Documents fallback
    if (finalSavedPath == null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;
      } catch (_) {}
    }

    return finalSavedPath;
  }

  /// Shares the exported palette image file via Android share sheet.
  Future<void> sharePaletteImage(String filePath, String title) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'image/png')],
      text: 'Aesthetic Color Palette "$title" created with Quick Post!',
    );
  }
}

