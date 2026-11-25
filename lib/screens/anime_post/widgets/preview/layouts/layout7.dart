import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 7: MINIMAL SPLIT / SWISS MODERNIST SLATE
/// Ultra-clean Swiss modernist architecture featuring an oversized subtle rank
/// watermark, floating visual card, crisp sans-serif title, a balanced 3-column
/// metadata slate with delicate hairline dividers, and an uncluttered footer.
class Layout7Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF6B7280);
    final watermarkBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1);

    final List<Widget> list = [];

    // 1. Oversized Minimalist Rank Watermark Numeral in Background ("01", "02")
    final rankText = slide.rank > 0 ? (slide.rank < 10 ? '0${slide.rank}' : '${slide.rank}') : '01';
    list.add(
      Positioned(
        top: 10,
        right: 14,
        child: IgnorePointer(
          child: Text(
            rankText,
            style: TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.w900,
              letterSpacing: -4,
              color: watermarkBgColor,
              height: 0.85,
            ),
          ),
        ),
      ),
    );

    // 2. Top Hairline Bar: Category Label & Slide Counter
    if (theme.showHookTag || theme.showSlideCounter) {
      final hookFont = theme.getFontForComponent(SlideComponentId.hookTag);
      final hookSize = theme.getFontSizeForComponent(SlideComponentId.hookTag, defaultSize: 8.5);
      final hookWeight = theme.getFontWeightForComponent(SlideComponentId.hookTag, defaultWeight: FontWeight.w800);
      final hookSpacing = theme.getLetterSpacingForComponent(SlideComponentId.hookTag, defaultSpacing: 2.0);
      final hookColor = theme.getColorForComponent(SlideComponentId.hookTag) ?? theme.accentColor;

      final counterFont = theme.getFontForComponent(SlideComponentId.slideCounter);
      final counterSize = theme.getFontSizeForComponent(SlideComponentId.slideCounter, defaultSize: 9.5);
      final counterWeight = theme.getFontWeightForComponent(SlideComponentId.slideCounter, defaultWeight: FontWeight.bold);
      final counterSpacing = theme.getLetterSpacingForComponent(SlideComponentId.slideCounter, defaultSpacing: 1.0);
      final counterColor = theme.getColorForComponent(SlideComponentId.slideCounter) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.hookTag,
          label: 'Top Header',
          baseLeft: 22,
          baseRight: 22,
          baseTop: 16,
          useGroupOffset: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (theme.showHookTag)
                context.wrapComponentBox(
                  componentId: SlideComponentId.hookTag,
                  child: Text(
                    (slide.coverTag.trim().isNotEmpty ? slide.coverTag : 'CURATION / ANIME').toUpperCase(),
                    style: TextStyle(
                      fontFamily: hookFont,
                      fontSize: hookSize,
                      fontWeight: hookWeight,
                      letterSpacing: hookSpacing,
                      color: hookColor,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (theme.showSlideCounter)
                context.wrapComponentBox(
                  componentId: SlideComponentId.slideCounter,
                  child: Text(
                    '${context.slideIndex + 1} / ${context.totalSlides}',
                    style: TextStyle(
                      fontFamily: counterFont,
                      fontSize: counterSize,
                      fontWeight: counterWeight,
                      letterSpacing: counterSpacing,
                      color: counterColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 3. Floating Visual Card (~16:10 ratio, sharp clean corners, soft shadow)
    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 1.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 14.0);
    final heroBg = theme.getEffectiveBgColor(SlideComponentId.heroVisual) ??
        (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100);
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: true);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Visual Card',
        baseLeft: 20,
        baseRight: 20,
        baseTop: 44,
        height: 205,
        child: Container(
          decoration: BoxDecoration(
            color: heroBg,
            borderRadius: BorderRadius.circular(heroRadius),
            border: heroBorderWidth > 0
                ? Border.all(
                    color: heroBorderColor ?? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
                    width: heroBorderWidth,
                  )
                : null,
            boxShadow: hasHeroShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
                    Icons.dashboard_outlined,
                    size: 42,
                    color: Colors.grey.shade400,
                  ),
                ),
        ),
      ),
    );

    // 4. Crisp Swiss Modernist Title
    final titleText = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'ANIME TITLE');

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Title',
        baseLeft: 22,
        baseRight: 22,
        baseTop: 262,
        child: context.wrapComponentBox(
          componentId: SlideComponentId.title,
          child: OutlinedText(
            text: titleText,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
              fontSize: theme.getFontSizeForComponent(
                SlideComponentId.title,
                defaultSize: (theme.titleFontSize * 1.05).clamp(19.0, 32.0),
              ),
              fontWeight: theme.getFontWeightForComponent(SlideComponentId.title, defaultWeight: FontWeight.w900),
              letterSpacing: theme.getLetterSpacingForComponent(SlideComponentId.title, defaultSpacing: 0.2),
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
    );

    // 5. 3-Column Micro Data Slate (Score • Studio • Episodes)
    final ratingScore = slide.rating.replaceAll('/ 10', '').replaceAll('/10', '').trim();
    final studioText = slide.studio.trim();
    final epText = slide.episodes.trim();

    final slateBg = theme.getEffectiveBgColor(SlideComponentId.rating) ??
        (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03));
    final slateBorderColor = theme.getBorderColorForComponent(SlideComponentId.rating) ?? dividerColor;
    final slateBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.rating) ?? 0.8;
    final slateRadius = theme.getBorderRadiusForComponent(SlideComponentId.rating, defaultRadius: 10.0);
    final slatePadding = theme.getPaddingForComponent(SlideComponentId.rating, defaultPadding: 14.0);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.rating,
        label: 'Data Slate',
        baseLeft: 22,
        baseRight: 22,
        baseTop: 310,
        child: context.wrapComponentBox(
          componentId: SlideComponentId.rating,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: slatePadding, vertical: slatePadding * 0.55),
            decoration: BoxDecoration(
              color: slateBg,
              borderRadius: BorderRadius.circular(slateRadius),
              border: slateBorderWidth > 0 ? Border.all(color: slateBorderColor, width: slateBorderWidth) : null,
            ),
            child: Row(
              children: [
                // Column 1: Rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                          const SizedBox(width: 3),
                          Text(
                            ratingScore.isNotEmpty ? ratingScore : '8.5',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Vertical divider
                Container(width: 1, height: 26, color: dividerColor),

                // Column 2: Studio
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'STUDIO',
                          style: TextStyle(
                            fontSize: 8.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          studioText.isNotEmpty ? studioText.toUpperCase() : 'STUDIO',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                // Vertical divider
                Container(width: 1, height: 26, color: dividerColor),

                // Column 3: Episodes
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LENGTH',
                          style: TextStyle(
                            fontSize: 8.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          epText.isNotEmpty ? '$epText EPS' : (slide.seasons.isNotEmpty ? slide.seasons : '12 EPS'),
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 6. Clean Single-Sentence Synopsis
    final synopsisText = slide.type == SlideType.cover
        ? slide.coverSubtitle
        : (slide.synopsis.trim().isNotEmpty ? slide.synopsis : slide.ctaSubheadline);

    if (theme.showSynopsis && synopsisText.trim().isNotEmpty) {
      final synFont = theme.getFontForComponent(SlideComponentId.synopsis, defaultFont: theme.bodyFontFamily);
      final synSize = theme.getFontSizeForComponent(SlideComponentId.synopsis, defaultSize: 11.0);
      final synWeight = theme.getFontWeightForComponent(SlideComponentId.synopsis, defaultWeight: FontWeight.w400);
      final synSpacing = theme.getLetterSpacingForComponent(SlideComponentId.synopsis, defaultSpacing: 0.0);
      final synColor = theme.getColorForComponent(SlideComponentId.synopsis) ?? context.effectiveBodyColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.synopsis,
          label: 'Synopsis',
          baseLeft: 22,
          baseRight: 22,
          baseTop: 366,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.synopsis,
            child: Text(
              synopsisText,
              style: TextStyle(
                fontFamily: synFont,
                fontSize: synSize,
                fontWeight: synWeight,
                letterSpacing: synSpacing,
                height: 1.35,
                color: synColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    // 7. Footer: Minimalist Watermark / Verified Badge
    if (theme.showWatermark && theme.watermarkText.trim().isNotEmpty) {
      final handleFont = theme.getFontForComponent(SlideComponentId.pageHandle, defaultFont: theme.bodyFontFamily);
      final handleSize = theme.getFontSizeForComponent(SlideComponentId.pageHandle, defaultSize: 9.5);
      final handleWeight = theme.getFontWeightForComponent(SlideComponentId.pageHandle, defaultWeight: FontWeight.bold);
      final handleColor = theme.getColorForComponent(SlideComponentId.pageHandle) ?? primaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.pageHandle,
          label: 'Handle',
          baseLeft: 22,
          baseRight: 22,
          baseBottom: 14,
          useGroupOffset: false,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.pageHandle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SWISS MINIMAL',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: secondaryTextColor.withValues(alpha: 0.5),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${theme.watermarkText.trim()}',
                      style: TextStyle(
                        fontFamily: handleFont,
                        fontSize: handleSize,
                        fontWeight: handleWeight,
                        letterSpacing: 0.4,
                        color: handleColor,
                      ),
                    ),
                    if (theme.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 12, color: Color(0xFF3897F0)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return list;
  }
}

