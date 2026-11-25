import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 6: POLAROID ARCHIVE / AESTHETIC SCRAPBOOK
/// Nostalgic yet modern Japanese aesthetic archive card featuring a floating
/// Polaroid photo frame with a semi-translucent washi tape accent, hand-stamped
/// bottom margin caption, minimal hashtag genre pills, and an archive footer.
class Layout6Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF6B7280);

    final List<Widget> list = [];

    // 1. Top Minimal Bar: Slide Counter & Archive Tag
    if (theme.showHookTag) {
      final hookFont = theme.getFontForComponent(SlideComponentId.hookTag);
      final hookSize = theme.getFontSizeForComponent(SlideComponentId.hookTag, defaultSize: 9.0);
      final hookWeight = theme.getFontWeightForComponent(SlideComponentId.hookTag, defaultWeight: FontWeight.w800);
      final hookSpacing = theme.getLetterSpacingForComponent(SlideComponentId.hookTag, defaultSpacing: 1.5);
      final hookColor = theme.getColorForComponent(SlideComponentId.hookTag) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.hookTag,
          label: 'Archive Tag',
          baseLeft: 24,
          baseTop: 16,
          useGroupOffset: false,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.hookTag,
            child: Text(
              (slide.coverTag.trim().isNotEmpty ? slide.coverTag : 'CURATED ARCHIVE').toUpperCase(),
              style: TextStyle(
                fontFamily: hookFont,
                fontSize: hookSize,
                fontWeight: hookWeight,
                letterSpacing: hookSpacing,
                color: hookColor,
              ),
            ),
          ),
        ),
      );
    }

    if (theme.showSlideCounter) {
      final counterFont = theme.getFontForComponent(SlideComponentId.slideCounter);
      final counterSize = theme.getFontSizeForComponent(SlideComponentId.slideCounter, defaultSize: 10.0);
      final counterWeight = theme.getFontWeightForComponent(SlideComponentId.slideCounter, defaultWeight: FontWeight.bold);
      final counterColor = theme.getColorForComponent(SlideComponentId.slideCounter) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.slideCounter,
          label: 'Archive No',
          baseRight: 24,
          baseTop: 16,
          useGroupOffset: false,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.slideCounter,
            child: Text(
              '${context.slideIndex + 1} / ${context.totalSlides}',
              style: TextStyle(
                fontFamily: counterFont,
                fontSize: counterSize,
                fontWeight: counterWeight,
                letterSpacing: 1.0,
                color: counterColor,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Polaroid Card with Washi Tape Accent
    final ratingScore = slide.rating.replaceAll('/ 10', '').replaceAll('/10', '').trim();
    final rankText = slide.rank > 0 ? (slide.rank < 10 ? '0${slide.rank}' : '${slide.rank}') : '01';
    final titleText = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'Anime Title');

    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 1.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 12.0);
    final heroBg = theme.getEffectiveBgColor(SlideComponentId.heroVisual) ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFFDFAF6));
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: true);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Polaroid Card',
        baseLeft: 24,
        baseRight: 24,
        baseTop: 42,
        height: 255,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Polaroid Paper Frame
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                color: heroBg,
                borderRadius: BorderRadius.circular(heroRadius),
                border: heroBorderWidth > 0
                    ? Border.all(
                        color: heroBorderColor ?? (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E7EB)),
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
              child: Column(
                children: [
                  // Photo Viewport
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular((heroRadius - 4).clamp(4.0, 20.0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasImage
                          ? Image.file(
                              File(slide.imagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Center(
                              child: Icon(
                                Icons.photo_library_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),

                  // Bottom Polaroid Paper Caption Margin
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '№ $rankText  •  $titleText',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (theme.showRating && ratingScore.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
                              const SizedBox(width: 3),
                              Text(
                                ratingScore,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Realistic Washi Tape Accent at Top Center
            Positioned(
              top: 0,
              child: Transform.rotate(
                angle: -0.03,
                child: Container(
                  width: 58,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 3. Clean Title (OutlinedText support)
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Title',
        baseLeft: 24,
        baseRight: 24,
        baseTop: 310,
        child: context.wrapComponentBox(
          componentId: SlideComponentId.title,
          child: OutlinedText(
            text: titleText,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
              fontSize: theme.getFontSizeForComponent(
                SlideComponentId.title,
                defaultSize: (theme.titleFontSize * 1.0).clamp(18.0, 30.0),
              ),
              fontWeight: theme.getFontWeightForComponent(SlideComponentId.title, defaultWeight: FontWeight.w800),
              letterSpacing: theme.getLetterSpacingForComponent(SlideComponentId.title, defaultSpacing: 0.2),
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

    // 4. Hashtag Genre Pills
    final rawGenres = slide.genres.trim();
    if (theme.showGenres && rawGenres.isNotEmpty) {
      final genreList = rawGenres.split(RegExp(r'[,•/|]')).map((g) => g.trim()).where((g) => g.isNotEmpty).take(3);
      final genreFont = theme.getFontForComponent(SlideComponentId.genres, defaultFont: theme.bodyFontFamily);
      final genreSize = theme.getFontSizeForComponent(SlideComponentId.genres, defaultSize: 9.5);
      final genreColor = theme.getColorForComponent(SlideComponentId.genres) ?? secondaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.genres,
          label: 'Genre Pills',
          baseLeft: 24,
          baseRight: 24,
          baseTop: 342,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.genres,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: genreList.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$genre',
                    style: TextStyle(
                      fontFamily: genreFont,
                      fontSize: genreSize,
                      fontWeight: FontWeight.w600,
                      color: genreColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    // 5. Brief Synopsis Note
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
          label: 'Archive Note',
          baseLeft: 24,
          baseRight: 24,
          baseTop: 372,
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

    // 6. Minimalist Watermark Footer
    if (theme.showWatermark && theme.watermarkText.trim().isNotEmpty) {
      final handleFont = theme.getFontForComponent(SlideComponentId.pageHandle, defaultFont: theme.bodyFontFamily);
      final handleSize = theme.getFontSizeForComponent(SlideComponentId.pageHandle, defaultSize: 9.5);
      final handleWeight = theme.getFontWeightForComponent(SlideComponentId.pageHandle, defaultWeight: FontWeight.bold);
      final handleColor = theme.getColorForComponent(SlideComponentId.pageHandle) ?? primaryTextColor;

      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.pageHandle,
          label: 'Archive Handle',
          baseLeft: 24,
          baseRight: 24,
          baseBottom: 14,
          useGroupOffset: false,
          child: context.wrapComponentBox(
            componentId: SlideComponentId.pageHandle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COLLECTION 2024',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: secondaryTextColor.withValues(alpha: 0.6),
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

