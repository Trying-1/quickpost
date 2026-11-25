import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../utils/font_selector.dart';
import '../../../../widgets/warped_text.dart';
import '../models/text_post_overlays.dart';
import '../services/text_post_color_matrix.dart';

/// Interactive preview canvas for TextPostScreen, rendering the background
/// color/image, mask overlay, bottom/top shape patches, main text layer,
/// extra text layers, and image sticker overlays.
class TextPostPreviewCanvas extends StatelessWidget {
  final GlobalKey previewKey;
  final double aspectRatio;
  final bool isExporting;
  final bool isTabContentExpanded;

  // Background & color adjustments
  final Color backgroundColor;
  final bool bgUseGradient;
  final Color bgColor2;
  final double bgGradientAngle;
  final double canvasPadding;
  final File? bgImage;
  final TransformationController transformationController;
  final double brightness;
  final double saturation;
  final double hue;

  // Mask settings
  final int maskType;
  final Color maskColor;
  final double maskOpacity;
  final double maskStart;
  final double maskEnd;

  // Main text settings
  final String text;
  final FontInfo? selectedFont;
  final Color textColor;
  final double fontSize;
  final double textScale;
  final double lineHeight;
  final double letterSpacing;
  final TextAlign textAlign;
  final Alignment textPosition;
  final bool enableTextShadow;
  final Color shadowColor;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double shadowBlurRadius;
  final bool enableTextGlow;
  final Color glowColor;
  final double glowRadius;
  final bool showMainBox;
  final Color mainBoxColor;
  final double mainBoxOpacity;
  final double mainBoxRadius;
  final String warpType;
  final double warpIntensity;
  final double textOpacity;
  final double textRotation;
  final bool textFill;
  final bool showStroke;
  final Color strokeColor;
  final double strokeWidth;

  // Snap guides
  final bool showSnapGuideX;
  final bool showSnapGuideY;

  // Overlays & selection state
  final List<TextPostOverlayPatch> patches;
  final int? selectedPatchIndex;
  final List<TextPostOverlayImage> imageOverlays;
  final int? selectedImageOverlayIndex;
  final List<TextPostTextOverlay> textOverlays;
  final int selectedTextIndex;

  // Callbacks
  final VoidCallback onBackgroundTap;
  final VoidCallback onMainTextPanStart;
  final ValueChanged<Alignment> onMainTextPanUpdate;
  final VoidCallback onMainTextTap;
  final void Function(bool snapX, bool snapY) onSnapGuidesChanged;
  final void Function(int index, double x, double y) onPatchPanUpdate;
  final ValueChanged<int> onPatchTap;
  final ValueChanged<int> onImageOverlayPanStart;
  final void Function(int index, double x, double y) onImageOverlayPanUpdate;
  final ValueChanged<int> onImageOverlayTap;
  final ValueChanged<int> onTextOverlayPanStart;
  final void Function(int index, double x, double y) onTextOverlayPanUpdate;
  final ValueChanged<int> onTextOverlayTap;

  const TextPostPreviewCanvas({
    super.key,
    required this.previewKey,
    required this.aspectRatio,
    required this.isExporting,
    required this.isTabContentExpanded,
    required this.backgroundColor,
    this.bgUseGradient = false,
    this.bgColor2 = const Color(0xFF1E3C72),
    this.bgGradientAngle = 135.0,
    this.canvasPadding = 16.0,
    required this.bgImage,
    required this.transformationController,
    required this.brightness,
    required this.saturation,
    required this.hue,
    required this.maskType,
    required this.maskColor,
    required this.maskOpacity,
    required this.maskStart,
    required this.maskEnd,
    required this.text,
    required this.selectedFont,
    required this.textColor,
    required this.fontSize,
    required this.textScale,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textAlign,
    required this.textPosition,
    required this.enableTextShadow,
    required this.shadowColor,
    required this.shadowOffsetX,
    required this.shadowOffsetY,
    required this.shadowBlurRadius,
    required this.enableTextGlow,
    required this.glowColor,
    required this.glowRadius,
    required this.showMainBox,
    required this.mainBoxColor,
    required this.mainBoxOpacity,
    required this.mainBoxRadius,
    required this.warpType,
    required this.warpIntensity,
    this.textOpacity = 1.0,
    this.textRotation = 0.0,
    this.textFill = true,
    this.showStroke = false,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.showSnapGuideX = false,
    this.showSnapGuideY = false,
    required this.patches,
    required this.selectedPatchIndex,
    required this.imageOverlays,
    required this.selectedImageOverlayIndex,
    required this.textOverlays,
    required this.selectedTextIndex,
    required this.onBackgroundTap,
    required this.onMainTextPanStart,
    required this.onMainTextPanUpdate,
    required this.onMainTextTap,
    required this.onSnapGuidesChanged,
    required this.onPatchPanUpdate,
    required this.onPatchTap,
    required this.onImageOverlayPanStart,
    required this.onImageOverlayPanUpdate,
    required this.onImageOverlayTap,
    required this.onTextOverlayPanStart,
    required this.onTextOverlayPanUpdate,
    required this.onTextOverlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: boxConstraints.maxHeight,
                    maxWidth: boxConstraints.maxWidth,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildPreviewSection(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final String previewText = text.isEmpty ? 'Your text here' : text;

    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final rad = bgGradientAngle * math.pi / 180.0;
        final dxGrad = math.cos(rad);
        final dyGrad = math.sin(rad);
        final double scaledMargin =
            canvasPadding * (constraints.maxWidth / 400.0);

        return Container(
          decoration: bgUseGradient
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-dxGrad, -dyGrad),
                    end: Alignment(dxGrad, dyGrad),
                    colors: [backgroundColor, bgColor2],
                  ),
                )
              : BoxDecoration(color: backgroundColor),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!isExporting)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onBackgroundTap,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              if (bgImage != null)
                InteractiveViewer(
                  transformationController: transformationController,
                  clipBehavior: Clip.none,
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: ColorFiltered(
                    colorFilter: ui.ColorFilter.matrix(
                      buildTextPostColorMatrix(brightness, saturation, hue),
                    ),
                    child: bgImage != null && bgImage!.existsSync()
                        ? Image.file(bgImage!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey,
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),
                  ),
                ),
              if (maskType != 0) _buildMaskOverlay(),

