import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../slide_render_context.dart';

/// Layout builder for CTA Outro slides.
class CtaSlideLayoutBuilder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final offX = slide.contentOffsetX;
    final offY = slide.contentOffsetY;

    final List<Widget> list = [];

    // 1. CTA Headline
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Headline',
        baseLeft: 20,
        baseRight: 20,
        baseBottom: 170,
        child: Text(
          slide.ctaHeadline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
            color: context.effectiveTitleColor,
            fontSize: (theme.titleFontSize * 1.1).clamp(16.0, 38.0),
            fontWeight: theme.titleFontWeight,
            height: 1.2,
            shadows: hasImage && theme.titleTextColor == null
                ? const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 8)]
                : null,
          ),
        ),
      ),
    );

    // 2. CTA Subheadline
    if (slide.ctaSubheadline.isNotEmpty) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.synopsis,
          label: 'Subheadline',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 130,
          child: Text(
            slide.ctaSubheadline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.getFontForComponent(SlideComponentId.synopsis, defaultFont: theme.bodyFontFamily),
              color: context.effectiveBodyColor,
              fontSize: theme.bodyFontSize,
              height: 1.3,
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
        baseBottom: 50,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: hasImage ? Colors.black.withValues(alpha: 0.5) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.3),
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
                hasImage: hasImage,
                fontFamily: theme.fontFamily,
              ),
              _buildCtaActionItem(
                icon: Icons.share_rounded,
                label: 'SHARE',
                color: hasImage ? Colors.white : const Color(0xFF334155),
                hasImage: hasImage,
                fontFamily: theme.fontFamily,
              ),
              _buildCtaActionItem(
                icon: Icons.chat_bubble_rounded,
                label: 'COMMENT',
                color: hasImage ? Colors.white : const Color(0xFF334155),
                hasImage: hasImage,
                fontFamily: theme.fontFamily,
              ),
              _buildCtaActionItem(
                icon: Icons.favorite_rounded,
                label: 'LIKE',
                color: const Color(0xFFFF4081),
                hasImage: hasImage,
                fontFamily: theme.fontFamily,
              ),
            ],
          ),
        ),
      ),
    );

    // 4. Follow prompt
    list.add(
      Positioned(
        left: (20 + offX).clamp(-60.0, 300.0),
        right: (20 - offX).clamp(-60.0, 300.0),
        bottom: (18 - offY).clamp(-60.0, 450.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Follow for daily anime updates: ',
              style: TextStyle(
                fontFamily: theme.fontFamily,
                color: context.effectiveBodyColor.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            Text(
              '@${theme.watermarkText}',
              style: TextStyle(
                fontFamily: theme.fontFamily,
                color: theme.accentColor,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    return list;
  }

  static Widget _buildCtaActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool hasImage,
    required String fontFamily,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            color: hasImage ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF475569),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
