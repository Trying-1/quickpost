import 'package:flutter/material.dart';
import '../../../models/carousel_slide.dart';
import '../../carousel_detail_components.dart';
import '../slide_render_context.dart';

/// Layout builder for Cover slides in Carousel Posts.
class CoverSlideLayoutBuilder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final isDark = context.isDarkBackground;

    final List<Widget> list = [];

    // 1. Calculate dynamic placement to prevent any title / subtitle overlap
    const baseTitleTop = 100.0;
    final coverTitleText = slide.coverTitle.trim().isNotEmpty ? slide.coverTitle : slide.title;
    final titleLength = coverTitleText.trim().length;
    const charsPerLine = 20;
    final titleLines = (titleLength / charsPerLine).ceil().clamp(1, 4);
    final effectiveTitleFontSize = (theme.titleFontSize * 1.3).clamp(18.0, 44.0);
    final estimatedTitleHeight = titleLines * (effectiveTitleFontSize * 1.2);
    final baseSubtitleTop = (baseTitleTop + estimatedTitleHeight + 16.0).clamp(155.0, 270.0);

    // 1. Cover Title
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Cover Title',
        baseLeft: 20,
        baseRight: 20,
        baseTop: baseTitleTop,
        child: Text(
          coverTitleText,
          style: TextStyle(
            fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
            color: context.effectiveTitleColor,
            fontSize: effectiveTitleFontSize,
            fontWeight: theme.titleFontWeight,
            height: 1.15,
            shadows: isDark && theme.titleTextColor == null
                ? const [Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 10)]
                : null,
          ),
        ),
      ),
    );

    // 2. Cover Subtitle (Positioned below Cover Title to guarantee no collision)
    final coverSubtitleText = slide.coverSubtitle.trim().isNotEmpty ? slide.coverSubtitle : slide.bodyText;
    if (coverSubtitleText.isNotEmpty) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.bodyText,
          label: 'Subtitle',
          baseLeft: 20,
          baseRight: 20,
          baseTop: baseSubtitleTop,
          child: Text(
            coverSubtitleText,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.bodyText, defaultFont: theme.bodyFontFamily),
              color: context.effectiveBodyColor,
              fontSize: (theme.bodyFontSize * 1.15).clamp(10.0, 24.0),
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    // 3. Swipe Indicator
    if (theme.showSwipeIndicator) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.swipeIndicator,
          label: 'Swipe Cue',
          baseLeft: 20,
          baseBottom: 24,
          child: CarouselSwipeIndicatorComponent(
            label: 'Swipe to read',
            accentColor: theme.accentColor,
            fontFamily: theme.getFontForComponent(SlideComponentId.swipeIndicator, defaultFont: theme.bodyFontFamily),
            isDarkBackground: isDark,
            isVisible: theme.showSwipeIndicator,
          ),
        ),
      );
    }

    return list;
  }
}
