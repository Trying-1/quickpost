import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../../../models/anime_template_theme.dart';
import '../slide_render_context.dart';
import 'cover_slide_layout.dart';
import 'cta_slide_layout.dart';
import 'layout1.dart';
import 'layout2.dart';
import 'layout3.dart';
import 'layout4.dart';
import 'layout5.dart';
import 'layout6.dart';
import 'layout7.dart';
import 'stacked_bottom_layout.dart';

/// Factory dispatcher selecting the appropriate modular slide layout builder.
class SlideLayoutFactory {
  static List<Widget> buildSlideContent(SlideRenderContext context) {
    final effectiveLayout = context.slide.getEffectiveLayout(context.theme);

    switch (context.slide.type) {
      case SlideType.cover:
        if (effectiveLayout == SlideLayout.layout2) {
          return Layout2Builder.build(context);
        } else if (effectiveLayout == SlideLayout.layout1) {
          return Layout1Builder.build(context);
        } else if (effectiveLayout == SlideLayout.layout3) {
          return Layout3Builder.build(context);
        } else if (effectiveLayout == SlideLayout.layout4) {
          return Layout4Builder.build(context);
        } else if (effectiveLayout == SlideLayout.layout5) {
          return Layout5Builder.build(context);
        } else if (effectiveLayout == SlideLayout.layout6) {
          return Layout6Builder.build(context);
        } else if (effectiveLayout == SlideLayout.layout7) {
          return Layout7Builder.build(context);
        }
        return CoverSlideLayoutBuilder.build(context);

      case SlideType.cta:
        return CtaSlideLayoutBuilder.build(context);

      case SlideType.anime:
        switch (effectiveLayout) {
          case SlideLayout.defaultLayout:
            return StackedBottomLayoutBuilder.build(context);
          case SlideLayout.layout1:
            return Layout1Builder.build(context);
          case SlideLayout.layout2:
            return Layout2Builder.build(context);
          case SlideLayout.layout3:
            return Layout3Builder.build(context);
          case SlideLayout.layout4:
            return Layout4Builder.build(context);
          case SlideLayout.layout5:
            return Layout5Builder.build(context);
          case SlideLayout.layout6:
            return Layout6Builder.build(context);
          case SlideLayout.layout7:
            return Layout7Builder.build(context);
        }
    }
  }
}
