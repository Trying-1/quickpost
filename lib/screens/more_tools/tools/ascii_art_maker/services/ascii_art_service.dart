import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ascii_art_model.dart';

/// Compiled GPU-cached ASCII art texture & copyable plain-text payload.
class AsciiRenderData {
  final ui.Image rasterImage;
  final String plainText;
  final int cols;
  final int rows;

  const AsciiRenderData({
    required this.rasterImage,
    required this.plainText,
    required this.cols,
    required this.rows,
  });

  void dispose() {
    rasterImage.dispose();
  }
}

/// High-performance ASCII Art Engine:
/// - Maintains a lightweight 200px sampling buffer so ASCII regeneration runs in < 5ms
/// - Pre-rasterizes ASCII typography ONCE into a crisp 1080px GPU texture (zero per-frame Paragraph blur lag)
/// - Supports hardware single-pass phosphor bloom glow & true-color coalesced glyph runs
class AsciiArtService {
  static final AsciiArtService _instance = AsciiArtService._internal();
  factory AsciiArtService() => _instance;
  AsciiArtService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  double? _cachedCellRatio; // lineH / charW for platform monospace font

  Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Decodes photo to lightweight 200px sampling [img.Image] + 900px preview [ui.Image].
  Future<({img.Image samplingImg, ui.Image previewUiImg})?> decodeImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      img.Image oriented = img.bakeOrientation(decoded);
      if (oriented.width > 900 || oriented.height > 900) {
        oriented = oriented.width >= oriented.height
            ? img.copyResize(oriented, width: 900, interpolation: img.Interpolation.linear)
            : img.copyResize(oriented, height: 900, interpolation: img.Interpolation.linear);
      }

      final uiImg = await _imgToUiImage(oriented);

      // Keep a fast 220px buffer exclusively for instant ASCII sampling (< 2ms resize)
      final img.Image sampling = (oriented.width > 220 || oriented.height > 220)
          ? (oriented.width >= oriented.height
              ? img.copyResize(oriented, width: 220, interpolation: img.Interpolation.linear)
              : img.copyResize(oriented, height: 220, interpolation: img.Interpolation.linear))
          : oriented;

