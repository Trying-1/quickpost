import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 2: BOLD HEADLINE / SPOTLIGHT
/// Clean pastel/white background with top centered pill tag, account handle,
/// top-right counter capsule, punchy multi-line bold headline, and large
/// centered character/poster spotlight. Matches assets/images/layout2.jpg.
class Layout2Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);

    final List<Widget> list = [];

    // 1. Subtle Ambient Gradient in Canvas Background (light pastel vignette toward bottom)
    list.add(
      Positioned.fill(
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: isDark
                    ? [
                        Colors.transparent,
                        Colors.transparent,
                        theme.accentColor.withValues(alpha: 0.12),
                      ]
                    : [
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xFFFFEBF2).withValues(alpha: 0.7),
                      ],
              ),
            ),
          ),
        ),
      ),
    );

    // 2. Top Right: Account Handle & Slide Counter Stack
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.slideCounter,
        label: 'Counter & Handle',
        baseRight: 16,
        baseTop: 12,
        useGroupOffset: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (theme.showWatermark && theme.watermarkText.trim().isNotEmpty) ...[
              Text(
                'IG/@${theme.watermarkText}',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (theme.showSlideCounter)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
          ],
        ),
      ),
    );

    // 3. Top Center: Hook Tag Pill Badge (e.g. "RECOMMENDATION")
    final hookTagText = slide.coverTag.trim().isNotEmpty ? slide.coverTag : 'RECOMMENDATION';
    if (theme.showHookTag) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.hookTag,
          label: 'Hook Tag',
          baseLeft: 40,
          baseRight: 40,
          baseTop: 18,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF111827),
                  width: 1.2,
                ),
              ),
              child: Text(
                hookTagText.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: primaryTextColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 4. Massive Punchy Multi-Line Bold Headline
    String headline = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'MUST WATCH SLICE OF LIFE ANIME');

    // If single line with spaces, format neatly as two-line punchy headline
    if (!headline.contains('\n') && headline.split(' ').length >= 4) {
      final words = headline.split(' ');
      final mid = (words.length / 2).ceil();
      headline = '${words.sublist(0, mid).join(' ')}\n${words.sublist(mid).join(' ')}';
    }

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Headline',
        baseLeft: 18,
        baseRight: 18,
        baseTop: 54,
        child: Center(
          child: context.wrapComponentBox(
            componentId: SlideComponentId.title,
            child: OutlinedText(
              text: headline.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
                fontSize: theme.getFontSizeForComponent(
                  SlideComponentId.title,
                  defaultSize: (theme.titleFontSize * 1.2).clamp(22.0, 42.0),
                ),
                fontWeight: theme.getFontWeightForComponent(SlideComponentId.title, defaultWeight: FontWeight.w900),
                letterSpacing: theme.getLetterSpacingForComponent(SlideComponentId.title, defaultSpacing: -0.5),
                height: 1.05,
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

    // 5. Hero Character / Poster Spotlight (Large Centered Visual)
    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 0.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 16.0);
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: false);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Character Spotlight',
        baseLeft: 16,
        baseRight: 16,
        baseTop: 135,
        baseBottom: 16,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(heroRadius),
              border: heroBorderWidth > 0
                  ? Border.all(color: heroBorderColor ?? (isDark ? Colors.white24 : Colors.black12), width: heroBorderWidth)
                  : null,
              boxShadow: hasHeroShadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(heroRadius),
                    child: Image.file(
                      File(slide.imagePath!),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  )
                : Container(
                    width: 240,
                    height: 280,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(heroRadius),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );

    return list;
  }
}

/// Backwards compatibility alias
typedef BoldHeadlineLayoutBuilder = Layout2Builder;

