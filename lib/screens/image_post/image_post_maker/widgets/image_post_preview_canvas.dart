import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../utils/font_selector.dart';
import '../models/image_post_overlays.dart';
import 'wire_frame_painter.dart';

/// Interactive preview canvas for ImagePostMakerScreen: renders canvas background
/// (image + filters or solid color), bottom/top shape patches, main photo,
/// gradient mask, text layers/split words, sticker overlays, and all watermark modes.
class ImagePostPreviewCanvas extends StatelessWidget {
  final GlobalKey repaintKey;
  final File? selectedImage;
  final File? bgImage;
  final File? profileImage;

  // Canvas & main image transform/frame
  final bool fullScreen;
  final double imageAspectRatio;
  final String bgColor;
  final double bgBrightness;
  final double bgSaturation;
  final double bgBlur;
  final double videoRadius;
  final double videoBorderWidth;
  final String videoBorderColor;
  final double videoScale;
  final double videoX;
  final double videoY;
  final bool showVideoShadow;
  final String videoShadowColor;
  final double videoShadowBlur;
  final double videoShadowSpread;
  final double videoShadowOffsetX;
  final double videoShadowOffsetY;

  // Mask
  final int maskType;
  final Color maskColor;
  final double maskOpacity;
  final double maskStart;
  final double maskEnd;

  // Watermark & profile styling
  final String watermarkType;
  final double watermarkX;
  final double watermarkY;
  final double watermarkScale;
  final bool showBox;
  final String boxColor;
  final double boxOpacity;
  final double boxRadius;
  final double fontSize;
  final double iconSize;
  final String textColor;
  final String accentColor;
  final String username;
  final String handle;
  final FontInfo? selectedUsernameFont;
  final FontInfo? selectedHandleFont;
  final double usernameSize;
  final double handleSize;
  final double usernameOpacity;
  final double handleOpacity;
  final bool showStoryRing;
  final bool isCustomRingColor;
  final String storyRingColor;
  final double storyRingWidth;
  final bool isVerified;
  final String verifiedBadgeColor;
  final String verifiedBadgeAttachTo;

  // Watermark shadows
  final bool showUsernameShadow;
  final String usernameShadowColor;
  final double usernameShadowBlur;
  final double usernameShadowOffsetX;
  final double usernameShadowOffsetY;
  final bool showHandleShadow;
  final String handleShadowColor;
  final double handleShadowBlur;
  final double handleShadowOffsetX;
  final double handleShadowOffsetY;
  final bool showIconShadow;
  final String iconShadowColor;
  final double iconShadowBlur;
  final double iconShadowOffsetX;
  final double iconShadowOffsetY;

  // Wireframe mode
  final double wireRadius;
  final double wireWidth;
  final String wireColor;
  final bool wireCutout;
  final bool wireCutoutDots;
  final double wireInset;
  final String wireTextPosition;
  final double wireGap;

  // Overlays & selection
  final List<ImagePostPatch> patches;
  final int selectedPatchIndex;
  final List<ImagePostTextOverlay> textOverlays;
  final Set<int> selectedTextOverlayIndices;
  final List<ImagePostOverlayImage> imageOverlays;
  final int selectedImageOverlayIndex;
  final int selectedTabIndex;
  final bool multiSelectMode;

  // Callbacks
  final VoidCallback onPickImage;
  final VoidCallback onCanvasTap;
  final void Function(double x, double y) onWatermarkPanUpdate;
  final void Function(int idx, double x, double y) onPatchPanUpdate;
  final ValueChanged<int> onPatchTap;
  final ValueChanged<int> onImageOverlayPanStart;
  final void Function(int idx, double x, double y) onImageOverlayPanUpdate;
  final ValueChanged<int> onImageOverlayTap;
  final ValueChanged<int> onTextOverlayPanStart;
  final void Function(double dx, double dy) onSelectedTextOverlaysPanUpdate;
  final ValueChanged<int> onTextOverlayTap;

