import 'package:flutter/material.dart';
import '../../../models/carousel_slide.dart';
import '../slide_render_context.dart';

/// Layout builder for CTA Outro slides in Carousel Posts.
class CtaSlideLayoutBuilder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final isDark = context.isDarkBackground;

    final List<Widget> list = [];

    // Calculate dynamic placement to prevent CTA headline & subheadline overlap
    const baseHeadTop = 110.0;
    final headLength = slide.ctaHeadline.trim().length;
    const charsPerLine = 24;
    final headLines = (headLength / charsPerLine).ceil().clamp(1, 4);
    final effectiveHeadFontSize = (theme.titleFontSize * 1.1).clamp(16.0, 38.0);
    final estimatedHeadHeight = headLines * (effectiveHeadFontSize * 1.25);
    final baseSubTop = (baseHeadTop + estimatedHeadHeight + 16.0).clamp(160.0, 250.0);

    // 1. CTA Headline
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Headline',
        baseLeft: 20,
        baseRight: 20,
        baseTop: baseHeadTop,
        child: Text(
          slide.ctaHeadline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
            color: context.effectiveTitleColor,
            fontSize: effectiveHeadFontSize,
            fontWeight: theme.titleFontWeight,
            height: 1.2,
            shadows: isDark && theme.titleTextColor == null
                ? const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 8)]
                : null,
          ),
        ),
      ),
    );

    // 2. CTA Subheadline (Positioned below headline to guarantee zero overlap)
    if (slide.ctaSubheadline.isNotEmpty) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.bodyText,
          label: 'Subheadline',
          baseLeft: 20,
          baseRight: 20,
          baseTop: baseSubTop,
          child: Text(
            slide.ctaSubheadline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.bodyText, defaultFont: theme.bodyFontFamily),
              color: context.effectiveBodyColor,
              fontSize: theme.bodyFontSize,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    // 3. Actions Ribbon (Swipe Indicator Component slot)
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.swipeIndicator,
        label: 'Actions Ribbon',
        baseLeft: 20,
        baseRight: 20,
        baseBottom: 40,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCtaActionItem(
                icon: Icons.bookmark_added_rounded,
                label: 'SAVE',
                color: theme.accentColor,
                fontFamily: theme.fontFamily,
              ),
              _buildCtaActionItem(
                icon: Icons.share_rounded,
                label: 'SHARE',
                color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155),
                fontFamily: theme.fontFamily,
              ),
              _buildCtaActionItem(
                icon: Icons.chat_bubble_rounded,
                label: 'COMMENT',
                color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155),
                fontFamily: theme.fontFamily,
              ),
            ],
          ),
        ),
      ),
    );

    return list;
  }

  static Widget _buildCtaActionItem({
    required IconData icon,
    required String label,
    required Color color,
    String? fontFamily,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }
}
