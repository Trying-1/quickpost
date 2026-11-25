import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quickpost/utils/watermark_settings.dart';

import '../../../../utils/font_selector.dart';

/// Interactive canvas rendering the Quote Card post, background filters, and identity bar.
class QuoteCardPreviewCanvas extends StatelessWidget {
  final GlobalKey previewKey;
  final double aspectRatio;
  final bool handleOnly;
  final bool isBulkMode;
  final List<Map<String, String>> bulkQuotes;
  final int currentBulkIndex;
  final ValueChanged<int> onBulkIndexChanged;

  final String quoteText;
  final String authorText;
  final String displayNameText;
  final String usernameText;

  final FontInfo? quoteFont;
  final FontInfo? authorFont;
  final FontInfo? displayNameFont;
  final FontInfo? handleFont;

  final Color backgroundColor;
  final Color textColor;
  final Color authorColor;
  final Color displayNameColor;
  final Color usernameColor;

  final bool enableQuoteShadow;
  final Color quoteShadowColor;
  final double quoteShadowOffsetX;
  final double quoteShadowOffsetY;
  final double quoteShadowBlur;
  final bool enableQuoteGlow;
  final Color quoteGlowColor;
  final double quoteGlowRadius;

  final bool enableAuthorShadow;
  final Color authorShadowColor;
  final double authorShadowOffsetX;
  final double authorShadowOffsetY;
  final double authorShadowBlur;
  final bool enableAuthorGlow;
  final Color authorGlowColor;
  final double authorGlowRadius;

  final TextAlign textAlign;
  final double fontSizeMultiplier;
  final double lineHeight;
  final double letterSpacing;

  final Alignment textPosition;
  final Alignment identityPosition;
  final ValueChanged<Alignment> onTextPositionChanged;
  final ValueChanged<Alignment> onIdentityPositionChanged;

  final File? profileImage;
  final File? backgroundImage;
  final BoxFit backgroundFit;
  final Offset backgroundOffset;
  final double backgroundScale;
  final double backgroundBlur;
  final double backgroundBrightness;
  final double backgroundSaturation;
  final ValueChanged<Offset> onBackgroundOffsetChanged;

  const QuoteCardPreviewCanvas({
    super.key,
    required this.previewKey,
    required this.aspectRatio,
    required this.handleOnly,
    required this.isBulkMode,
    required this.bulkQuotes,
    required this.currentBulkIndex,
    required this.onBulkIndexChanged,
    required this.quoteText,
    required this.authorText,
    required this.displayNameText,
    required this.usernameText,
    required this.quoteFont,
    required this.authorFont,
    required this.displayNameFont,
    required this.handleFont,
    required this.backgroundColor,
    required this.textColor,
    required this.authorColor,
    required this.displayNameColor,
    required this.usernameColor,
    required this.enableQuoteShadow,
    required this.quoteShadowColor,
    required this.quoteShadowOffsetX,
    required this.quoteShadowOffsetY,
    required this.quoteShadowBlur,
    required this.enableQuoteGlow,
    required this.quoteGlowColor,
    required this.quoteGlowRadius,
    required this.enableAuthorShadow,
    required this.authorShadowColor,
    required this.authorShadowOffsetX,
    required this.authorShadowOffsetY,
    required this.authorShadowBlur,
    required this.enableAuthorGlow,
    required this.authorGlowColor,
    required this.authorGlowRadius,
    required this.textAlign,
    required this.fontSizeMultiplier,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textPosition,
    required this.identityPosition,
    required this.onTextPositionChanged,
    required this.onIdentityPositionChanged,
    required this.profileImage,
    required this.backgroundImage,
    required this.backgroundFit,
    required this.backgroundOffset,
    required this.backgroundScale,
    required this.backgroundBlur,
    required this.backgroundBrightness,
    required this.backgroundSaturation,
    required this.onBackgroundOffsetChanged,
  });

