import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/pixel_art_model.dart';

/// Proportional, zero-overflow retro pixel art canvas renderer.
/// Supports crisp square pixels, LCD matrix, LED diode boards, circular pegboard beads,
/// interactive Before/After split wipe comparison, CRT shaders, HUD badges, and 7 retro frames.
class PixelArtCanvasView extends StatelessWidget {
  final GlobalKey? boundaryKey;
  final ui.Image? pixelImage;
  final Uint8List? rgbaBytes;
  final ui.Image? originalImage;
  final int gridCols;
  final int gridRows;
  final PixelArtConfig config;
  final VoidCallback? onHoldCompareStart;
  final VoidCallback? onHoldCompareEnd;

  const PixelArtCanvasView({
    super.key,
    this.boundaryKey,
    required this.pixelImage,
    required this.rgbaBytes,
    required this.originalImage,
    required this.gridCols,
    required this.gridRows,
    required this.config,
    this.onHoldCompareStart,
    this.onHoldCompareEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (pixelImage == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final double imgRatio = (config.aspectRatio.ratio ?? (gridCols / gridRows)).clamp(0.45, 2.2);
    const double refWidth = 360.0;

    return FittedBox(
      fit: BoxFit.contain,
      child: RepaintBoundary(
        key: boundaryKey,
        child: GestureDetector(
          onLongPressStart: onHoldCompareStart != null ? (_) => onHoldCompareStart!() : null,
          onLongPressEnd: onHoldCompareEnd != null ? (_) => onHoldCompareEnd!() : null,
          child: SizedBox(
            width: refWidth,
            child: _buildFramedCanvas(refWidth, imgRatio),
          ),
        ),
      ),
    );
  }

  Widget _buildPixelViewport(double aspectRatio) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PixelArtPainter(
              pixelImage: pixelImage!,
              rgbaBytes: rgbaBytes,
              originalImage: originalImage,
              cols: gridCols,
              rows: gridRows,
              config: config,
            ),
          ),
          if (config.hudBadge != PixelHudBadge.none && config.compareMode != CompareViewMode.fullOriginal)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  border: Border.all(
                    color: _badgeAccentColor(config.hudBadge),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  config.hudBadge.badgeText,
                  style: TextStyle(
                    color: _badgeAccentColor(config.hudBadge),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _badgeAccentColor(PixelHudBadge badge) {
    switch (badge) {
      case PixelHudBadge.recLive:
        return const Color(0xFFFF3B30);
      case PixelHudBadge.hpHearts:
        return const Color(0xFF4ADE80);
      case PixelHudBadge.levelUp:
        return const Color(0xFFFACC15);
      case PixelHudBadge.saveSlot:
        return const Color(0xFF38BDF8);
      case PixelHudBadge.none:
        return Colors.white;
    }
  }

  Widget _buildFramedCanvas(double width, double imgRatio) {
    switch (config.frameStyle) {
      case PixelFrameStyle.frameless:
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _buildPixelViewport(imgRatio),
        );

      case PixelFrameStyle.gameBoyShell:
        return _buildGameBoyShell(width, imgRatio);

      case PixelFrameStyle.arcadeCrt:
        return _buildArcadeCrt(width, imgRatio);

      case PixelFrameStyle.retroWin95:
        return _buildRetroWin95(width, imgRatio);

      case PixelFrameStyle.rpgDialogBox:
        return _buildRpgDialogBox(width, imgRatio);

      case PixelFrameStyle.polaroid8Bit:
        return _buildPolaroid8Bit(width, imgRatio);

      case PixelFrameStyle.cartridgeCard:
        return _buildCartridgeCard(width, imgRatio);
    }
  }

  /// Classic 1989 Game Boy DMG-01 LCD bezel & handheld shell.
  Widget _buildGameBoyShell(double width, double imgRatio) {
    const double outerPad = 18.0;
    const double lensPadX = 24.0;
    const double lensPadTop = 26.0;
    const double lensPadBottom = 16.0;

    return Container(
      width: width,
      padding: const EdgeInsets.all(outerPad),
      decoration: BoxDecoration(
        color: const Color(0xFFD5D3C8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(42),
        ),
        border: Border.all(color: const Color(0xFFB3B0A2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(lensPadX, lensPadTop, lensPadX, lensPadBottom),
            decoration: const BoxDecoration(
              color: Color(0xFF565A66),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(height: 2, color: const Color(0xFF7E2B57)),
                          const SizedBox(height: 2),
                          Container(height: 2, color: const Color(0xFF28346F)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'DOT MATRIX WITH STEREO SOUND',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 6.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 18,
                      child: Column(
                        children: [
                          Container(height: 2, color: const Color(0xFF7E2B57)),
                          const SizedBox(height: 2),
                          Container(height: 2, color: const Color(0xFF28346F)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2E2E),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2E2E).withValues(alpha: 0.8),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'BATT',
                            style: TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 5.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF2D3138), width: 2.5),
                        ),
                        child: _buildPixelViewport(imgRatio),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'QUICKBOY',
                    style: TextStyle(
                      color: Color(0xFF28346F),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'TM',
                    style: TextStyle(
                      color: Color(0xFF28346F),
                      fontSize: 6.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildConsoleButton('B'),
                  const SizedBox(width: 8),
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: _buildConsoleButton('A'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleButton(String label) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF9E1F58),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(1, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF3E8EE),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Glowing 1980s Arcade CRT Cabinet monitor frame.
  Widget _buildArcadeCrt(double width, double imgRatio) {
    const double bezelPad = 18.0;

    return Container(
      width: width,
      padding: const EdgeInsets.all(bezelPad),
      decoration: BoxDecoration(
        color: const Color(0xFF10111A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '1UP  08420',
                  style: TextStyle(
                    color: Color(0xFFFF2A85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'HI-SCORE  99990',
                  style: TextStyle(
                    color: const Color(0xFF00F5D4).withValues(alpha: 0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2B2E42), width: 4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildPixelViewport(imgRatio),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            config.customTitleText.isNotEmpty && config.customTitleText != 'NOSTALGIA_1989.BMP'
                ? config.customTitleText.toUpperCase()
                : 'INSERT COIN TO CONTINUE  •  CREDIT 01',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// Authentic 1995 Windows 95 beveled desktop application frame.
  Widget _buildRetroWin95(double width, double imgRatio) {
    const double pad = 5.0;

    return Container(
      width: width,
      padding: const EdgeInsets.all(pad),
      decoration: const BoxDecoration(
        color: Color(0xFFC0C0C0),
        border: Border(
          top: BorderSide(color: Colors.white, width: 2),
          left: BorderSide(color: Colors.white, width: 2),
          right: BorderSide(color: Color(0xFF404040), width: 2.5),
          bottom: BorderSide(color: Color(0xFF404040), width: 2.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000080), Color(0xFF1084D0)],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_on_rounded, color: Colors.white, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    config.customTitleText.isNotEmpty
                        ? config.customTitleText
                        : 'pixel_art_studio.bmp - Paint95',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                _buildWin95Btn('_'),
                const SizedBox(width: 2),
                _buildWin95Btn('□'),
                const SizedBox(width: 2),
                _buildWin95Btn('×'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF606060), width: 2),
                left: BorderSide(color: Color(0xFF606060), width: 2),
                right: BorderSide(color: Colors.white, width: 2),
                bottom: BorderSide(color: Colors.white, width: 2),
              ),
            ),
            child: _buildPixelViewport(imgRatio),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildWin95StatusBox('${config.palette.label} • ${gridCols}x$gridRows px'),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 1,
                child: _buildWin95StatusBox(config.ditherAlgorithm.label),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWin95Btn(String char) {
    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFC0C0C0),
        border: Border(
          top: BorderSide(color: Colors.white, width: 1.5),
          left: BorderSide(color: Colors.white, width: 1.5),
          right: BorderSide(color: Color(0xFF404040), width: 1.5),
          bottom: BorderSide(color: Color(0xFF404040), width: 1.5),
        ),
      ),
      child: Text(
        char,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildWin95StatusBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFC0C0C0),
        border: Border(
          top: BorderSide(color: Color(0xFF808080), width: 1.5),
          left: BorderSide(color: Color(0xFF808080), width: 1.5),
          right: BorderSide(color: Colors.white, width: 1.5),
          bottom: BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 8.5,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  /// Retro 8-Bit JRPG Dialogue Box scene frame.
  Widget _buildRpgDialogBox(double width, double imgRatio) {
    return Container(
      width: width,
      color: const Color(0xFF0A0D18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPixelViewport(imgRatio),
          Container(
            width: width,
            padding: const EdgeInsets.all(6),
            color: const Color(0xFF0B1026),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1026),
                border: Border.all(color: Colors.white, width: 2.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.rpgSpeakerName.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: const Color(0xFF2563EB),
                      child: Text(
                        config.rpgSpeakerName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          config.rpgDialogueText.isEmpty
                              ? 'A wild pixel memory appeared!'
                              : config.rpgDialogueText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '▼',
                        style: TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Classic retro instant film card with bottom caption & pixel metadata.
  Widget _buildPolaroid8Bit(double width, double imgRatio) {
    const double pad = 16.0;

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(pad, pad, pad, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2DDD5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
              border: Border.all(color: const Color(0xFF1E293B), width: 2),
            ),
            child: _buildPixelViewport(imgRatio),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  config.customTitleText.isEmpty ? 'PIXEL MEMORIES • 1989' : config.customTitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: const Color(0xFF00796B),
                child: Text(
                  '${gridCols}x$gridRows',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Retro Collectible Game Cartridge / Stat Card Frame.
  Widget _buildCartridgeCard(double width, double imgRatio) {
    const double pad = 14.0;

    return Container(
      width: width,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFACC15), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Ribbon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  config.customTitleText.isEmpty ? '8-BIT EDITION CARD' : config.customTitleText.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LVL 99',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFDE047), width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _buildPixelViewport(imgRatio),
            ),
          ),
          const SizedBox(height: 10),
          // Retro RPG Stat Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF312E81),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6366F1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  config.palette.label.toUpperCase().split(' ').first,
                  style: const TextStyle(
                    color: Color(0xFFC7D2FE),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'RES ${gridCols}x$gridRows  •  STR 99',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering square, LCD subpixel, LED board, or circular pegboard dots,
/// optional Before/After split wipe curtain, grid lines, CRT scanlines, and CRT vignette.
class _PixelArtPainter extends CustomPainter {
  final ui.Image pixelImage;
  final Uint8List? rgbaBytes;
  final ui.Image? originalImage;
  final int cols;
  final int rows;
  final PixelArtConfig config;

  _PixelArtPainter({
    required this.pixelImage,
    required this.rgbaBytes,
    required this.originalImage,
    required this.cols,
    required this.rows,
    required this.config,
  });

  void _drawOriginalCropped(Canvas canvas, Size size) {
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
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _drawPixelLayer(Canvas canvas, Size size) {
    final Rect dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Base Pixel Rendering by Block Shape
    if (config.blockShape == PixelBlockShape.square || rgbaBytes == null || rgbaBytes!.length < cols * rows * 4) {
      final Rect srcPixelRect = Rect.fromLTWH(
        0,
        0,
        pixelImage.width.toDouble(),
        pixelImage.height.toDouble(),
      );
      canvas.drawImageRect(
        pixelImage,
        srcPixelRect,
        dstRect,
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false,
      );
    } else {
      // Draw dark bezel backing
      canvas.drawRect(
        dstRect,
        Paint()..color = const Color(0xFF0B0D12),
      );

      final double cellW = size.width / cols;
      final double cellH = size.height / rows;
      final Uint8List bytes = rgbaBytes!;
      final Paint cellPaint = Paint()..isAntiAlias = config.blockShape == PixelBlockShape.pegboard;

      if (config.blockShape == PixelBlockShape.lcdMatrix) {
        final double gapX = (cellW * 0.14).clamp(0.4, 2.0);
        final double gapY = (cellH * 0.14).clamp(0.4, 2.0);
        for (int y = 0; y < rows; y++) {
          final double top = y * cellH + gapY * 0.5;
          final double h = math.max(0.5, cellH - gapY);
          for (int x = 0; x < cols; x++) {
            final int i = (y * cols + x) * 4;
            cellPaint.color = Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
            canvas.drawRect(
              Rect.fromLTWH(x * cellW + gapX * 0.5, top, math.max(0.5, cellW - gapX), h),
              cellPaint,
            );
          }
        }
      } else if (config.blockShape == PixelBlockShape.ledBoard) {
        final double pad = (math.min(cellW, cellH) * 0.16).clamp(0.5, 2.2);
        final Radius corner = Radius.circular((math.min(cellW, cellH) * 0.25).clamp(0.5, 4.0));
        for (int y = 0; y < rows; y++) {
          final double top = y * cellH + pad;
          final double h = math.max(0.8, cellH - pad * 2);
          for (int x = 0; x < cols; x++) {
            final int i = (y * cols + x) * 4;
            cellPaint.color = Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x * cellW + pad, top, math.max(0.8, cellW - pad * 2), h),
                corner,
              ),
              cellPaint,
            );
          }
        }
      } else {
        // Pegboard / Perler circular beads
        final double radius = (math.min(cellW, cellH) * 0.43).clamp(0.6, 20.0);
        for (int y = 0; y < rows; y++) {
          final double cy = y * cellH + cellH * 0.5;
          for (int x = 0; x < cols; x++) {
            final int i = (y * cols + x) * 4;
            cellPaint.color = Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
            canvas.drawCircle(Offset(x * cellW + cellW * 0.5, cy), radius, cellPaint);
          }
        }
      }
    }

    // 2. Optional crisp Pixel Matrix Grid Lines
    if (config.showPixelGrid && cols <= 104 && config.blockShape == PixelBlockShape.square) {
      final double cellW = size.width / cols;
      final double cellH = size.height / rows;
      final Paint gridPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = 0.75;

      for (int c = 1; c < cols; c++) {
        final double x = c * cellW;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (int r = 1; r < rows; r++) {
        final double y = r * cellH;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 3. Optional CRT Horizontal Scanline Shader Overlay
    if (config.crtScanlines && config.scanlineOpacity > 0.01) {
      final Paint scanPaint = Paint()
        ..color = Colors.black.withValues(alpha: config.scanlineOpacity.clamp(0.0, 0.7))
        ..strokeWidth = 1.25;

      const double step = 3.5;
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
      }
    }

    // 4. Optional CRT Corner Vignette
    if (config.crtVignette) {
      final Paint vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2),
          math.max(size.width, size.height) * 0.72,
          [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
          const [0.55, 1.0],
        );
      canvas.drawRect(dstRect, vignettePaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (config.compareMode == CompareViewMode.fullOriginal && originalImage != null) {
      _drawOriginalCropped(canvas, size);
      return;
    }

    if (config.compareMode == CompareViewMode.splitWipe && originalImage != null) {
      final double splitX = (size.width * config.compareSplit.clamp(0.05, 0.95));

      // Left side: Original photo
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, splitX, size.height));
      _drawOriginalCropped(canvas, size);
      canvas.restore();

      // Right side: Retro Pixel Art
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(splitX, 0, size.width - splitX, size.height));
      _drawPixelLayer(canvas, size);
      canvas.restore();

      // Divider Line & Handle
      final Paint linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(splitX, 0), Offset(splitX, size.height), linePaint);

      canvas.drawCircle(
        Offset(splitX, size.height / 2),
        10,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(splitX, size.height / 2),
        7,
        Paint()..color = const Color(0xFF00796B),
      );
      return;
    }

    _drawPixelLayer(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainter oldDelegate) {
    return oldDelegate.pixelImage != pixelImage ||
        oldDelegate.rgbaBytes != rgbaBytes ||
        oldDelegate.originalImage != originalImage ||
        oldDelegate.cols != cols ||
        oldDelegate.rows != rows ||
        oldDelegate.config.blockShape != config.blockShape ||
        oldDelegate.config.showPixelGrid != config.showPixelGrid ||
        oldDelegate.config.crtScanlines != config.crtScanlines ||
        oldDelegate.config.scanlineOpacity != config.scanlineOpacity ||
        oldDelegate.config.crtVignette != config.crtVignette ||
        oldDelegate.config.compareMode != config.compareMode ||
        oldDelegate.config.compareSplit != config.compareSplit ||
        oldDelegate.config.hudBadge != config.hudBadge;
  }
}
