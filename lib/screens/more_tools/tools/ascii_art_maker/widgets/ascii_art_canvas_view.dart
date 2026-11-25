import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/ascii_art_model.dart';
import '../services/ascii_art_service.dart';

/// Proportional zero-overflow ASCII Art canvas renderer.
/// Scales pre-laid-out vector [ui.Paragraph] glyphs crisply inside 4 retro terminal/zine frames.
class AsciiArtCanvasView extends StatelessWidget {
  final GlobalKey? boundaryKey;
  final AsciiRenderData? renderData;
  final ui.Image? originalImage;
  final AsciiArtConfig config;
  final bool isPeekingOriginal;

  const AsciiArtCanvasView({
    super.key,
    this.boundaryKey,
    required this.renderData,
    required this.originalImage,
    required this.config,
    this.isPeekingOriginal = false,
  });

  double _effectiveAspectRatio() {
    if (config.aspectRatio.ratio != null) {
      return config.aspectRatio.ratio!;
    }
    if (originalImage != null && originalImage!.height > 0) {
      return (originalImage!.width / originalImage!.height).clamp(0.45, 2.2);
    }
    return 4.0 / 5.0;
  }

  @override
  Widget build(BuildContext context) {
    if (renderData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    const double refWidth = 360.0;
    final double ratio = _effectiveAspectRatio();

    return FittedBox(
      fit: BoxFit.contain,
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: refWidth,
          child: _buildFramedCanvas(refWidth, ratio),
        ),
      ),
    );
  }

  Widget _buildAsciiViewport(double aspectRatio) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CustomPaint(
        painter: _AsciiArtPainter(
          renderData: renderData!,
          originalImage: originalImage,
          config: config,
          isPeekingOriginal: isPeekingOriginal,
        ),
      ),
    );
  }

  Widget _buildFramedCanvas(double width, double imgRatio) {
    switch (config.frameStyle) {
      case AsciiFrameStyle.frameless:
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _buildAsciiViewport(imgRatio),
        );

      case AsciiFrameStyle.macTerminal:
        return _buildMacTerminal(width, imgRatio);

      case AsciiFrameStyle.crtMonitor:
        return _buildCrtMonitor(width, imgRatio);

      case AsciiFrameStyle.zinePoster:
        return _buildZinePoster(width, imgRatio);
    }
  }

  /// Authentic macOS / Linux Terminal shell window frame.
  Widget _buildMacTerminal(double width, double imgRatio) {
    final bool isLightTheme = config.colorMode == AsciiColorMode.newsprintInk;
    final Color shellBg = isLightTheme ? const Color(0xFFF3EFE6) : const Color(0xFF141820);
    final Color barBg = isLightTheme ? const Color(0xFFE7E1D4) : const Color(0xFF1E2430);
    final Color textColor = isLightTheme ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: shellBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLightTheme ? const Color(0xFFD6CEC0) : const Color(0xFF2D3546),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: barBg,
              child: Row(
                children: [
                  const CircleAvatar(radius: 4.5, backgroundColor: Color(0xFFFF5F56)),
                  const SizedBox(width: 5),
                  const CircleAvatar(radius: 4.5, backgroundColor: Color(0xFFFFBD2E)),
                  const SizedBox(width: 5),
                  const CircleAvatar(radius: 4.5, backgroundColor: Color(0xFF27C93F)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      config.headerTitle.isNotEmpty
                          ? config.headerTitle
                          : 'ascii_render.sh — ${renderData!.cols}x${renderData!.rows}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ASCII Canvas
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildAsciiViewport(imgRatio),
            ),
          ],
        ),
      ),
    );
  }

  /// Glowing Retro CRT Computer Terminal Bezel.
  Widget _buildCrtMonitor(double width, double imgRatio) {
    final Color accent = config.colorMode.fgColor;

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1016),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  config.headerTitle.isNotEmpty ? config.headerTitle.toUpperCase() : 'ASCII-CRT SYS // 64KB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '${renderData!.cols}x${renderData!.rows}',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF282D3D), width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildAsciiViewport(imgRatio),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHARSET: ${config.charset.label.toUpperCase()}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 8.5,
                  fontFamily: 'monospace',
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Minimal Editorial Zine Exhibition Print Poster.
  Widget _buildZinePoster(double width, double imgRatio) {
    final bool isLightTheme = config.colorMode == AsciiColorMode.newsprintInk;
    final Color frameBg = isLightTheme ? const Color(0xFFFDFBF7) : const Color(0xFF111827);
    final Color textColor = isLightTheme ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: frameBg,
        border: Border.all(
          color: isLightTheme ? const Color(0xFFD6D1C7) : const Color(0xFF334155),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: textColor.withValues(alpha: 0.25), width: 1),
            ),
            child: _buildAsciiViewport(imgRatio),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  config.headerTitle.isNotEmpty
                      ? config.headerTitle.toUpperCase()
                      : 'FIG 01. TYPOGRAPHIC STUDY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                '${renderData!.cols} COL',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.65),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering the calibrated vector [ui.Paragraph], optional double-exposure photo bleed,
