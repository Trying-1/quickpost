import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 3: FLOATING POSTER & MAL BADGE
/// Minimalist sleek aesthetic with floating portrait poster card, centered title,
/// uppercase episode count, branded [MAL] • 8.12 rating pill, bottom watermark
/// logo and bottom-right series tag. Matches assets/images/layout3.jpg.
class Layout3Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF6B7280);

    final List<Widget> list = [];

    // 1. Top Right Minimalist Slide Counter Pill (e.g. "4/15")
    if (theme.showSlideCounter) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.slideCounter,
          label: 'Slide No',
          baseRight: 18,
          baseTop: 16,
          useGroupOffset: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${context.slideIndex + 1}/${context.totalSlides}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Center Floating Portrait Poster Card (3:4 ratio with smooth rounded corners & soft shadow)
    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 1.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 22.0);
    final heroBg = theme.getEffectiveBgColor(SlideComponentId.heroVisual) ??
        (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100);
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: true);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Poster Card',
        baseLeft: 40,
        baseRight: 40,
        baseTop: 45,
        height: 250,
        child: Center(
          child: Container(
            width: 215,
            height: 250,
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
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 24,
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
                  )
                : Center(
                    child: Icon(
                      Icons.movie_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                  ),
          ),
        ),
      ),
    );

    // 3. Centered Anime Title (e.g. "Solo Leveling")
    final titleText = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'Solo Leveling');

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Title',
        baseLeft: 24,
        baseRight: 24,
        baseTop: 310,
        child: Center(
          child: context.wrapComponentBox(
            componentId: SlideComponentId.title,
            child: OutlinedText(
              text: titleText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
                fontSize: theme.getFontSizeForComponent(
                  SlideComponentId.title,
                  defaultSize: (theme.titleFontSize * 1.05).clamp(18.0, 32.0),
                ),
                fontWeight: theme.getFontWeightForComponent(SlideComponentId.title, defaultWeight: FontWeight.w800),
                letterSpacing: theme.getLetterSpacingForComponent(SlideComponentId.title, defaultSpacing: 0.3),
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

    // 4. Centered Episode Count (e.g. "25 EPISODES")
    final episodesText = slide.episodes.trim().isNotEmpty
        ? (slide.episodes.toLowerCase().contains('ep') ? slide.episodes : '${slide.episodes} EPISODES')
        : '25 EPISODES';

    if (theme.showEpisodes) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.episodes,
          label: 'Episodes',
          baseLeft: 24,
          baseRight: 24,
          baseTop: 342,
          child: Center(
            child: Text(
              episodesText.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: secondaryTextColor,
              ),
            ),
          ),
        ),
      );
    }

    // 5. Branded [MAL] • 8.12 Rating Badge Row
    String ratingScore = slide.rating.replaceAll('/ 10', '').replaceAll('/10', '').trim();
    if (ratingScore.isEmpty) {
      ratingScore = '8.12';
    }

    if (theme.showRating) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.rating,
          label: 'MAL Rating',
          baseLeft: 24,
          baseRight: 24,
          baseTop: 366,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // [MAL] Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E51A2), // Official MyAnimeList blue
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'MAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ratingScore,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 6. Bottom Left: Watermark Brand Logo / Text (e.g. "IMN")
    final watermarkBrand = theme.watermarkText.trim().isNotEmpty
        ? (theme.watermarkText.length <= 4
            ? theme.watermarkText.toUpperCase()
            : theme.watermarkText)
        : 'IMN';

    if (theme.showWatermark) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.pageHandle,
          label: 'Watermark',
          baseLeft: 18,
          baseBottom: 14,
          useGroupOffset: false,
          child: Text(
            watermarkBrand,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }

    // 7. Bottom Right: Series / Category Hook Tagline (e.g. "WEAK TO STRONG ANIME RECS")
    final seriesHookText = slide.coverTag.trim().isNotEmpty
        ? slide.coverTag
        : (slide.genres.trim().isNotEmpty ? slide.genres : 'WEAK TO STRONG ANIME RECS');

    if (theme.showHookTag) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.hookTag,
          label: 'Series Hook',
          baseRight: 18,
          baseBottom: 15,
          useGroupOffset: false,
          child: Text(
            seriesHookText.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return list;
  }
}

/// Backwards compatibility alias
typedef FloatingPosterLayoutBuilder = Layout3Builder;