  const ImagePostPreviewCanvas({
    super.key,
    required this.repaintKey,
    required this.selectedImage,
    required this.bgImage,
    required this.profileImage,
    required this.fullScreen,
    required this.imageAspectRatio,
    required this.bgColor,
    required this.bgBrightness,
    required this.bgSaturation,
    required this.bgBlur,
    required this.videoRadius,
    required this.videoBorderWidth,
    required this.videoBorderColor,
    required this.videoScale,
    required this.videoX,
    required this.videoY,
    required this.showVideoShadow,
    required this.videoShadowColor,
    required this.videoShadowBlur,
    required this.videoShadowSpread,
    required this.videoShadowOffsetX,
    required this.videoShadowOffsetY,
    required this.maskType,
    required this.maskColor,
    required this.maskOpacity,
    required this.maskStart,
    required this.maskEnd,
    required this.watermarkType,
    required this.watermarkX,
    required this.watermarkY,
    required this.watermarkScale,
    required this.showBox,
    required this.boxColor,
    required this.boxOpacity,
    required this.boxRadius,
    required this.fontSize,
    required this.iconSize,
    required this.textColor,
    required this.accentColor,
    required this.username,
    required this.handle,
    required this.selectedUsernameFont,
    required this.selectedHandleFont,
    required this.usernameSize,
    required this.handleSize,
    required this.usernameOpacity,
    required this.handleOpacity,
    required this.showStoryRing,
    required this.isCustomRingColor,
    required this.storyRingColor,
    required this.storyRingWidth,
    required this.isVerified,
    required this.verifiedBadgeColor,
    required this.verifiedBadgeAttachTo,
    required this.showUsernameShadow,
    required this.usernameShadowColor,
    required this.usernameShadowBlur,
    required this.usernameShadowOffsetX,
    required this.usernameShadowOffsetY,
    required this.showHandleShadow,
    required this.handleShadowColor,
    required this.handleShadowBlur,
    required this.handleShadowOffsetX,
    required this.handleShadowOffsetY,
    required this.showIconShadow,
    required this.iconShadowColor,
    required this.iconShadowBlur,
    required this.iconShadowOffsetX,
    required this.iconShadowOffsetY,
    required this.wireRadius,
    required this.wireWidth,
    required this.wireColor,
    required this.wireCutout,
    required this.wireCutoutDots,
    required this.wireInset,
    required this.wireTextPosition,
    required this.wireGap,
    required this.patches,
    required this.selectedPatchIndex,
    required this.textOverlays,
    required this.selectedTextOverlayIndices,
    required this.imageOverlays,
    required this.selectedImageOverlayIndex,
    required this.selectedTabIndex,
    required this.multiSelectMode,
    required this.onPickImage,
    required this.onCanvasTap,
    required this.onWatermarkPanUpdate,
    required this.onPatchPanUpdate,
    required this.onPatchTap,
    required this.onImageOverlayPanStart,
    required this.onImageOverlayPanUpdate,
    required this.onImageOverlayTap,
    required this.onTextOverlayPanStart,
    required this.onSelectedTextOverlaysPanUpdate,
    required this.onTextOverlayTap,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No background image selected',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Background Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final outAspect = fullScreen ? 9 / 16 : imageAspectRatio;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: parseImagePostColor(bgColor),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: RepaintBoundary(
              key: repaintKey,
              child: AspectRatio(
                aspectRatio: outAspect,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double unscaledW;
                    final double unscaledH;
                    if (constraints.maxWidth / imageAspectRatio <=
                        constraints.maxHeight) {
                      unscaledW = constraints.maxWidth;
                      unscaledH = constraints.maxWidth / imageAspectRatio;
                    } else {
                      unscaledH = constraints.maxHeight;
                      unscaledW = constraints.maxHeight * imageAspectRatio;
                    }
                    final double scaledW = unscaledW * videoScale;
                    final double scaledH = unscaledH * videoScale;
                    final double videoOffsetDx =
                        (videoX - 0.5) * (constraints.maxWidth - scaledW);
                    final double videoOffsetDy =
                        (videoY - 0.5) * (constraints.maxHeight - scaledH);

                    return GestureDetector(
                      onTap: onCanvasTap,
                      onPanUpdate: (d) => onWatermarkPanUpdate(
                        (d.localPosition.dx / constraints.maxWidth)
                            .clamp(0.0, 1.0),
                        (d.localPosition.dy / constraints.maxHeight)
                            .clamp(0.0, 1.0),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (bgImage != null)
                            Positioned.fill(
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: bgBlur / 5,
                                  sigmaY: bgBlur / 5,
                                ),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.matrix([
                                    0.213 + 0.787 * bgSaturation,
                                    0.715 - 0.715 * bgSaturation,
                                    0.072 - 0.072 * bgSaturation,
                                    0,
                                    0,
                                    0.213 - 0.213 * bgSaturation,
                                    0.715 + 0.285 * bgSaturation,
                                    0.072 - 0.072 * bgSaturation,
                                    0,
                                    0,
                                    0.213 - 0.213 * bgSaturation,
                                    0.715 - 0.715 * bgSaturation,
                                    0.072 + 0.928 * bgSaturation,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                  ]),
                                  child: ImageFiltered(
                                    imageFilter: ui.ColorFilter.mode(
                                      Colors.black.withValues(
                                        alpha:
                                            (1.0 - bgBrightness).clamp(0.0, 1.0),
                                      ),
                                      BlendMode.darken,
                                    ),
                                    child: Image.file(
                                      bgImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (bgImage == null)
                            Positioned.fill(
                              child: ColoredBox(
                                color: parseImagePostColor(bgColor),
                              ),
                            ),

                          // Patches (Bottom Layer)
                          ...patches
                              .asMap()
                              .entries
                              .where((e) => !e.value.isTop)
                              .map(
                                (entry) => _buildPatchPreview(
                                  entry.value,
                                  entry.key,
                                  constraints,
                                ),
                              ),

                          // Main Overlay Image
                          Center(
                            child: Transform.translate(
                              offset: Offset(videoOffsetDx, videoOffsetDy),
                              child: Transform.scale(
                                scale: videoScale,
                                child: Container(
                                  width: unscaledW,
                                  height: unscaledH,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(videoRadius),
                                    border: videoBorderWidth > 0
                                        ? Border.all(
                                            color: parseImagePostColor(
                                              videoBorderColor,
                                            ),
                                            width: videoBorderWidth,
                                          )
                                        : null,
                                    boxShadow: showVideoShadow
                                        ? [
                                            BoxShadow(
                                              color: parseImagePostColor(
                                                videoShadowColor,
                                              ),
                                              blurRadius: videoShadowBlur,
                                              offset: Offset(
                                                videoShadowOffsetX,
                                                videoShadowOffsetY,
                                              ),
                                              spreadRadius: videoShadowSpread,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(videoRadius),
                                    child: AspectRatio(
                                      aspectRatio: imageAspectRatio,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.file(
                                              selectedImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (watermarkType == 'wire')
                                            Positioned.fill(
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, videoConstraints) {
                                                  final double previewScale =
                                                      videoConstraints.maxWidth /
                                                          1080.0 *
                                                          watermarkScale;
                                                  return _buildWatermarkPreview(
                                                    previewScale,
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (maskType != 0) _buildMaskOverlay(),

                          // Patches (Top Layer)
                          ...patches
                              .asMap()
                              .entries
                              .where((e) => e.value.isTop)
                              .map(
                                (entry) => _buildPatchPreview(
                                  entry.value,
                                  entry.key,
                                  constraints,
                                ),
                              ),

                          // Text Overlays
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

                          // Standard Watermark Overlay
                          if (watermarkType != 'wire')
                            Positioned(
                              left: watermarkX * constraints.maxWidth,
                              top: watermarkY * constraints.maxHeight,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: _buildWatermarkPreview(
                                  constraints.maxWidth /
                                      1080.0 *
                                      watermarkScale,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaskOverlay() {
    if (maskType == 0) return const SizedBox.shrink();

    Alignment? begin;
    Alignment? end;
    if (maskType == 1) {
      begin = Alignment.topCenter;
      end = Alignment.bottomCenter;
    } else if (maskType == 2) {
      begin = Alignment.bottomCenter;
      end = Alignment.topCenter;
    } else if (maskType == 4) {
      begin = Alignment.centerRight;
      end = Alignment.centerLeft;
    } else if (maskType == 5) {
      begin = Alignment.centerLeft;
      end = Alignment.centerRight;
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color:
                maskType == 3 ? maskColor.withValues(alpha: maskOpacity) : null,
            gradient: (begin != null && end != null)
                ? LinearGradient(
                    begin: begin,
                    end: end,
                    colors: [
                      Colors.transparent,
                      maskColor.withValues(alpha: maskOpacity),
                    ],
                    stops: [
                      maskStart.clamp(0.0, 1.0),
                      maskEnd.clamp(0.0, 1.0),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildPatchPreview(
    ImagePostPatch p,
    int idx,
    BoxConstraints constraints,
  ) {
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
        child: Container(
          decoration: BoxDecoration(
            color: parseImagePostColor(p.color).withValues(alpha: p.opacity),
            borderRadius: BorderRadius.circular(
              p.radius * (constraints.maxWidth / 1080.0),
            ),
            border: selectedPatchIndex == idx
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildImageOverlayPreview(
    ImagePostOverlayImage img,
    int idx,
    BoxConstraints constraints,
  ) {
    final isSelected =
        selectedImageOverlayIndex == idx && selectedTabIndex == 9;
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
          onPanUpdate: (d) => onImageOverlayPanUpdate(
            idx,
            (img.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0),
            (img.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0),
          ),
          onTap: () => onImageOverlayTap(idx),
          child: Transform.rotate(
            angle: img.rotation * (math.pi / 180),
            child: Opacity(
              opacity: img.opacity,
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.deepPurple, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
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
    ImagePostTextOverlay t,
    int idx,
    BoxConstraints constraints,
  ) {
    final isSelected =
        selectedTextOverlayIndices.contains(idx) && selectedTabIndex == 8;

    return Positioned(
      left: t.x * constraints.maxWidth,
      top: t.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: t.isLocked ? null : (_) => onTextOverlayPanStart(idx),
          onPanUpdate: t.isLocked
              ? null
              : (d) => onSelectedTextOverlaysPanUpdate(
                    d.delta.dx / constraints.maxWidth,
                    d.delta.dy / constraints.maxHeight,
                  ),
          onTap: () => onTextOverlayTap(idx),
          child: Opacity(
            opacity: t.opacity,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.92 * t.scale,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: t.styleSegments != null && t.styleSegments!.isNotEmpty
                  ? Text.rich(
                      TextSpan(
                        children: t.styleSegments!
                            .map(
                              (seg) => TextSpan(
                                text: '${seg.text} ',
                                style: TextStyle(
                                  color: parseImagePostColor(seg.color),
                                  fontFamily: seg.font?.family,
                                  fontWeight: seg.font?.weight,
                                  fontStyle: seg.font?.style,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      textAlign: t.textAlign,
                      style: TextStyle(
                        fontSize:
                            t.fontSize * (constraints.maxWidth / 1080.0) * t.scale,
                        height: t.lineHeight,
                        letterSpacing: t.letterSpacing,
                        wordSpacing: t.wordSpacing,
                        shadows: t.showShadow
                            ? [
                                Shadow(
                                  color: parseImagePostColor(t.shadowColor),
                                  blurRadius: t.shadowBlur,
                                  offset: Offset(
                                    t.shadowOffsetX,
                                    t.shadowOffsetY,
                                  ),
                                ),
                              ]
                            : null,
                      ),
                    )
                  : Text(
                      t.text,
                      textAlign: t.textAlign,
                      style: TextStyle(
                        color: parseImagePostColor(t.color),
                        fontSize:
                            t.fontSize * (constraints.maxWidth / 1080.0) * t.scale,
                        fontFamily: t.font?.family,
                        height: t.lineHeight,
                        letterSpacing: t.letterSpacing,
                        wordSpacing: t.wordSpacing,
                        shadows: t.showShadow
                            ? [
                                Shadow(
                                  color: parseImagePostColor(t.shadowColor),
                                  blurRadius: t.shadowBlur,
                                  offset: Offset(
                                    t.shadowOffsetX,
                                    t.shadowOffsetY,
                                  ),
                                ),
                              ]
                            : null,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatermarkPreview(double scale) {
    if (!showBox || watermarkType == 'wire') {
      return _buildWatermarkContent(scale);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: parseImagePostColor(boxColor).withValues(alpha: boxOpacity),
        borderRadius: BorderRadius.circular(boxRadius * scale),
      ),
      child: _buildWatermarkContent(scale),
    );
  }

  Widget _buildProfileAvatar(double scale) {
    return Container(
      padding: showStoryRing ? EdgeInsets.all(storyRingWidth * scale) : EdgeInsets.zero,
      decoration: showStoryRing
          ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCustomRingColor
                  ? null
                  : const SweepGradient(
                      colors: [
                        Color(0xFFFCAF45),
                        Color(0xFFF56040),
                        Color(0xFFE1306C),
                        Color(0xFFC13584),
                        Color(0xFFFCAF45),
                      ],
                    ),
              color: isCustomRingColor
                  ? parseImagePostColor(storyRingColor)
                  : null,
            )
          : null,
      child: Container(
        decoration: showIconShadow
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: parseImagePostColor(iconShadowColor),
                    blurRadius: iconShadowBlur * scale,
                    offset: Offset(
                      iconShadowOffsetX * scale,
                      iconShadowOffsetY * scale,
                    ),
                  ),
                ],
              )
            : null,
        child: CircleAvatar(
          radius: (iconSize * scale) / 2,
          backgroundColor: Colors.grey.shade400,
          backgroundImage: profileImage != null ? FileImage(profileImage!) : null,
          child: profileImage == null
              ? Icon(Icons.person, size: iconSize * scale * 0.6, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildWatermarkContent(double scale) {
    if (watermarkType == 'none') return const SizedBox.shrink();

    switch (watermarkType) {
      case 'profile_vertical':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileAvatar(scale),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        color: parseImagePostColorWithAlpha(
                          textColor,
                          usernameOpacity,
                        ),
                        fontWeight: FontWeight.bold,
                        fontSize: usernameSize * scale,
                        fontFamily: selectedUsernameFont?.family,
                        shadows: _usernameShadows(scale),
                      ),
                    ),
                    if (isVerified && verifiedBadgeAttachTo == 'username') ...[
                      const SizedBox(width: 4),
                      _buildVerifiedBadgeWidget(scale),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      handle,
                      style: TextStyle(
                        color: parseImagePostColorWithAlpha(
                          accentColor,
                          handleOpacity,
                        ),
                        fontSize: handleSize * scale,
                        fontFamily: selectedHandleFont?.family,
                        shadows: _handleShadows(scale),
                      ),
                    ),
                    if (isVerified && verifiedBadgeAttachTo == 'handle') ...[
                      const SizedBox(width: 4),
                      _buildVerifiedBadgeWidget(scale),
                    ],
                  ],
                ),
              ],
            ),
          ],
        );

      case 'profile':
      case 'profile_dots':
        final isSocial = watermarkType == 'profile_dots';
        return SizedBox(
          width: isSocial ? (1080 * scale) : null,
          child: Row(
            mainAxisSize: isSocial ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: isSocial
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileAvatar(scale),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                              color: parseImagePostColorWithAlpha(
                                textColor,
                                usernameOpacity,
                              ),
                              fontWeight:
                                  selectedUsernameFont?.weight ?? FontWeight.bold,
                              fontStyle:
                                  selectedUsernameFont?.style ?? FontStyle.normal,
                              fontSize: usernameSize * scale,
                              fontFamily: selectedUsernameFont?.family,
                              shadows: _usernameShadows(scale),
                            ),
                          ),
                          if (isVerified &&
                              verifiedBadgeAttachTo == 'username') ...[
                            const SizedBox(width: 6),
                            _buildVerifiedBadgeWidget(scale),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            handle,
                            style: TextStyle(
                              color: parseImagePostColorWithAlpha(
                                accentColor,
                                handleOpacity,
                              ),
                              fontWeight: selectedHandleFont?.weight ??
                                  selectedUsernameFont?.weight ??
                                  FontWeight.normal,
                              fontStyle: selectedHandleFont?.style ??
                                  selectedUsernameFont?.style ??
                                  FontStyle.normal,
                              fontSize: handleSize * scale,
                              fontFamily: selectedHandleFont?.family ??
                                  selectedUsernameFont?.family,
                              shadows: _handleShadows(scale),
                            ),
                          ),
                          if (isVerified && verifiedBadgeAttachTo == 'handle') ...[
                            const SizedBox(width: 6),
                            _buildVerifiedBadgeWidget(scale),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (isSocial)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: fontSize * 0.2 * scale,
                    right: 12 * scale,
                  ),
                  child: Icon(
                    Icons.more_horiz,
                    color: parseImagePostColorWithAlpha(
                      accentColor,
                      handleOpacity,
                    ),
                    size: fontSize * 1.2 * scale,
                  ),
                ),
            ],
          ),
        );

      case 'text':
        return Text(
          username,
          style: TextStyle(
            color: parseImagePostColorWithAlpha(textColor, usernameOpacity),
            fontWeight: FontWeight.bold,
            fontSize: usernameSize * scale,
            fontFamily: selectedUsernameFont?.family,
            shadows: _usernameShadows(scale),
          ),
        );

      case 'wire':
        return _buildWireWatermark(scale);

      case 'image':
        return profileImage != null
            ? Image.file(
                profileImage!,
                width: iconSize * scale,
                height: iconSize * scale,
                fit: BoxFit.contain,
              )
            : Icon(
                Icons.image,
                size: iconSize * scale,
                color: Colors.grey.shade400,
              );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWireWatermark(double scale) {
    final double inset = wireInset * scale;
    final textPainter = TextPainter(
      text: TextSpan(
        text: username,
        style: TextStyle(
          fontWeight: selectedUsernameFont?.weight ?? FontWeight.bold,
          fontStyle: selectedUsernameFont?.style ?? FontStyle.normal,
          fontSize: usernameSize * scale,
          fontFamily: selectedUsernameFont?.family,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double textWidth = textPainter.width;

    final rawText = Text(
      username,
      style: TextStyle(
        color: parseImagePostColorWithAlpha(textColor, usernameOpacity),
        fontWeight: selectedUsernameFont?.weight ?? FontWeight.bold,
        fontStyle: selectedUsernameFont?.style ?? FontStyle.normal,
        fontSize: usernameSize * scale,
        fontFamily: selectedUsernameFont?.family,
        shadows: _usernameShadows(scale),
      ),
    );

    final textWidget = showBox
        ? Container(
            padding:
                EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
            decoration: BoxDecoration(
              color: parseImagePostColor(boxColor).withValues(alpha: boxOpacity),
              borderRadius: BorderRadius.circular(boxRadius * scale),
            ),
            child: rawText,
          )
        : rawText;

    final double edgeOffset = showBox
        ? (inset - (usernameSize * scale / 2.0) - (6 * scale))
        : (wireCutout
            ? (inset - (usernameSize * scale / 2.0))
            : (inset + (8 * scale)));

    return Stack(
      children: [
        Positioned(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: CustomPaint(
            painter: WireFramePainter(
              radius: wireRadius,
              width: wireWidth,
              color: parseImagePostColorWithAlpha(wireColor, handleOpacity),
              textWidth: textWidth,
              scale: scale,
              hasCutout: wireCutout,
              hasCutoutDots: wireCutoutDots,
              textPosition: wireTextPosition,
              wireGap: wireGap,
            ),
          ),
        ),
        if (wireTextPosition == 'bottom')
          Positioned(
            left: 0,
            right: 0,
            bottom: edgeOffset,
            child: Center(child: textWidget),
          )
        else if (wireTextPosition == 'top')
          Positioned(
            left: 0,
            right: 0,
            top: edgeOffset,
            child: Center(child: textWidget),
          )
        else if (wireTextPosition == 'left')
          Positioned(
            top: 0,
            bottom: 0,
            left: edgeOffset,
            child: Center(
              child: RotatedBox(quarterTurns: 1, child: textWidget),
            ),
          )
        else
          Positioned(
            top: 0,
            bottom: 0,
            right: edgeOffset,
            child: Center(
              child: RotatedBox(quarterTurns: 1, child: textWidget),
            ),
          ),
      ],
    );
  }

  List<Shadow>? _usernameShadows(double scale) {
    if (!showUsernameShadow) return null;
    return [
      Shadow(
        color: parseImagePostColor(usernameShadowColor),
        blurRadius: usernameShadowBlur * scale,
        offset: Offset(
          usernameShadowOffsetX * scale,
          usernameShadowOffsetY * scale,
        ),
      ),
    ];
  }

  List<Shadow>? _handleShadows(double scale) {
    if (!showHandleShadow) return null;
    return [
      Shadow(
        color: parseImagePostColor(handleShadowColor),
        blurRadius: handleShadowBlur * scale,
        offset: Offset(
          handleShadowOffsetX * scale,
          handleShadowOffsetY * scale,
        ),
      ),
    ];
  }

  Widget _buildVerifiedBadgeWidget(double scale) {
    return Icon(
      Icons.verified,
      color: parseImagePostColor(verifiedBadgeColor),
      size: usernameSize * 0.8 * scale * 0.9,
    );
  }
}