  Color get _watermarkColor {
    final double luminance = backgroundColor.computeLuminance();
    return luminance > 0.5
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);
  }

  @override
  Widget build(BuildContext context) {
    final String previewQuote;
    final String previewAuthor;

    if (isBulkMode && bulkQuotes.isNotEmpty) {
      final idx = currentBulkIndex.clamp(0, bulkQuotes.length - 1);
      previewQuote = bulkQuotes[idx]['quote'] ?? '';
      previewAuthor = bulkQuotes[idx]['author'] ?? '';
    } else {
      previewQuote = quoteText.isEmpty ? 'Write your quote here' : quoteText;
      previewAuthor = authorText;
    }

    return Column(
      children: [
        if (isBulkMode && bulkQuotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: currentBulkIndex > 0
                      ? () => onBulkIndexChanged(currentBulkIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Post ${currentBulkIndex + 1} of ${bulkQuotes.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: currentBulkIndex < bulkQuotes.length - 1
                      ? () => onBulkIndexChanged(currentBulkIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: RepaintBoundary(
            key: previewKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  color: backgroundColor,
                  child: Stack(
                    children: [
                      if (backgroundImage != null)
                        Positioned.fill(
                          child: GestureDetector(
                            onPanUpdate: (details) =>
                                onBackgroundOffsetChanged(
                                    backgroundOffset + details.delta),
                            child: ClipRect(
                              child: Transform.translate(
                                offset: backgroundOffset,
                                child: Transform.scale(
                                  scale: backgroundScale,
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix([
                                      0.2126 + 0.7874 * backgroundSaturation,
                                      0.7152 - 0.7152 * backgroundSaturation,
                                      0.0722 - 0.0722 * backgroundSaturation,
                                      0,
                                      0,
                                      0.2126 - 0.2126 * backgroundSaturation,
                                      0.7152 + 0.2848 * backgroundSaturation,
                                      0.0722 - 0.0722 * backgroundSaturation,
                                      0,
                                      0,
                                      0.2126 - 0.2126 * backgroundSaturation,
                                      0.7152 - 0.7152 * backgroundSaturation,
                                      0.0722 + 0.9278 * backgroundSaturation,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.matrix([
                                        backgroundBrightness,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        backgroundBrightness,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        backgroundBrightness,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ]),
                                      child: ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: backgroundBlur,
                                          sigmaY: backgroundBlur,
                                        ),
                                        child: Image.file(
                                          backgroundImage!,
                                          fit: backgroundFit,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Draggable quote & author block.
                      Positioned(
                        left: (constraints.maxWidth / 2) +
                            (textPosition.x * constraints.maxWidth / 2),
                        top: (constraints.maxHeight / 2) +
                            (textPosition.y * constraints.maxHeight / 2),
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              final newX = textPosition.x +
                                  (details.delta.dx /
                                      (constraints.maxWidth / 2));
                              final newY = textPosition.y +
                                  (details.delta.dy /
                                      (constraints.maxHeight / 2));
                              onTextPositionChanged(
                                Alignment(
                                  newX.clamp(-1.0, 1.0),
                                  newY.clamp(-1.0, 1.0),
                                ),
                              );
                            },
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.85,
                              ),
                              padding: const EdgeInsets.all(8),
                              color: Colors.transparent,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    previewQuote,
                                    textAlign: textAlign,
                                    style: TextStyle(
                                      fontFamily: quoteFont?.family,
                                      fontWeight:
                                          quoteFont?.weight ?? FontWeight.w600,
                                      fontStyle:
                                          quoteFont?.style ?? FontStyle.normal,
                                      color: textColor,
                                      fontSize: 30 * fontSizeMultiplier,
                                      height: lineHeight,
                                      letterSpacing: letterSpacing,
                                      shadows: [
                                        if (enableQuoteShadow)
                                          Shadow(
                                            color: quoteShadowColor,
                                            offset: Offset(
                                              quoteShadowOffsetX,
                                              quoteShadowOffsetY,
                                            ),
                                            blurRadius: quoteShadowBlur,
                                          ),
                                        if (enableQuoteGlow)
                                          Shadow(
                                            color: quoteGlowColor,
                                            offset: Offset.zero,
                                            blurRadius: quoteGlowRadius,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (previewAuthor.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '- $previewAuthor',
                                      textAlign: textAlign,
                                      style: TextStyle(
                                        fontFamily: authorFont?.family,
                                        fontWeight: authorFont?.weight ??
                                            FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        color: authorColor,
                                        fontSize: 16 * fontSizeMultiplier,
                                        shadows: [
                                          if (enableAuthorShadow)
                                            Shadow(
                                              color: authorShadowColor,
                                              offset: Offset(
                                                authorShadowOffsetX,
                                                authorShadowOffsetY,
                                              ),
                                              blurRadius: authorShadowBlur,
                                            ),
                                          if (enableAuthorGlow)
                                            Shadow(
                                              color: authorGlowColor,
                                              offset: Offset.zero,
                                              blurRadius: authorGlowRadius,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Draggable identity bar.
                      Positioned(
                        left: (constraints.maxWidth / 2) +
                            (identityPosition.x * constraints.maxWidth / 2),
                        top: (constraints.maxHeight / 2) +
                            (identityPosition.y * constraints.maxHeight / 2),
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              final newX = identityPosition.x +
                                  (details.delta.dx /
                                      (constraints.maxWidth / 2));
                              final newY = identityPosition.y +
                                  (details.delta.dy /
                                      (constraints.maxHeight / 2));
                              onIdentityPositionChanged(
                                Alignment(
                                  newX.clamp(-1.0, 1.0),
                                  newY.clamp(-1.0, 1.0),
                                ),
                              );
                            },
                            child: _buildIdentityBar(),
                          ),
                        ),
                      ),

                      if (WatermarkSettings.showWatermark)
                        Align(
                          alignment: const Alignment(0, 0.95),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'made in Quick Post Maker',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                                color: _watermarkColor,
                              ),
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
      ],
    );
  }

  Widget _buildIdentityBar() {
    final displayName =
        displayNameText.isEmpty ? 'Username' : displayNameText;
    final username = usernameText.isEmpty ? '@yourhandle' : usernameText;

    if (handleOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          username,
          style: TextStyle(
            fontFamily: handleFont?.family,
            fontWeight: handleFont?.weight ?? FontWeight.w500,
            fontStyle: handleFont?.style ?? FontStyle.normal,
            fontSize: 12,
            color: usernameColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final hasProfile = profileImage != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black.withValues(alpha: 0.06),
            backgroundImage: hasProfile ? FileImage(profileImage!) : null,
            child: hasProfile
                ? null
                : const Icon(Icons.person, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontFamily: displayNameFont?.family,
                  fontWeight: displayNameFont?.weight ?? FontWeight.w600,
                  fontStyle: displayNameFont?.style ?? FontStyle.normal,
                  fontSize: 12,
                  color: displayNameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                username,
                style: TextStyle(
                  fontFamily: handleFont?.family,
                  fontWeight: handleFont?.weight ?? FontWeight.w400,
                  fontStyle: handleFont?.style ?? FontStyle.normal,
                  fontSize: 10,
                  color: usernameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