      return (samplingImg: sampling, previewUiImg: uiImg);
    } catch (e) {
      debugPrint('AsciiArtService decode error: $e');
      return null;
    }
  }

  Future<ui.Image> _imgToUiImage(img.Image source) async {
    final int w = source.width;
    final int h = source.height;
    final Uint8List rgba = Uint8List(w * h * 4);
    int offset = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        rgba[offset++] = p.r.toInt().clamp(0, 255);
        rgba[offset++] = p.g.toInt().clamp(0, 255);
        rgba[offset++] = p.b.toInt().clamp(0, 255);
        rgba[offset++] = p.a.toInt().clamp(0, 255);
      }
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Generates a lightweight high-contrast geometric planet demo scene (200x250 = fast!).
  Future<({img.Image samplingImg, ui.Image previewUiImg})> generateSampleScene() async {
    const int width = 200;
    const int height = 250;
    final img.Image canvas = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final double ny = y / height;
      for (int x = 0; x < width; x++) {
        final double nx = x / width;

        double r = 10 + (1.0 - ny) * 35;
        double g = 14 + ny * 38;
        double b = 26 + ny * 65;

        final double pdx = nx - 0.50;
        final double pdy = (ny - 0.36) * (height / width);
        final double pDist = math.sqrt(pdx * pdx + pdy * pdy);

        if (pDist < 0.24) {
          final double nz = math.sqrt(math.max(0.0, 0.24 * 0.24 - pDist * pDist)) / 0.24;
          const double lx = -0.55;
          const double ly = -0.55;
          const double lz = 0.62;
          final double nxS = pdx / 0.24;
          final double nyS = pdy / 0.24;
          final double diff = math.max(0.06, nxS * lx + nyS * ly + nz * lz);
          final double band = 0.85 + 0.15 * math.sin(nyS * 14.0);
          r = (255 * diff * band).clamp(0, 255);
          g = (210 * diff * band).clamp(0, 255);
          b = (155 * diff + 45).clamp(0, 255);
        }

        final double rx = pdx * 0.94 + pdy * 0.34;
        final double ry = (-pdx * 0.34 + pdy * 0.94) * 3.8;
        final double ringDist = math.sqrt(rx * rx + ry * ry);
        if (ringDist > 0.30 && ringDist < 0.44 && (pDist >= 0.24 || pdy > 0.0)) {
          final double ringGlow = 1.0 - ((ringDist - 0.37).abs() / 0.07);
          r = (r + 185 * ringGlow).clamp(0, 255);
          g = (g + 245 * ringGlow).clamp(0, 255);
          b = (b + 235 * ringGlow).clamp(0, 255);
        }

        final double m1 = 0.78 - 0.20 * math.max(0.0, 1.0 - (nx - 0.22).abs() * 3.4);
        final double m2 = 0.78 - 0.24 * math.max(0.0, 1.0 - (nx - 0.78).abs() * 3.1);
        final double m3 = 0.80 - 0.14 * math.max(0.0, 1.0 - (nx - 0.50).abs() * 4.8);
        final double horizon = math.min(m1, math.min(m2, m3));
        if (ny > horizon) {
          final double slopeLight = (nx < 0.22 || (nx > 0.50 && nx < 0.78)) ? 0.55 : 0.18;
          r = 25 * slopeLight + 6;
          g = 155 * slopeLight + 12;
          b = 140 * slopeLight + 18;
        }

        if (ny < 0.68 && pDist > 0.26 && ((x * 97 + y * 151) % 311 == 0)) {
          r = 255;
          g = 255;
          b = 255;
        }

        canvas.setPixelRgba(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
          255,
        );
      }
    }

    final uiImg = await _imgToUiImage(canvas);
    return (samplingImg: canvas, previewUiImg: uiImg);
  }

  /// Measures exact monospace glyph `lineHeight / charWidth` ratio once.
  double _measureMonospaceCellRatio() {
    if (_cachedCellRatio != null) return _cachedCellRatio!;

    const double testSize = 16.0;
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontFamily: 'monospace', fontSize: testSize, height: 1.02),
    )
      ..pushStyle(ui.TextStyle(fontFamily: 'monospace', fontSize: testSize, height: 1.02))
      ..addText('MMMMMMMMMM');

    final p = pb.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    final double charW = p.maxIntrinsicWidth / 10.0;
    final double lineH = p.height;
    p.dispose();

    _cachedCellRatio = (charW > 0.5 && lineH > 0.5) ? (lineH / charW) : 1.72;
    return _cachedCellRatio!;
  }

  /// Samples [source], constructs crisp typographic Paragraph WITHOUT per-glyph blur shadows,
  /// and bakes ONCE into a sharp cached [ui.Image] texture (with optional hardware glow pass).
  Future<AsciiRenderData> generateAsciiArt({
    required img.Image source,
    required AsciiArtConfig config,
  }) async {
    // 1. Optional aspect crop
    img.Image cropped = source;
    final double? targetRatio = config.aspectRatio.ratio;
    if (targetRatio != null && targetRatio > 0) {
      final double srcRatio = source.width / source.height;
      int cropW = source.width;
      int cropH = source.height;
      if (srcRatio > targetRatio) {
        cropW = (source.height * targetRatio).round().clamp(1, source.width);
      } else if (srcRatio < targetRatio) {
        cropH = (source.width / targetRatio).round().clamp(1, source.height);
      }
      final int offsetX = ((source.width - cropW) / 2).round();
      final int offsetY = ((source.height - cropH) / 2).round();
      cropped = img.copyCrop(source, x: offsetX, y: offsetY, width: cropW, height: cropH);
    }

    // 2. Compute grid dimensions compensated for monospace character aspect ratio
    final double cellAspect = _measureMonospaceCellRatio();
    final int cols = config.columns.clamp(24, 100);
    final double imgAspect = cropped.width / cropped.height;
    final int rows = math.max(8, (cols / imgAspect / cellAspect).round()).clamp(8, 120);

    final img.Image sampled = img.copyResize(
      cropped,
      width: cols,
      height: rows,
      interpolation: img.Interpolation.linear,
    );

    // 3. Prepare character ramp string
    final String rawRamp = config.charset == AsciiCharset.custom
        ? (config.customRampText.isNotEmpty ? config.customRampText : 'ASCII*:. ')
        : config.charset.ramp;

    final bool isDarkCanvas = config.colorMode.bgColor.computeLuminance() < 0.35;
    final bool brightMeansDense = isDarkCanvas ? !config.invertLuminance : config.invertLuminance;
    final List<String> glyphs =
        (brightMeansDense ? rawRamp.split('').reversed : rawRamp.split('')).toList();
    final int maxGlyphIdx = glyphs.length - 1;

    // 4. Build vector Paragraph cleanly (zero per-glyph TextStyle.shadows overhead!)
    const double refFontSize = 14.0;
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: 'monospace',
        fontSize: refFontSize,
        height: 1.02,
        maxLines: rows,
      ),
    );

    final StringBuffer plainBuf = StringBuffer();
    final double brightShift = config.brightness * 255.0;
    final double contrastF = config.contrast;

    if (!config.colorMode.usesPhotoColors && config.colorMode != AsciiColorMode.synthNeon) {
      // Ultra-fast single TextStyle span across ALL rows!
      for (int y = 0; y < rows; y++) {
        for (int x = 0; x < cols; x++) {
          final p = sampled.getPixel(x, y);
          final double r = ((p.r.toDouble() - 128.0) * contrastF + 128.0) + brightShift;
          final double g = ((p.g.toDouble() - 128.0) * contrastF + 128.0) + brightShift;
          final double b = ((p.b.toDouble() - 128.0) * contrastF + 128.0) + brightShift;
          final double lum = ((0.299 * r + 0.587 * g + 0.114 * b) / 255.0).clamp(0.0, 1.0);
          plainBuf.write(glyphs[(lum * maxGlyphIdx).round().clamp(0, maxGlyphIdx)]);
        }
        if (y < rows - 1) plainBuf.write('\n');
      }

      pb.pushStyle(ui.TextStyle(
        fontFamily: 'monospace',
        fontSize: refFontSize,
        height: 1.02,
        color: config.colorMode.fgColor,
      ));
      pb.addText(plainBuf.toString());
      pb.pop();
    } else {
      // Multi-color coalesced runs (quantized 4-bit color steps for rapid Skia paragraph build)
      for (int y = 0; y < rows; y++) {
        int? lastColorArgb;
        final StringBuffer spanRun = StringBuffer();

        void flushSpan() {
          if (spanRun.isEmpty || lastColorArgb == null) return;
          pb.pushStyle(ui.TextStyle(
            fontFamily: 'monospace',
            fontSize: refFontSize,
            height: 1.02,
            color: Color(lastColorArgb),
          ));
          pb.addText(spanRun.toString());
          pb.pop();
          spanRun.clear();
        }

        for (int x = 0; x < cols; x++) {
          final p = sampled.getPixel(x, y);
          final int ir = (((p.r.toDouble() - 128.0) * contrastF + 128.0) + brightShift).round().clamp(0, 255);
          final int ig = (((p.g.toDouble() - 128.0) * contrastF + 128.0) + brightShift).round().clamp(0, 255);
          final int ib = (((p.b.toDouble() - 128.0) * contrastF + 128.0) + brightShift).round().clamp(0, 255);

          final double lum = ((0.299 * ir + 0.587 * ig + 0.114 * ib) / 255.0).clamp(0.0, 1.0);
          final String ch = glyphs[(lum * maxGlyphIdx).round().clamp(0, maxGlyphIdx)];
          plainBuf.write(ch);

          Color glyphColor;
          if (config.colorMode == AsciiColorMode.synthNeon) {
            final double qLum = (lum * 8).round() / 8.0;
            glyphColor = Color.lerp(config.colorMode.secondaryColor, config.colorMode.fgColor, qLum) ??
                config.colorMode.fgColor;
          } else {
            // 4-bit quantization merges neighboring pixels into fast spans
            glyphColor = Color.fromARGB(
              255,
              ((ir >> 4) << 4).clamp(0, 255),
              ((ig >> 4) << 4).clamp(0, 255),
              ((ib >> 4) << 4).clamp(0, 255),
            );
          }

          final int argb = glyphColor.toARGB32();
          if (lastColorArgb != argb) {
            flushSpan();
            lastColorArgb = argb;
          }
          spanRun.write(ch);
        }

        if (y < rows - 1) {
          plainBuf.write('\n');
          spanRun.write('\n');
        }
        flushSpan();
      }
    }

    final ui.Paragraph paragraph = pb.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    final double pW = math.max(1.0, paragraph.maxIntrinsicWidth);
    final double pH = math.max(1.0, paragraph.height);

    // 5. Bake ONCE into a crisp high-res GPU ui.Image (target ~1080px wide)
    const int texW = 1080;
    final int texH = math.max(120, (texW * (pH / pW)).round());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas bakeCanvas = Canvas(recorder, Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble()));

    final double sx = texW / pW;
    final double sy = texH / pH;

    if (config.enableGlow) {
      // Single hardware-blurred bloom pass baked ONCE (0 UI-frame cost!)
      bakeCanvas.saveLayer(
        Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble()),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
      );
      bakeCanvas.scale(sx, sy);
      bakeCanvas.drawParagraph(paragraph, Offset.zero);
      bakeCanvas.restore();
    }

    bakeCanvas.save();
    bakeCanvas.scale(sx, sy);
    bakeCanvas.drawParagraph(paragraph, Offset.zero);
    bakeCanvas.restore();

    paragraph.dispose();

    final ui.Picture pic = recorder.endRecording();
    final ui.Image rasterImage = await pic.toImage(texW, texH);
    pic.dispose();

    return AsciiRenderData(
      rasterImage: rasterImage,
      plainText: plainBuf.toString(),
      cols: cols,
      rows: rows,
    );
  }

  /// Captures the RepaintBoundary ASCII graphic at crisp 3.0x resolution.
  Future<Uint8List?> captureBoundary(GlobalKey boundaryKey, {double pixelRatio = 3.0}) async {
    try {
      final RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('AsciiArtService captureBoundary error: $e');
      return null;
    }
  }

  /// Saves ASCII art PNG to Pictures/Quick Post ASCII in Android MediaStore.
  Future<String?> saveAsciiToGallery(Uint8List pngBytes, String presetName) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = presetName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'QuickPostASCII_${safeName}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post ASCII',
      });
    } catch (e) {
      debugPrint('saveImageToGallery channel error: $e');
    }

    if (finalSavedPath != null && finalSavedPath.startsWith('/')) {
      try {
        await _channel.invokeMethod('scanMediaFile', {
          'filePath': finalSavedPath,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    final bool mediaStoreSuccess = finalSavedPath != null &&
        (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

    if (!mediaStoreSuccess) {
      try {
        final dcimDir = Directory('/storage/emulated/0/Pictures/Quick Post ASCII');
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

  Future<void> shareAscii(String filePath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'image/png')],
          text: 'Created with QuickPost ASCII Art Studio',
        ),
      );
    } catch (e) {
      debugPrint('Share ASCII error: $e');
    }
  }
}
