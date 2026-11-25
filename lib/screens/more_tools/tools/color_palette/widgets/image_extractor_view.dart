import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:quickpost/config/app_theme.dart';
import '../models/color_palette_item.dart';
import '../models/palette_color.dart';
import '../services/color_extractor_service.dart';

/// Interactive view allowing creators to pick images, extract dominant palettes,
/// and use a live touch magnifying loupe / eyedropper to sample any pixel.
class ImageExtractorView extends StatefulWidget {
  final File? imageFile;
  final ValueChanged<ColorPaletteItem> onPaletteExtracted;
  final ValueChanged<PaletteColor> onColorSampled;
  final VoidCallback onPickNewImage;

  const ImageExtractorView({
    super.key,
    required this.imageFile,
    required this.onPaletteExtracted,
    required this.onColorSampled,
    required this.onPickNewImage,
  });

  @override
  State<ImageExtractorView> createState() => _ImageExtractorViewState();
}

class _ImageExtractorViewState extends State<ImageExtractorView> {
  img.Image? _decodedImage;
  bool _isProcessing = false;
  ColorPaletteItem? _extractedPalette;

  // Eyedropper / Loupe touch state
  Offset? _touchPosition;
  Color? _sampledColor;
  Size _imageRenderSize = Size.zero;

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      _processImage(widget.imageFile!);
    }
  }

  @override
  void didUpdateWidget(covariant ImageExtractorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageFile != null && widget.imageFile?.path != oldWidget.imageFile?.path) {
      _processImage(widget.imageFile!);
    }
  }

  Future<void> _processImage(File file) async {
    setState(() {
      _isProcessing = true;
      _touchPosition = null;
      _sampledColor = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      final palette = await ColorExtractorService().extractPaletteFromImage(file);

      if (mounted) {
        setState(() {
          _decodedImage = decoded;
          _extractedPalette = palette;
          _isProcessing = false;
        });

        if (palette != null) {
          widget.onPaletteExtracted(palette);
        }
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleTouch(Offset localPos) {
    if (_decodedImage == null || _imageRenderSize.width <= 0 || _imageRenderSize.height <= 0) return;

    final nx = (localPos.dx / _imageRenderSize.width).clamp(0.0, 1.0);
    final ny = (localPos.dy / _imageRenderSize.height).clamp(0.0, 1.0);

    final color = ColorExtractorService().sampleNormalizedPixel(_decodedImage!, nx, ny);

    setState(() {
      _touchPosition = localPos;
      _sampledColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageFile == null) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top action bar with Change Image button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.colorize_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Interactive Eyedropper',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: widget.onPickNewImage,
                icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppColors.primary),
                label: const Text('Change Photo', style: TextStyle(color: AppColors.primary, fontSize: 13, fontFamily: 'Poppins')),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primarySurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Interactive Photo Canvas with Magnifying Loupe
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isProcessing
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                        SizedBox(height: 14),
                        Text('Extracting vibrant colors...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Poppins')),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      _imageRenderSize = Size(constraints.maxWidth, constraints.maxHeight);

                      return GestureDetector(
                        onPanDown: (d) => _handleTouch(d.localPosition),
                        onPanUpdate: (d) => _handleTouch(d.localPosition),
                        onTapUp: (d) {
                          _handleTouch(d.localPosition);
                          if (_sampledColor != null) {
                            widget.onColorSampled(PaletteColor(
                              color: _sampledColor!,
                              name: PaletteColor.findNearestName(_sampledColor!),
                              role: 'Eyedropper Pick',
                            ));
                          }
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                widget.imageFile!,
                                fit: BoxFit.cover,
                              ),
                            ),

                            // Touch instruction overlay when not touching
                            if (_touchPosition == null)
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.touch_app_rounded, color: Color(0xFF00E5FF), size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Drag on photo to sample exact colors',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Magnifying Loupe Overlay
                            if (_touchPosition != null && _sampledColor != null)
                              Positioned(
                                left: (_touchPosition!.dx - 45).clamp(10.0, _imageRenderSize.width - 100),
                                top: (_touchPosition!.dy - 95).clamp(10.0, _imageRenderSize.height - 100),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _sampledColor,
                                    border: Border.all(color: Colors.white, width: 3.5),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _sampledColor!.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '#${_sampledColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                                        style: TextStyle(
                                          color: _sampledColor!.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // Live Sampled Color Action Bar (if active)
          if (_sampledColor != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _sampledColor!.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _sampledColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PaletteColor.findNearestName(_sampledColor!),
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                        ),
                        Text(
                          '#${_sampledColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                          style: const TextStyle(color: AppColors.primary, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onColorSampled(PaletteColor(
                        color: _sampledColor!,
                        name: PaletteColor.findNearestName(_sampledColor!),
                        role: 'Sampled Eyedropper',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added sampled color to active palette!'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add to Palette', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Extracted Swatches Summary Card
          if (_extractedPalette != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Extracted Dominant Palette',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                ),
                TextButton(
                  onPressed: () => widget.onPaletteExtracted(_extractedPalette!),
                  child: const Text('Apply All to Studio', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Swatch Preview Row
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: _extractedPalette!.colors.map((c) {
                  return Expanded(
                    child: Tooltip(
                      message: '${c.name} (${c.hexCode})',
                      child: Container(
                        height: 52,
                        color: c.color,
                        alignment: Alignment.center,
                        child: Text(
                          c.hexCode.substring(1),
                          style: TextStyle(
                            color: c.onColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Extract Palette from Photo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select any image from your gallery to automatically extract its dominant, vibrant, and neutral harmonic colors.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onPickNewImage,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Pick Image from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