              // Patches (Bottom Layer)
              ...patches.asMap().entries.where((e) => !e.value.isTop).map(
                    (entry) =>
                        _buildPatchPreview(entry.value, entry.key, constraints),
                  ),

              // Main Text Layer
              Padding(
                padding: EdgeInsets.all(scaledMargin),
                child: Align(
                  alignment: textPosition,
                  child: GestureDetector(
                    onPanStart: isExporting ? null : (_) => onMainTextPanStart(),
                    onPanUpdate: isExporting
                        ? null
                        : (details) {
                            final double dx =
                                (details.delta.dx / constraints.maxWidth) * 2;
                            final double dy =
                                (details.delta.dy / constraints.maxHeight) * 2;
                            final double rawX =
                                (textPosition.x + dx).clamp(-1.0, 1.0);
                            final double rawY =
                                (textPosition.y + dy).clamp(-1.0, 1.0);
                            final bool snapX = rawX.abs() < 0.05;
                            final bool snapY = rawY.abs() < 0.05;
                            onSnapGuidesChanged(snapX, snapY);
                            onMainTextPanUpdate(
                              Alignment(
                                snapX ? 0.0 : rawX,
                                snapY ? 0.0 : rawY,
                              ),
                            );
                          },
                    onPanEnd: isExporting
                        ? null
                        : (_) => onSnapGuidesChanged(false, false),
                    onPanCancel: isExporting
                        ? null
                        : () => onSnapGuidesChanged(false, false),
                    onTap: onMainTextTap,
                    child: Transform.rotate(
                      angle: textRotation * (math.pi / 180.0),
                      child: Opacity(
                        opacity: textOpacity.clamp(0.0, 1.0),
                        child: _buildSelectionWrapper(
                          isSelected: !isExporting &&
                              selectedTextIndex == -1 &&
                              isTabContentExpanded,
                          color: Colors.blueAccent,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: showMainBox
                                    ? mainBoxColor
                                        .withValues(alpha: mainBoxOpacity)
                                    : null,
                                borderRadius:
                                    BorderRadius.circular(mainBoxRadius),
                              ),
                              child: _buildTextWidget(
                                textValue: previewText,
                                font: selectedFont,
                                color: textColor,
                                resolvedFontSize: 24 * fontSize * textScale,
                                letterSpacing: letterSpacing,
                                lineHeight: lineHeight,
                                align: textAlign,
                                showShadow: enableTextShadow,
                                shadowColor: shadowColor,
                                shadowOffsetX: shadowOffsetX,
                                shadowOffsetY: shadowOffsetY,
                                shadowBlur: shadowBlurRadius,
                                showGlow: enableTextGlow,
                                glowColor: glowColor,
                                glowRadius: glowRadius,
                                textFill: textFill,
                                showStroke: showStroke,
                                strokeColor: strokeColor,
                                strokeWidth: strokeWidth,
                                warpType: warpType,
                                warpIntensity: warpIntensity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Patches (Top Layer)
              ...patches.asMap().entries.where((e) => e.value.isTop).map(
                    (entry) =>
                        _buildPatchPreview(entry.value, entry.key, constraints),
                  ),

              // Extra Text Overlays
              ...textOverlays.asMap().entries.map(
                    (entry) => _buildTextOverlayPreview(
                      entry.value,
                      entry.key,
                      constraints,
                    ),
                  ),

              // Image Overlays
              ...imageOverlays.asMap().entries.map(
                    (entry) => _buildImageOverlayPreview(
                      entry.value,
                      entry.key,
                      constraints,
                    ),
                  ),

              // Center Snap Guides (only visible while dragging & snapped)
              if (!isExporting && showSnapGuideX)
                Positioned(
                  left: constraints.maxWidth / 2 - 0.5,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 1,
                      color: Colors.cyanAccent.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              if (!isExporting && showSnapGuideY)
                Positioned(
                  top: constraints.maxHeight / 2 - 0.5,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      color: Colors.cyanAccent.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: RepaintBoundary(
        key: previewKey,
        child: Material(
          type: MaterialType.transparency,
          child: content,
        ),
      ),
    );
  }

  Widget _buildTextWidget({
    required String textValue,
    required FontInfo? font,
    required Color color,
    required double resolvedFontSize,
    required double letterSpacing,
    required double lineHeight,
    required TextAlign align,
    required bool showShadow,
    required Color shadowColor,
    required double shadowOffsetX,
    required double shadowOffsetY,
    required double shadowBlur,
    required bool showGlow,
    required Color glowColor,
    required double glowRadius,
    required bool textFill,
    required bool showStroke,
    required Color strokeColor,
    required double strokeWidth,
    required String warpType,
    required double warpIntensity,
  }) {
    final shadows = <Shadow>[
      if (showShadow)
        Shadow(
          color: shadowColor.withValues(alpha: 0.7),
          offset: Offset(shadowOffsetX, shadowOffsetY),
          blurRadius: shadowBlur,
        ),
      if (showGlow)
        Shadow(
          color: glowColor.withValues(alpha: 0.9),
          offset: Offset.zero,
          blurRadius: glowRadius,
        ),
    ];

    final resolvedFillColor = textFill ? color : Colors.transparent;
    final style = TextStyle(
      fontFamily: font?.family,
      fontWeight: font?.weight ?? FontWeight.normal,
      fontStyle: font?.style ?? FontStyle.normal,
      color: resolvedFillColor,
      fontSize: resolvedFontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );

    if (warpType != 'none') {
      return WarpedTextWidget(
        text: textValue,
        style: style,
        warpType: warpType,
        warpIntensity: warpIntensity,
        defaultColor: resolvedFillColor,
      );
    }

    if ((showStroke || !textFill) && strokeWidth > 0) {
      final strokeStyle = TextStyle(
        fontFamily: font?.family,
        fontWeight: font?.weight ?? FontWeight.normal,
        fontStyle: font?.style ?? FontStyle.normal,
        fontSize: resolvedFontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = strokeColor,
      );
      return Stack(
        alignment: Alignment.center,
        children: [
          Text(textValue, textAlign: align, style: strokeStyle),
          Text(textValue, textAlign: align, style: style),
        ],
      );
    }

    return Text(
      textValue,
      textAlign: align,
      style: style,
    );
  }

  Widget _buildMaskOverlay() {
    Alignment begin = Alignment.topCenter;
    Alignment end = Alignment.bottomCenter;

    switch (maskType) {
      case 1:
        begin = Alignment.topCenter;
        end = Alignment.bottomCenter;
        break;
      case 2:
        begin = Alignment.bottomCenter;
        end = Alignment.topCenter;
        break;
      case 3:
        return Container(color: maskColor.withValues(alpha: maskOpacity));
      case 4:
        begin = Alignment.centerRight;
        end = Alignment.centerLeft;
        break;
      case 5:
        begin = Alignment.centerLeft;
        end = Alignment.centerRight;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            maskColor.withValues(alpha: 0.0),
            maskColor.withValues(alpha: maskOpacity),
          ],
          stops: [maskStart, maskEnd],
        ),
      ),
    );
  }

  Widget _buildPatchPreview(
    TextPostOverlayPatch p,
    int idx,
    BoxConstraints constraints,
  ) {
    final isSelected = !isExporting && selectedPatchIndex == idx;
    return Positioned(
      left: p.x * constraints.maxWidth,
      top: p.y * constraints.maxHeight,
      width: p.width * constraints.maxWidth,
      height: p.height * constraints.maxHeight,
      child: GestureDetector(
        onPanUpdate: (d) {
          final nextX = (p.x + d.delta.dx / constraints.maxWidth)
              .clamp(0.0, 1.0 - p.width);
          final nextY = (p.y + d.delta.dy / constraints.maxHeight)
              .clamp(0.0, 1.0 - p.height);
          onPatchPanUpdate(idx, nextX, nextY);
        },
        onTap: () => onPatchTap(idx),
        child: _buildSelectionWrapper(
          isSelected: isSelected,
          color: Colors.blueAccent,
          child: Container(
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: p.opacity),
              borderRadius: BorderRadius.circular(
                p.radius * (constraints.maxWidth / 1000),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageOverlayPreview(
    TextPostOverlayImage img,
    int idx,
    BoxConstraints constraints,
  ) {
    final isSelected = !isExporting && selectedImageOverlayIndex == idx;
    final file = File(img.path);
    if (!file.existsSync()) return const SizedBox.shrink();

    final overlayW = constraints.maxWidth * img.scale;
    return Positioned(
      left: img.x * constraints.maxWidth,
      top: img.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: (_) => onImageOverlayPanStart(idx),
          onPanUpdate: (d) {
            final rawX =
                (img.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            final rawY =
                (img.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
            final snapX = (rawX - 0.5).abs() < 0.025;
            final snapY = (rawY - 0.5).abs() < 0.025;
            onSnapGuidesChanged(snapX, snapY);
            onImageOverlayPanUpdate(
              idx,
              snapX ? 0.5 : rawX,
              snapY ? 0.5 : rawY,
            );
          },
          onPanEnd: (_) => onSnapGuidesChanged(false, false),
          onPanCancel: () => onSnapGuidesChanged(false, false),
          onTap: () => onImageOverlayTap(idx),
          child: _buildSelectionWrapper(
            isSelected: isSelected,
            color: Colors.blueAccent,
            child: Transform.rotate(
              angle: img.rotation * (math.pi / 180),
              child: Opacity(
                opacity: img.opacity,
                child: Image.file(
                  file,
                  width: overlayW,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlayPreview(
    TextPostTextOverlay t,
    int idx,
    BoxConstraints constraints,
  ) {
    final isSelected = !isExporting && selectedTextIndex == idx;

    return Positioned(
      left: t.x * constraints.maxWidth,
      top: t.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: (_) => onTextOverlayPanStart(idx),
          onPanUpdate: (d) {
            final rawX =
                (t.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            final rawY =
                (t.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
            final snapX = (rawX - 0.5).abs() < 0.025;
            final snapY = (rawY - 0.5).abs() < 0.025;
            onSnapGuidesChanged(snapX, snapY);
            onTextOverlayPanUpdate(
              idx,
              snapX ? 0.5 : rawX,
              snapY ? 0.5 : rawY,
            );
          },
          onPanEnd: (_) => onSnapGuidesChanged(false, false),
          onPanCancel: () => onSnapGuidesChanged(false, false),
          onTap: () => onTextOverlayTap(idx),
          child: Transform.rotate(
            angle: t.rotation * (math.pi / 180.0),
            child: Opacity(
              opacity: t.opacity.clamp(0.0, 1.0),
              child: _buildSelectionWrapper(
                isSelected: isSelected,
                color: Colors.blueAccent,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.92 * t.scale,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.showBox
                        ? t.boxColor.withValues(alpha: t.boxOpacity)
                        : null,
                    borderRadius: BorderRadius.circular(t.boxRadius),
                  ),
                  child: _buildTextWidget(
                    textValue: t.text,
                    font: t.font,
                    color: t.color,
                    resolvedFontSize: t.fontSize * t.scale,
                    letterSpacing: t.letterSpacing,
                    lineHeight: t.lineHeight,
                    align: t.textAlign,
                    showShadow: t.showShadow,
                    shadowColor: t.shadowColor,
                    shadowOffsetX: t.shadowOffsetX,
                    shadowOffsetY: t.shadowOffsetY,
                    shadowBlur: t.shadowBlur,
                    showGlow: t.showGlow,
                    glowColor: t.glowColor,
                    glowRadius: t.glowRadius,
                    textFill: t.textFill,
                    showStroke: t.showStroke,
                    strokeColor: t.strokeColor,
                    strokeWidth: t.strokeWidth,
                    warpType: t.warpType,
                    warpIntensity: t.warpIntensity,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionWrapper({
    required Widget child,
    required bool isSelected,
    required Color color,
  }) {
    if (!isSelected) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: child,
        ),
        Positioned(top: -4, left: -4, child: _buildHandle(color)),
        Positioned(top: -4, right: -4, child: _buildHandle(color)),
        Positioned(bottom: -4, left: -4, child: _buildHandle(color)),
        Positioned(bottom: -4, right: -4, child: _buildHandle(color)),
      ],
    );
  }

  Widget _buildHandle(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

