import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout 1: SHOWCASE GALLERY (Multi-Shot Showcase)
/// Clean aesthetic with faint typographic watermark, top recommendation badge,
/// bold centered title, floating landscape hero card, dual screenshots row,
/// and centered bottom tagline. Matches assets/images/layout1.jpg.
class Layout1Builder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B7280);
    final watermarkBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

    final List<Widget> list = [];

    // 1. Faint Typographic Watermark Monogram in Upper Background (e.g. "IMN" or watermark letters)
    final watermarkMonogram = theme.watermarkText.trim().isNotEmpty
        ? (theme.watermarkText.length <= 4
            ? theme.watermarkText.toUpperCase()
            : theme.watermarkText.substring(0, 3).toUpperCase())
        : 'IMN';

    list.add(
      Positioned(
        top: 18,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Text(
              watermarkMonogram,
              style: TextStyle(
                fontSize: 105,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: watermarkBgColor,
                height: 0.9,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      ),
    );

    // 2. Slide Counter (Top Right Capsule)
    if (theme.showSlideCounter) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.slideCounter,
          label: 'Slide No',
          baseRight: 16,
          baseTop: 14,
          useGroupOffset: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
        ),
      );
    }

    // 3. Top Hook Tag Pill (e.g. "RECOMMENDATION")
    final hookTagText = slide.coverTag.trim().isNotEmpty ? slide.coverTag : 'RECOMMENDATION';
    if (theme.showHookTag) {
      final hookColor = theme.getColorForComponent(SlideComponentId.hookTag) ?? primaryTextColor;
      final hookBg = theme.getEffectiveBgColor(SlideComponentId.hookTag);
      final hookBorderColor = theme.getBorderColorForComponent(SlideComponentId.hookTag) ??
          (isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF111827));
      final hookBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.hookTag) ?? 1.2;
      final hookRadius = theme.getBorderRadiusForComponent(SlideComponentId.hookTag, defaultRadius: 20.0);
      final hookFont = theme.getFontForComponent(SlideComponentId.hookTag);
      final hookSize = theme.getFontSizeForComponent(SlideComponentId.hookTag, defaultSize: 9.5);
      final hookWeight = theme.getFontWeightForComponent(SlideComponentId.hookTag, defaultWeight: FontWeight.w900);
      final hookSpacing = theme.getLetterSpacingForComponent(SlideComponentId.hookTag, defaultSpacing: 1.2);

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
                color: hookBg,
                borderRadius: BorderRadius.circular(hookRadius),
                border: hookBorderWidth > 0
                    ? Border.all(
                        color: hookBorderColor,
                        width: hookBorderWidth,
                      )
                    : null,
              ),
              child: Text(
                hookTagText.toUpperCase(),
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
        ),
      );
    }

    // 4. Release Year / Meta Subtitle (e.g. "2021")
    final metaText = slide.seasons.trim().isNotEmpty
        ? slide.seasons
        : (slide.studio.trim().isNotEmpty ? slide.studio : '2021');
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.seasons,
        label: 'Year / Meta',
        baseLeft: 40,
        baseRight: 40,
        baseTop: 48,
        child: Center(
          child: Text(
            metaText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: secondaryTextColor,
            ),
          ),
        ),
      ),
    );

    // 5. Anime Title (e.g. "BELLE")
    final titleText = slide.type == SlideType.cover
        ? slide.coverTitle
        : (slide.animeName.trim().isNotEmpty ? slide.animeName : 'BELLE');

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Title',
        baseLeft: 20,
        baseRight: 20,
        baseTop: 68,
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
                  defaultSize: (theme.titleFontSize * 1.1).clamp(20.0, 36.0),
                ),
                fontWeight: theme.getFontWeightForComponent(SlideComponentId.title, defaultWeight: FontWeight.w900),
                letterSpacing: theme.getLetterSpacingForComponent(SlideComponentId.title, defaultSpacing: 1.0),
                height: 1.1,
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

    // 6. Primary Landscape Hero Image Card (~16:9 ratio, smooth corners & elevation)
    final heroBorderColor = theme.getBorderColorForComponent(SlideComponentId.heroVisual);
    final heroBorderWidth = theme.getBorderWidthForComponent(SlideComponentId.heroVisual) ?? 0.0;
    final heroRadius = theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 18.0);
    final heroBg = theme.getEffectiveBgColor(SlideComponentId.heroVisual) ??
        (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100);
    final hasHeroShadow = theme.hasShadowForComponent(SlideComponentId.heroVisual, defaultShadow: true);

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.heroVisual,
        label: 'Hero Image',
        baseLeft: 18,
        baseRight: 18,
        baseTop: 114,
        height: 185,
        child: Container(
          decoration: BoxDecoration(
            color: heroBg,
            borderRadius: BorderRadius.circular(heroRadius),
            border: heroBorderWidth > 0
                ? Border.all(
                    color: heroBorderColor ?? (isDark ? Colors.white24 : Colors.black12),
                    width: heroBorderWidth,
                  )
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
                    Icons.image_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
        ),
      ),
    );

    // 7. Screenshots Section ("SCREENSHOTS :" heading + dual screenshots cards)
    final secImgs = slide.secondaryImagePaths;
    final hasSec1 = secImgs.isNotEmpty && File(secImgs[0]).existsSync();
    final hasSec2 = secImgs.length > 1 && File(secImgs[1]).existsSync();

    Widget buildScreenshotTile({required bool isLeft}) {
      return Expanded(
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isLeft
              ? (hasSec1
                  ? Image.file(File(secImgs[0]), fit: BoxFit.cover)
                  : (hasImage
                      ? Image.file(
                          File(slide.imagePath!),
                          fit: BoxFit.cover,
                          alignment: const Alignment(-0.6, 0.0),
                        )
                      : Center(child: Icon(Icons.photo_outlined, size: 22, color: Colors.grey.shade400))))
              : (hasSec2
                  ? Image.file(File(secImgs[1]), fit: BoxFit.cover)
                  : (hasImage
                      ? Image.file(
                          File(slide.imagePath!),
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.6, 0.0),
                        )
                      : Center(child: Icon(Icons.photo_outlined, size: 22, color: Colors.grey.shade400)))),
        ),
      );
    }

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.screenshots,
        label: 'Screenshots',
        baseLeft: 18,
        baseRight: 18,
        baseTop: 310,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SCREENSHOTS :',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                buildScreenshotTile(isLeft: true),
                const SizedBox(width: 8),
                buildScreenshotTile(isLeft: false),
              ],
            ),
          ],
        ),
      ),
    );

    // 8. Bottom Center Tagline / Caption Footer
    final taglineText = slide.synopsis.trim().isNotEmpty
        ? slide.synopsis
        : (slide.coverSubtitle.trim().isNotEmpty
            ? slide.coverSubtitle
            : 'ANIME MOVIES THAT ARE ABSOLUTE PEAK');

    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.synopsis,
        label: 'Tagline',
        baseLeft: 20,
        baseRight: 20,
        baseBottom: 12,
        child: Center(
          child: Text(
            taglineText.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: secondaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    return list;
  }
}

/// Backwards compatibility alias
typedef ShowcaseGalleryLayoutBuilder = Layout1Builder;

