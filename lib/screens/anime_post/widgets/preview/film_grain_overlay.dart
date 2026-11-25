import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Singleton manager that generates and caches a 128x128 monochrome
/// micro-noise texture in GPU memory for high-performance film grain rendering.
class FilmGrainTextureManager {
  FilmGrainTextureManager._();
  static final FilmGrainTextureManager instance = FilmGrainTextureManager._();

  ui.Image? _cachedTexture;
  bool _isGenerating = false;
  final List<VoidCallback> _listeners = [];

  ui.Image? get texture => _cachedTexture;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    if (_cachedTexture == null && !_isGenerating) {
      _generateNoiseTexture();
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  void _generateNoiseTexture() {
    if (_isGenerating || _cachedTexture != null) return;
    _isGenerating = true;

    const int size = 128;
    final Uint8List pixels = Uint8List(size * size * 4);
    final random = math.Random(1337); // Seeded for consistent texture aesthetic

    int byteIdx = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        // High-contrast, fine-grained analog noise value (0-255)
        final int val = random.nextInt(256);
        pixels[byteIdx] = val; // R
        pixels[byteIdx + 1] = val; // G
        pixels[byteIdx + 2] = val; // B
        pixels[byteIdx + 3] = 255; // Alpha
        byteIdx += 4;
      }
    }

    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      (ui.Image result) {
        _cachedTexture = result;
        _isGenerating = false;
        _notifyListeners();
      },
    );
  }
}

/// Renders a hardware-accelerated 35mm analog film grain overlay across the canvas.
/// Uses Skia/Impeller ImageShader with TileMode.repeated for maximum 120 FPS performance.
class FilmGrainOverlay extends StatefulWidget {
  final double intensity; // 0.01 - 0.25 (typically ~0.04 - 0.08)
  final BlendMode blendMode;

  const FilmGrainOverlay({
    super.key,
    this.intensity = 0.05,
    this.blendMode = BlendMode.overlay,
  });

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay> {
  @override
  void initState() {
    super.initState();
    FilmGrainTextureManager.instance.addListener(_onTextureReady);
  }

  @override
  void dispose() {
    FilmGrainTextureManager.instance.removeListener(_onTextureReady);
    super.dispose();
  }

  void _onTextureReady() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0.001) return const SizedBox.shrink();

    final texture = FilmGrainTextureManager.instance.texture;

    return IgnorePointer(
      child: CustomPaint(
        painter: _FilmGrainPainter(
          texture: texture,
          intensity: widget.intensity.clamp(0.0, 0.35),
          blendMode: widget.blendMode,
        ),
      ),
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  final ui.Image? texture;
  final double intensity;
  final BlendMode blendMode;

  _FilmGrainPainter({
    required this.texture,
    required this.intensity,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (texture == null || size.isEmpty) return;

    final shader = ImageShader(
      texture!,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );

    final paint = Paint()
      ..shader = shader
      ..color = Colors.white.withValues(alpha: intensity)
      ..blendMode = blendMode;

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter oldDelegate) {
    return oldDelegate.texture != texture ||
        oldDelegate.intensity != intensity ||
        oldDelegate.blendMode != blendMode;
  }
}

/// Renders a smooth, cinematic radial edge vignette over the canvas
/// to draw focus toward the center artwork.
class VignetteOverlay extends StatelessWidget {
  final double intensity; // 0.0 to 1.0 (typically ~0.3 to 0.6)
  final Color tintColor;

  const VignetteOverlay({
    super.key,
    this.intensity = 0.35,
    this.tintColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.01) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              Colors.transparent,
              tintColor.withValues(alpha: (intensity * 0.3).clamp(0.0, 1.0)),
              tintColor.withValues(alpha: intensity.clamp(0.0, 1.0)),
            ],
            stops: const [0.55, 0.85, 1.0],
          ),
        ),
      ),
    );
  }
}

