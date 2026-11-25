import 'package:flutter/material.dart';
import '../../../models/carousel_slide.dart';
import '../slide_render_context.dart';
import 'cover_slide_layout.dart';
import 'cta_slide_layout.dart';
import 'stacked_bottom_layout.dart';

/// Factory dispatcher selecting the appropriate slide layout builder.
class SlideLayoutFactory {
  static List<Widget> buildSlideContent(SlideRenderContext context) {
    switch (context.slide.type) {
      case SlideType.cover:
        return CoverSlideLayoutBuilder.build(context);
      case SlideType.cta:
        return CtaSlideLayoutBuilder.build(context);
      case SlideType.content:
        return StackedBottomLayoutBuilder.build(context);
    }
  }
}

