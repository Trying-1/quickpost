import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 5: CINEMATIC LETTERBOX / 35MM FRAME
/// Anamorphic movie-still presentation featuring minimalist corner viewfinder crosshairs,
/// recording timecode, widescreen letterbox visual card, cinematic movie-subtitle captioning,
/// poster-style wide tracking title, and sleek metadata chips.
class Layout5Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF6B7280);
    final crosshairColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.14);

    final List<Widget> list = [];

    // 1. Viewfinder Corner Crop Marks (⌜ ⌝ ⌞ ⌟)
    Widget buildCornerCrosshair({bool top = true, bool left = true}) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          border: Border(
            top: top ? BorderSide(color: crosshairColor, width: 1.5) : BorderSide.none,
            bottom: !top ? BorderSide(color: crosshairColor, width: 1.5) : BorderSide.none,
            left: left ? BorderSide(color: crosshairColor, width: 1.5) : BorderSide.none,
            right: !left ? BorderSide(color: crosshairColor, width: 1.5) : BorderSide.none,
          ),
        ),
      );
    }

    list.add(
      Positioned.fill(
        child: IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Align(alignment: Alignment.topLeft, child: buildCornerCrosshair(top: true, left: true)),
                Align(alignment: Alignment.topRight, child: buildCornerCrosshair(top: true, left: false)),
                Align(alignment: Alignment.bottomLeft, child: buildCornerCrosshair(top: false, left: true)),
                Align(alignment: Alignment.bottomRight, child: buildCornerCrosshair(top: false, left: false)),
              ],
            ),
          ),
        ),
      ),
    );

    // 2. Cinematic Top Bar: Aspect Ratio Indicator & Timecode Counter
    final hookBg = theme.getEffectiveBgColor(SlideComponentId.hookTag);
    final hookRadius = theme.getBorderRadiusForComponent(SlideComponentId.hookTag, defaultRadius: 4.0);
    final hookPadding = theme.getPaddingForComponent(SlideComponentId.hookTag, defaultPadding: 4.0);
    final hookFont = theme.getFontForComponent(SlideComponentId.hookTag);
    final hookSize = theme.getFontSizeForComponent(SlideComponentId.hookTag, defaultSize: 8.5);
    final hookWeight = theme.getFontWeightForComponent(SlideComponentId.hookTag, defaultWeight: FontWeight.w800);
    final hookSpacing = theme.getLetterSpacingForComponent(SlideComponentId.hookTag, defaultSpacing: 1.4);
    final hookColor = theme.getColorForComponent(SlideComponentId.hookTag) ?? primaryTextColor;

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.hookTag,
        label: 'Cinema Tag',
        baseLeft: 22,
        baseTop: 16,
        useGroupOffset: false,
        child: context.wrapComponentBox(
          componentId: SlideComponentId.hookTag,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hookPadding + 2, vertical: hookPadding * 0.5),
            decoration: hookBg != null
                ? BoxDecoration(
                    color: hookBg,
                    borderRadius: BorderRadius.circular(hookRadius),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), // Camera recording red dot
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  (slide.coverTag.trim().isNotEmpty ? slide.coverTag : 'REC  •  2.39:1 CINEMATIC').toUpperCase(),
                  style: TextStyle(
                    fontFamily: hookFont,
                    fontSize: hookSize,
                    fontWeight: hookWeight,
                    letterSpacing: hookSpacing,
                    color: hookColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (theme.showSlideCounter) {
      final counterFont = theme.getFontForComponent(SlideComponentId.slideCounter, defaultFont: 'monospace');
      final counterSize = theme.getFontSizeForComponent(SlideComponentId.slideCounter, defaultSize: 9.0);
      final counterWeight = theme.getFontWeightForComponent(SlideComponentId.slideCounter, defaultWeight: FontWeight.w700);
      final counterColor = theme.getColorForComponent(SlideComponentId.slideCounter) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.slideCounter,
          label: 'Timecode',
          baseRight: 22,
          baseTop: 16,
          useGroupOffset: false,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.slideCounter,
            child: Text(
              'TC 00:0${context.slideIndex + 1}:24',
              style: TextStyle(
                fontSize: counterSize,
                fontWeight: counterWeight,
                fontFamily: counterFont,
                letterSpacing: 1.2,
                color: counterColor,
              ),
            ),
          ),
        ),
      );
    }

    // 3. Cinematic Widescreen Visual Letterbox Card (~16:9 ratio)
    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 1.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 12.0);
    final heroBg = theme.getEffectiveBgColor(SlideComponentId.heroVisual) ?? Colors.black;
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: true);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Widescreen Frame',
        baseLeft: 18,
        baseRight: 18,
        baseTop: 44,
        height: 195,
        child: Container(
          decoration: BoxDecoration(
            color: heroBg,
            borderRadius: BorderRadius.circular(heroRadius),
            border: heroBorderWidth > 0
                ? Border.all(
                    color: heroBorderColor ?? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1)),
                    width: heroBorderWidth,
                  )
                : null,
            boxShadow: hasHeroShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Image.file(
                  File(slide.imagePath!),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                )
              : Center(
                  child: Icon(
                    Icons.movie_filter_outlined,
                    size: 46,
                    color: Colors.grey.shade600,
                  ),
                ),
        ),
      ),
    );

    // 4. Movie Subtitle Snippet (clean centered movie caption bar)
    final synopsisText = slide.type == SlideType.cover
        ? slide.coverSubtitle
        : (slide.synopsis.trim().isNotEmpty ? slide.synopsis : slide.ctaSubheadline);

    if (theme.showSynopsis && synopsisText.trim().isNotEmpty) {
      final synBg = theme.getEffectiveBgColor(SlideComponentId.synopsis) ?? Colors.black.withValues(alpha: 0.72);
      final synRadius = theme.getBorderRadiusForComponent(SlideComponentId.synopsis, defaultRadius: 6.0);
      final synPadding = theme.getPaddingForComponent(SlideComponentId.synopsis, defaultPadding: 8.0);
      final synBorderColor = theme.getBorderColorForComponent(SlideComponentId.synopsis);
      final synBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.synopsis) ?? 0.0;
      final synColor = theme.getColorForComponent(SlideComponentId.synopsis) ?? const Color(0xFFFDE047);
      final synFont = theme.getFontForComponent(SlideComponentId.synopsis, defaultFont: theme.bodyFontFamily);
      final synSize = theme.getFontSizeForComponent(SlideComponentId.synopsis, defaultSize: 10.5);
      final synWeight = theme.getFontWeightForComponent(SlideComponentId.synopsis, defaultWeight: FontWeight.w600);
      final synSpacing = theme.getLetterSpacingForComponent(SlideComponentId.synopsis, defaultSpacing: 0.2);

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.synopsis,
          label: 'Movie Subtitle',
          baseLeft: 22,
          baseRight: 22,
          baseTop: 248,
          child: Center(
            child: context.wrapComponentBox(
              componentId: SlideComponentId.synopsis,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: synPadding + 4, vertical: synPadding * 0.6),
                decoration: BoxDecoration(
                  color: synBg,
                  borderRadius: BorderRadius.circular(synRadius),
                  border: synBorderWidth > 0
                      ? Border.all(
                          color: synBorderColor ?? Colors.transparent,
                          width: synBorderWidth,
                        )
                      : null,
                ),
                child: Text(
                  '"$synopsisText"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: synFont,
                    color: synColor,
                    fontSize: synSize,
                    fontWeight: synWeight,
                    letterSpacing: synSpacing,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 5. Cinematic Poster Title (Wide tracking uppercase)
    final titleText = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'FEATURE TITLE');

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Poster Title',
        baseLeft: 20,
        baseRight: 20,
        baseTop: 298,
        child: Center(
          child: context.wrapComponentBox(
            componentId: SlideComponentId.title,
            child: OutlinedText(
              text: titleText.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
                fontSize: theme.getFontSizeForComponent(
                  SlideComponentId.title,
                  defaultSize: (theme.titleFontSize * 1.0).clamp(18.0, 32.0),
                ),
                fontWeight: theme.getFontWeightForComponent(SlideComponentId.title, defaultWeight: FontWeight.w900),
                letterSpacing: theme.getLetterSpacingForComponent(SlideComponentId.title, defaultSpacing: 2.8),
                height: 1.15,
              ),
              fillColor: theme.getColorForComponent(SlideComponentId.title) ?? context.effectiveTitleColor,
              strokeOnly: theme.isTextStrokeOnly(SlideComponentId.title),
              strokeWidth: theme.getTextStrokeWidth(
                SlideComponentId.title,
                defaultWidth: theme.isTextStrokeOnly(SlideComponentId.title) ? 1.5 : 0.0,
              ),
              strokeColor: theme.getTextStrokeColor(SlideComponentId.title, defaultColor: theme.accentColor),
            ),
          ),
        ),
      ),
    );

    // 6. Japanese Original Title (Subtle centered caption)
    final japaneseText = slide.japaneseName.trim();
    if (theme.showJapaneseTitle && japaneseText.isNotEmpty) {
      final jpFont = theme.getFontForComponent(SlideComponentId.japaneseTitle, defaultFont: theme.bodyFontFamily);
      final jpSize = theme.getFontSizeForComponent(SlideComponentId.japaneseTitle, defaultSize: 11.0);
      final jpWeight = theme.getFontWeightForComponent(SlideComponentId.japaneseTitle, defaultWeight: FontWeight.w500);
      final jpSpacing = theme.getLetterSpacingForComponent(SlideComponentId.japaneseTitle, defaultSpacing: 1.5);
      final jpColor = theme.getColorForComponent(SlideComponentId.japaneseTitle) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.japaneseTitle,
          label: 'Japanese Title',
          baseLeft: 20,
          baseRight: 20,
          baseTop: 338,
          child: Center(
            child: context.wrapComponentBox(
              componentId: SlideComponentId.japaneseTitle,
              child: Text(
                japaneseText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: jpFont,
                  fontSize: jpSize,
                  fontWeight: jpWeight,
                  letterSpacing: jpSpacing,
                  color: jpColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 7. Cinema Metadata Chips Row (Rating, Studio, Seasons)
    final ratingScore = slide.rating.replaceAll('/ 10', '').replaceAll('/10', '').trim();
    final studioText = slide.studio.trim();
    final seasonsText = slide.seasons.trim();

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.rating,
        label: 'Cinema Metadata',
        baseLeft: 20,
        baseRight: 20,
        baseTop: 366,
        child: Center(
          child: context.wrapComponentBox(
            componentId: SlideComponentId.rating,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (theme.showRating && ratingScore.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                        const SizedBox(width: 4),
                        Text(
                          ratingScore,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (theme.showStudio && studioText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      studioText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                if (theme.showSeasons && seasonsText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      seasonsText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // 8. Bottom Minimalist Watermark / Curator Tag
    if (theme.showWatermark && theme.watermarkText.trim().isNotEmpty) {
      final handleFont = theme.getFontForComponent(SlideComponentId.pageHandle, defaultFont: theme.bodyFontFamily);
      final handleSize = theme.getFontSizeForComponent(SlideComponentId.pageHandle, defaultSize: 9.5);
      final handleWeight = theme.getFontWeightForComponent(SlideComponentId.pageHandle, defaultWeight: FontWeight.w600);
      final handleColor = theme.getColorForComponent(SlideComponentId.pageHandle) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.pageHandle,
          label: 'Cinema Handle',
          baseLeft: 22,
          baseRight: 22,
          baseBottom: 14,
          useGroupOffset: false,
          child: Center(
            child: context.wrapComponentBox(
              componentId: SlideComponentId.pageHandle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_outlined,
                    size: 13,
                    color: handleColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '@${theme.watermarkText.trim()}',
                    style: TextStyle(
                      fontFamily: handleFont,
                      fontSize: handleSize,
                      fontWeight: handleWeight,
                      letterSpacing: 0.5,
                      color: handleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return list;
  }
}

