import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../utils/font_selector.dart';
import '../models/carousel_slide.dart';
import '../services/carousel_color_matrix.dart';
import 'carousel_mask_overlay.dart';

/// Interactive or export-ready canvas renderer for a single [CarouselSlide].
class CarouselSlideCanvas extends StatelessWidget {
  final CarouselSlide slide;
  final bool isExport;
  final FontInfo? defaultFont;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final double? snapLineX;
  final double? snapLineY;
  final VoidCallback onClearSelection;
  final ValueChanged<int> onTapWord;
  final void Function(int wordIndex, Offset delta, Size bounds) onDragWord;
  final void Function(Offset delta, Size bounds) onDragClassicText;
  final ValueChanged<Size> onMeasureClassicSize;

  const CarouselSlideCanvas({
    super.key,
    required this.slide,
    required this.isExport,
    required this.defaultFont,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    required this.snapLineX,
    required this.snapLineY,
    required this.onClearSelection,
    required this.onTapWord,
    required this.onDragWord,
    required this.onDragClassicText,
    required this.onMeasureClassicSize,
  });

  @override
  Widget build(BuildContext context) {
    final Widget imageWidget = slide.image != null
        ? ColorFiltered(
            colorFilter: ui.ColorFilter.matrix(
              buildCarouselColorMatrix(
                  slide.brightness, slide.saturation, slide.hue),
            ),
            child: Image.file(
              slide.image!,
              fit: BoxFit.cover,
            ),
          )
        : const SizedBox.shrink();

    final Widget content = Container(
      color: slide.bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (slide.image != null)
            isExport
                ? Center(
                    child: Transform(
                      transform: slide.transformationController.value,
                      alignment: Alignment.center,
                      child: imageWidget,
                    ),
                  )
                : InteractiveViewer(
                    transformationController: slide.transformationController,
                    clipBehavior: Clip.none,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: imageWidget,
                  ),
          if (slide.maskType != 0) CarouselMaskOverlay(slide: slide),
          _buildCompositeTextAndCutout(),
          if (!isExport && snapLineX != null)
            IgnorePointer(
              child: Align(
                alignment: Alignment(snapLineX!, 0),
                child: Container(
                  width: 1.0,
                  color: const Color(0xFF00796B).withValues(alpha: 0.5),
                ),
              ),
            ),
          if (!isExport && snapLineY != null)
            IgnorePointer(
              child: Align(
                alignment: Alignment(0, snapLineY!),
                child: Container(
                  height: 1.0,
                  color: const Color(0xFF00796B).withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(16),
      child: RepaintBoundary(
        key: slide.previewKey,
        child: Material(
          type: MaterialType.transparency,
          child: content,
        ),
      ),
    );
  }

  Widget _buildCompositeTextAndCutout() {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        _buildTextLayer(false),
        if (slide.foregroundImage != null)
          Opacity(
            opacity: slide.fgOpacity,
            child: isExport
                ? Center(
                    child: Transform(
                      transform: slide.transformationController.value,
                      alignment: Alignment.center,
                      child: ColorFiltered(
                        colorFilter: ui.ColorFilter.matrix(
                          buildCarouselColorMatrix(
                              slide.fgBrightness, slide.fgSaturation, slide.fgHue),
                        ),
                        child: Image.file(
                          slide.foregroundImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                : IgnorePointer(
                    child: InteractiveViewer(
                      transformationController: slide.transformationController,
                      clipBehavior: Clip.none,
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: ColorFiltered(
                        colorFilter: ui.ColorFilter.matrix(
                          buildCarouselColorMatrix(
                              slide.fgBrightness, slide.fgSaturation, slide.fgHue),
                        ),
                        child: Image.file(
                          slide.foregroundImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
          ),
        IgnorePointer(
          child: slide.fgStrokeOnly && slide.foregroundImage != null
              ? ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (Rect bounds) {
                    if (slide.uiForegroundImage == null) {
                      return const LinearGradient(
                        colors: [Colors.transparent, Colors.transparent],
                      ).createShader(bounds);
                    }

                    final imageSize = Size(
                      slide.uiForegroundImage!.width.toDouble(),
                      slide.uiForegroundImage!.height.toDouble(),
                    );
                    final containerSize = bounds.size;

                    final double scale = math.max(
                      containerSize.width / imageSize.width,
                      containerSize.height / imageSize.height,
                    );
                    final double dx =
                        (containerSize.width - imageSize.width * scale) / 2.0;
                    final double dy =
                        (containerSize.height - imageSize.height * scale) / 2.0;

                    final boxFitMatrix = Matrix4.identity()
                      ..translateByDouble(dx, dy, 0.0, 1.0)
                      ..scaleByDouble(scale, scale, 1.0, 1.0);

                    final totalMatrix =
                        slide.transformationController.value.clone()
                          ..multiply(boxFitMatrix);

                    return ui.ImageShader(
                      slide.uiForegroundImage!,
                      ui.TileMode.clamp,
                      ui.TileMode.clamp,
                      totalMatrix.storage,
                    );
                  },
                  child: _buildTextLayer(true),
                )
              : _buildTextLayer(true),
        ),
      ],
    );
  }

  Widget _buildTextLayer(bool isMaskLayer) {
    if (slide.useWordMode && slide.wordTokens.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          Alignment wordsCenter = Alignment.center;
          if (slide.wordTokens.isNotEmpty) {
            double minX = slide.wordTokens.first.position.x;
            double maxX = slide.wordTokens.first.position.x;
            double minY = slide.wordTokens.first.position.y;
            double maxY = slide.wordTokens.first.position.y;
            for (final t in slide.wordTokens) {
              minX = math.min(minX, t.position.x);
              maxX = math.max(maxX, t.position.x);
              minY = math.min(minY, t.position.y);
              maxY = math.max(maxY, t.position.y);
            }
            wordsCenter = Alignment((minX + maxX) / 2, (minY + maxY) / 2);
          }

          return GestureDetector(
            onTap: isExport ? null : onClearSelection,
            behavior: HitTestBehavior.translucent,
            child: Transform.scale(
              scale: slide.textScale,
              alignment: wordsCenter,
              child: Stack(
                children: List.generate(slide.wordTokens.length, (i) {
                  final word = slide.wordTokens[i];
                  final bool isSelected =
                      !isExport && selectedWordIndices.contains(i);
                  return Align(
                    alignment: word.position,
                    child: GestureDetector(
                      onTap: isExport ? null : () => onTapWord(i),
                      onPanUpdate: isExport || slide.isLocked || isMaskLayer
                          ? null
                          : (details) => onDragWord(
                                i,
                                details.delta,
                                Size(constraints.maxWidth,
                                    constraints.maxHeight),
                              ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: isSelected && !isMaskLayer
                            ? BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Transform.rotate(
                          angle: word.rotation * math.pi / 180,
                          child: Stack(
                            children: [
                              if (word.strokeWidth > 0 &&
                                  (isMaskLayer
                                      ? word.strokeOverForeground
                                      : !word.fgStrokeOnly))
                                Text(
                                  word.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: word.fontSize,
                                    fontFamily: word.font?.family ??
                                        defaultFont?.family,
                                    fontWeight: word.font?.weight ??
                                        defaultFont?.weight ??
                                        FontWeight.bold,
                                    letterSpacing: slide.letterSpacing,
                                    wordSpacing: slide.wordSpacing,
                                    height: slide.lineHeight,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = word.strokeWidth
                                      ..color = word.strokeColor,
                                  ),
                                ),
                              if (!isMaskLayer)
                                Text(
                                  word.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: word.textFill
                                        ? word.color
                                        : Colors.transparent,
                                    fontSize: word.fontSize,
                                    fontFamily: word.font?.family ??
                                        defaultFont?.family,
                                    fontWeight: word.font?.weight ??
                                        defaultFont?.weight ??
                                        FontWeight.bold,
                                    letterSpacing: slide.letterSpacing,
                                    wordSpacing: slide.wordSpacing,
                                    height: slide.lineHeight,
                                    shadows: [
                                      if (word.enableShadow)
                                        Shadow(
                                          color: word.shadowColor,
                                          offset: word.shadowOffset,
                                          blurRadius: word.shadowBlur,
                                        ),
                                      if (word.enableGlow)
                                        Shadow(
                                          color: word.glowColor,
                                          offset: Offset.zero,
                                          blurRadius: word.glowRadius,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      );
    }

    if (slide.text.isNotEmpty && !slide.useWordMode) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (!isMaskLayer) {
            onMeasureClassicSize(
                Size(constraints.maxWidth, constraints.maxHeight));
          }
          return Align(
            alignment: slide.textAlignment,
            child: Transform.scale(
              scale: slide.textScale,
              child: GestureDetector(
                onPanUpdate: isExport || slide.isLocked || isMaskLayer
                    ? null
                    : (details) => onDragClassicText(
                          details.delta,
                          Size(constraints.maxWidth, constraints.maxHeight),
                        ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    children: [
                      if (slide.textStrokeWidth > 0 &&
                          (isMaskLayer
                              ? slide.strokeOverForeground
                              : !slide.fgStrokeOnly))
                        Text(
                          slide.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: slide.slideFontSize,
                            fontFamily:
                                slide.font?.family ?? defaultFont?.family,
                            fontWeight: slide.font?.weight ??
                                defaultFont?.weight ??
                                FontWeight.bold,
                            letterSpacing: slide.letterSpacing,
                            wordSpacing: slide.wordSpacing,
                            height: slide.lineHeight,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = slide.textStrokeWidth
                              ..color = slide.textStrokeColor,
                          ),
                        ),
                      if (!isMaskLayer)
                        Text(
                          slide.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: slide.textFill
                                ? slide.textColor
                                : Colors.transparent,
                            fontSize: slide.slideFontSize,
                            fontFamily:
                                slide.font?.family ?? defaultFont?.family,
                            fontWeight: slide.font?.weight ??
                                defaultFont?.weight ??
                                FontWeight.bold,
                            letterSpacing: slide.letterSpacing,
                            wordSpacing: slide.wordSpacing,
                            height: slide.lineHeight,
                            shadows: [
                              if (slide.enableShadow)
                                Shadow(
                                  color: slide.shadowColor,
                                  offset: slide.shadowOffset,
                                  blurRadius: slide.shadowBlur,
                                ),
                              if (slide.enableGlow)
                                Shadow(
                                  color: slide.glowColor,
                                  offset: Offset.zero,
                                  blurRadius: slide.glowRadius,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