/// and horizontal CRT scanlines cleanly with zero wrapping bugs.
class _AsciiArtPainter extends CustomPainter {
  final AsciiRenderData renderData;
  final ui.Image? originalImage;
  final AsciiArtConfig config;
  final bool isPeekingOriginal;

  _AsciiArtPainter({
    required this.renderData,
    required this.originalImage,
    required this.config,
    required this.isPeekingOriginal,
  });

  void _drawCroppedOriginal(Canvas canvas, Size size, Paint paint) {
    if (originalImage == null) return;
    final double srcAspect = originalImage!.width / originalImage!.height;
    final double dstAspect = size.width / size.height;

    Rect srcRect;
    if (srcAspect > dstAspect) {
      final double cropW = originalImage!.height * dstAspect;
      final double dx = (originalImage!.width - cropW) / 2.0;
      srcRect = Rect.fromLTWH(dx, 0, cropW, originalImage!.height.toDouble());
    } else {
      final double cropH = originalImage!.width / dstAspect;
      final double dy = (originalImage!.height - cropH) / 2.0;
      srcRect = Rect.fromLTWH(0, dy, originalImage!.width.toDouble(), cropH);
    }

    canvas.drawImageRect(
      originalImage!,
      srcRect,
      Offset.zero & size,
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    if (isPeekingOriginal && originalImage != null) {
      _drawCroppedOriginal(canvas, size, Paint()..filterQuality = FilterQuality.medium);
      return;
    }

    // 1. Terminal Background Color
    canvas.drawRect(rect, Paint()..color = config.colorMode.bgColor);

    // 2. Optional faint Double-Exposure Photo Ghost (single pass without saveLayer)
    if (config.photoBgOpacity > 0.01 && originalImage != null) {
      _drawCroppedOriginal(canvas, size, Paint()..filterQuality = FilterQuality.low);
      canvas.drawRect(
        rect,
        Paint()
          ..color = config.colorMode.bgColor.withValues(alpha: (1.0 - config.photoBgOpacity).clamp(0.45, 0.99)),
      );
    }

    // 3. Cached GPU-baked ASCII texture (0.05ms single blit, zero per-frame Paragraph lag!)
    final ui.Image img = renderData.rasterImage;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    // 4. Optional CRT Horizontal Scanline Overlay
    if (config.crtScanlines && config.scanlineOpacity > 0.01) {
      final Paint scanPaint = Paint()
        ..color = Colors.black.withValues(alpha: config.scanlineOpacity.clamp(0.0, 0.6))
        ..strokeWidth = 1.25;

      const double step = 4.0;
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AsciiArtPainter oldDelegate) {
    return oldDelegate.renderData != renderData ||
        oldDelegate.originalImage != originalImage ||
        oldDelegate.config.colorMode != config.colorMode ||
        oldDelegate.config.crtScanlines != config.crtScanlines ||
        oldDelegate.config.scanlineOpacity != config.scanlineOpacity ||
        oldDelegate.config.photoBgOpacity != config.photoBgOpacity ||
        oldDelegate.isPeekingOriginal != isPeekingOriginal;
  }
}

