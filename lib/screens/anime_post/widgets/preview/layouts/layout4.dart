import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 4: EDITORIAL MAGAZINE / ASYMMETRIC SPREAD
/// High-fashion publication aesthetic featuring faint vertical Japanese typography,
/// an asymmetric framed visual card with frosted metadata badge, refined editorial
/// title typography, accent-bordered pull-quote synopsis, and clean attribution footer.
class Layout4Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF6B7280);
    final watermarkBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

    final List<Widget> list = [];

    // 1. Elegant Vertical Calligraphy / Japanese Typographic Watermark on the Right
    final verticalWatermark = slide.japaneseName.trim().isNotEmpty
        ? slide.japaneseName.trim()
        : (slide.animeName.trim().isNotEmpty ? slide.animeName.trim() : '推薦作品');

    list.add(
      Positioned(
        top: 28,
        right: 14,
        bottom: 28,
        child: IgnorePointer(
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(
              verticalWatermark.toUpperCase(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 8.0,
                color: watermarkBgColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      ),
    );

    // 2. Top Header Row: Issue / Entry Badge (Left)
    final rankText = slide.rank > 0 ? (slide.rank < 10 ? '0${slide.rank}' : '${slide.rank}') : '01';
    final hookTagText = slide.coverTag.trim().isNotEmpty ? slide.coverTag.toUpperCase() : 'EDITORIAL PICK';

    if (theme.showHookTag || theme.showRankBadge) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.hookTag,
          label: 'Editorial Issue',
          baseLeft: 20,
          baseTop: 16,
          useGroupOffset: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '№ $rankText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hookTagText,
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Top Header Row: Minimalist Slide Counter (Right)
    if (theme.showSlideCounter) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.slideCounter,
          label: 'Slide Counter',
          baseRight: 20,
          baseTop: 16,
          useGroupOffset: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${context.slideIndex + 1} / ${context.totalSlides}',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      );
    }

    // 4. Hero Visual Card (~4:3 ratio, clean border, soft shadow, frosted rating chip)
    final ratingScore = slide.rating.replaceAll('/ 10', '').replaceAll('/10', '').trim();
    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 1.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 16.0);
    final heroBg = theme.getEffectiveBgColor(SlideComponentId.heroVisual) ??
        (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100);
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: true);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Magazine Visual',
        baseLeft: 20,
        baseRight: 20,
        baseTop: 48,
        height: 215,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasImage
                  ? Image.file(
                      File(slide.imagePath!),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    )
                  : Center(
                      child: Icon(
                        Icons.auto_stories_outlined,
                        size: 44,
                        color: Colors.grey.shade400,
                      ),
                    ),

              // Frosted rating chip on the bottom-left inside the visual
              if (theme.showRating && ratingScore.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          ratingScore,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // 5. Genre / Category Line with Wide Tracking (below visual)
    final genreText = slide.genres.trim().isNotEmpty
        ? slide.genres.replaceAll(',', ' •').toUpperCase()
        : 'ACTION • DRAMA • SHONEN';

    if (theme.showGenres) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.genres,
          label: 'Category',
          baseLeft: 20,
          baseRight: 20,
          baseTop: 272,
          child: Text(
            genreText,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: theme.accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // 6. Refined Editorial Title
    final titleText = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'ANIME TITLE');

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Title',
        baseLeft: 20,
        baseRight: 20,
        baseTop: 290,
        child: context.wrapComponentBox(
          componentId: SlideComponentId.title,
          child: OutlinedText(
            text: titleText,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
              fontSize: theme.getFontSizeForComponent(
                SlideComponentId.title,
                defaultSize: (theme.titleFontSize * 1.05).clamp(20.0, 34.0),
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

    // 7. Minimalist Pull-Quote Synopsis Box with Accent Border
    final synopsisText = slide.type == SlideType.cover
        ? slide.coverSubtitle
        : (slide.synopsis.trim().isNotEmpty ? slide.synopsis : slide.ctaSubheadline);

    if (theme.showSynopsis && synopsisText.trim().isNotEmpty) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.synopsis,
          label: 'Synopsis Quote',
          baseLeft: 20,
          baseRight: 20,
          baseTop: 345,
          child: Container(
            padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.accentColor,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              synopsisText,
              style: TextStyle(
                fontFamily: theme.getFontForComponent(SlideComponentId.synopsis, defaultFont: theme.bodyFontFamily),
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                height: 1.35,
                color: context.effectiveBodyColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    // 8. Footer Metadata Row: Studio, Episodes & Watermark
    final studioText = slide.studio.trim().isNotEmpty ? slide.studio.toUpperCase() : 'STUDIO';
    final seasonText = slide.seasons.trim().isNotEmpty ? slide.seasons.toUpperCase() : '';
    final episodeText = slide.episodes.trim().isNotEmpty ? '${slide.episodes.toUpperCase()} EPS' : '';

    final metaTokens = [
      if (theme.showStudio && studioText.isNotEmpty) studioText,
      if (theme.showSeasons && seasonText.isNotEmpty) seasonText,
      if (theme.showEpisodes && episodeText.isNotEmpty) episodeText,
    ];

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.studio,
        label: 'Meta Footer',
        baseLeft: 20,
        baseRight: 20,
        baseBottom: 14,
        useGroupOffset: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (metaTokens.isNotEmpty)
              Expanded(
                child: Text(
                  metaTokens.join('  •  '),
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const Spacer(),
            if (theme.showWatermark && theme.watermarkText.trim().isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${theme.watermarkText.trim()}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: primaryTextColor,
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
    );

    return list;
  }
}

