import 'package:flutter/material.dart';
import '../../../models/carousel_slide.dart';
import '../../../models/carousel_template_theme.dart';
import '../../carousel_detail_components.dart';
import '../slide_render_context.dart';

/// Layout 1: STACKED / EDITORIAL
/// Clean, non-overlapping layout for motivational quotes and guide posts.
class StackedBottomLayoutBuilder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final offX = slide.contentOffsetX;
    final offY = slide.contentOffsetY;

    final isDark = context.isDarkBackground;

    final titleColumn = context.buildTitleColumn();

    final bodyComponent = CarouselBodyComponent.fromTheme(
      bodyText: slide.bodyText,
      theme: theme,
      isDarkBackground: isDark,
    );

    // Calculate dynamic vertical placement to guarantee zero text collision
    const baseTitleTop = 82.0;
    final titleLength = slide.title.trim().length;
    const charsPerLine = 28;
    final titleLines = (titleLength / charsPerLine).ceil().clamp(1, 4);
    final isTag = theme.titleCardStyle == TitleCardStyle.editorialTag;
    final estimatedTitleHeight = (titleLines * (theme.titleFontSize * 1.25)) + (isTag ? 14.0 : 0.0);
    final baseBodyTop = (baseTitleTop + estimatedTitleHeight + 16.0).clamp(135.0, 240.0);

    final List<Widget> list = [];

    // Optional Card Backdrop Container
    if (theme.showCardBackdrop || theme.cardStyle != CardStyle.none) {
      final cardLeft = (14.0 + offX).clamp(-60.0, 100.0);
      final cardRight = (14.0 - offX).clamp(-60.0, 100.0);
      final cardTop = (66.0 + offY).clamp(20.0, 160.0);
      final cardBottom = (20.0 - offY).clamp(0.0, 160.0);
      list.add(
        Positioned(
          left: cardLeft,
          right: cardRight,
          top: cardTop,
          bottom: cardBottom,
          child: context.buildCardBackdrop(
            width: double.infinity,
            height: double.infinity,
            borderRadius: theme.cardBorderRadius,
          ),
        ),
      );
    }

    // 1. Title / Headline (Clean full-width layout)
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Headline',
        baseLeft: 20,
        baseRight: 20,
        baseTop: baseTitleTop,
        child: titleColumn,
      ),
    );

    // 2. Body Text / Quote (Placed cleanly below headline to prevent any overlap)
    if (theme.showBodyText && slide.bodyText.isNotEmpty) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.bodyText,
          label: 'Body Text',
          baseLeft: 20,
          baseRight: 20,
          baseTop: baseBodyTop,
          child: bodyComponent,
        ),
      );
    }

    return list;
  }
}
