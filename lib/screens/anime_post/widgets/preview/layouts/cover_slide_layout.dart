import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../../anime_detail_components.dart';
import '../outlined_text.dart';
import '../slide_render_context.dart';

/// Layout builder for Cover slides.
class CoverSlideLayoutBuilder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final List<Widget> list = [];

    // 1. Hook Tag (centered above title)
    if (slide.coverTag.isNotEmpty && theme.showHookTag) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.hookTag,
          label: 'Hook Tag',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 178,
          child: Center(
            child: AnimeHookTagComponent.fromTheme(
              tag: slide.coverTag,
              theme: theme,
              isDarkBackground: hasImage,
            ),
          ),
        ),
      );
    }

    // 2. Cover Title (fixed centered anchor)
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Cover Title',
        baseLeft: 20,
        baseRight: 20,
        baseBottom: 102,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedText(
            text: slide.coverTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
              fontSize: (theme.titleFontSize * 1.3).clamp(18.0, 44.0),
              fontWeight: theme.titleFontWeight,
              height: 1.15,
            ),
            fillColor: context.effectiveTitleColor,
            strokeOnly: theme.isTextStrokeOnly(SlideComponentId.title),
            strokeWidth: theme.getTextStrokeWidth(
              SlideComponentId.title,
              defaultWidth: theme.isTextStrokeOnly(SlideComponentId.title) ? 1.5 : 0.0,
            ),
            strokeColor: theme.getTextStrokeColor(SlideComponentId.title, defaultColor: theme.accentColor),
            shadows: (hasImage && theme.titleTextColor == null && !theme.isTextStrokeOnly(SlideComponentId.title))
                ? const [Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 10)]
                : null,
          ),
        ),
      ),
    );

    // 3. Cover Subtitle (fixed centered anchor below Cover Title)
    if (slide.coverSubtitle.isNotEmpty) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.synopsis,
          label: 'Subtitle',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 56,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              slide.coverSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: theme.getFontForComponent(SlideComponentId.synopsis, defaultFont: theme.bodyFontFamily),
                color: context.effectiveBodyColor,
                fontSize: (theme.bodyFontSize * 1.15).clamp(10.0, 24.0),
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    // 4. Swipe Indicator (centered below subtitle)
    if (theme.showSwipeIndicator) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.swipeIndicator,
          label: 'Swipe Cue',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 16,
          child: Center(
            child: AnimeSwipeIndicatorComponent(
              label: 'Swipe to start',
              accentColor: theme.accentColor,
              fontFamily: theme.getFontForComponent(SlideComponentId.swipeIndicator, defaultFont: theme.bodyFontFamily),
              isDarkBackground: hasImage,
              isVisible: theme.showSwipeIndicator,
            ),
          ),
        ),
      );
    }

    return list;
  }
}
