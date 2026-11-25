import 'package:flutter/material.dart';
import '../models/carousel_template_theme.dart';

/// Modular component for the Slide Number / Step Badge (e.g. #01, 1).
class CarouselNumberBadgeComponent extends StatelessWidget {
  final int number;
  final Color accentColor;
  final String? fontFamily;
  final RankBadgeStyle style;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselNumberBadgeComponent({
    super.key,
    required this.number,
    this.accentColor = const Color(0xFF0D9488),
    this.fontFamily,
    this.style = RankBadgeStyle.modernGradient,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  factory CarouselNumberBadgeComponent.fromTheme({
    Key? key,
    required int number,
    required CarouselTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return CarouselNumberBadgeComponent(
      key: key,
      number: number,
      accentColor: theme.getColorForComponent('numberBadge', defaultColor: theme.accentColor),
      fontFamily: theme.getFontForComponent('numberBadge', defaultFont: theme.titleFontFamily),
      style: theme.rankBadgeStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showNumberBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final label = '#${number.toString().padLeft(2, '0')}';

    switch (style) {
      case RankBadgeStyle.circularStamp:
        return Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: fontFamily,
            ),
          ),
        );

      case RankBadgeStyle.minimalOutlined:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accentColor, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isDarkBackground ? Colors.white : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: fontFamily,
            ),
          ),
        );

      case RankBadgeStyle.glassPill:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFamily: fontFamily,
            ),
          ),
        );

      case RankBadgeStyle.boldRibbon:
      case RankBadgeStyle.modernGradient:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
    }
  }
}

/// Modular component for the Main Body text or Quote description.
class CarouselBodyComponent extends StatelessWidget {
  final String bodyText;
  final Color accentColor;
  final Color? textColor;
  final String? fontFamily;
  final double fontSize;
  final SynopsisCardStyle style;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselBodyComponent({
    super.key,
    required this.bodyText,
    this.accentColor = const Color(0xFF0D9488),
    this.textColor,
    this.fontFamily,
    this.fontSize = 14.0,
    this.style = SynopsisCardStyle.cleanMinimal,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  factory CarouselBodyComponent.fromTheme({
    Key? key,
    required String bodyText,
    required CarouselTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return CarouselBodyComponent(
      key: key,
      bodyText: bodyText,
      accentColor: theme.getColorForComponent('bodyText', defaultColor: theme.accentColor),
      textColor: theme.bodyTextColor,
      fontFamily: theme.getFontForComponent('bodyText', defaultFont: theme.bodyFontFamily),
      fontSize: theme.bodyFontSize,
      style: theme.synopsisCardStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showBodyText,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || bodyText.trim().isEmpty) return const SizedBox.shrink();

    final effectiveColor = textColor ?? (isDarkBackground ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF334155));

    switch (style) {
      case SynopsisCardStyle.translucentBox:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDarkBackground ? Colors.black45 : Colors.white70,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: accentColor, width: 3.5),
            ),
          ),
          child: Text(
            bodyText,
            style: TextStyle(
              color: effectiveColor,
              fontSize: fontSize,
              height: 1.4,
              fontFamily: fontFamily,
            ),
          ),
        );

      case SynopsisCardStyle.floatingChip:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDarkBackground ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDarkBackground ? Colors.white12 : Colors.black12,
              width: 1,
            ),
          ),
          child: Text(
            bodyText,
            style: TextStyle(
              color: effectiveColor,
              fontSize: fontSize,
              height: 1.45,
              fontWeight: FontWeight.w400,
              fontFamily: fontFamily,
            ),
          ),
        );

      case SynopsisCardStyle.cleanMinimal:
      case SynopsisCardStyle.quoteQuoteMark:
      default:
        return Text(
          bodyText,
          style: TextStyle(
            color: effectiveColor,
            fontSize: fontSize,
            height: 1.45,
            fontWeight: FontWeight.w400,
            fontFamily: fontFamily,
            shadows: isDarkBackground && textColor == null
                ? const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
        );
    }
  }
}

/// Modular component for the Action Item / Key Takeaway box.
class CarouselTakeawayComponent extends StatelessWidget {
  final String takeaway;
  final Color accentColor;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselTakeawayComponent({
    super.key,
    required this.takeaway,
    this.accentColor = const Color(0xFF0D9488),
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  factory CarouselTakeawayComponent.fromTheme({
    Key? key,
    required String takeaway,
    required CarouselTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return CarouselTakeawayComponent(
      key: key,
      takeaway: takeaway,
      accentColor: theme.getColorForComponent('takeaway', defaultColor: theme.accentColor),
      fontFamily: theme.getFontForComponent('takeaway', defaultFont: theme.bodyFontFamily),
      isDarkBackground: isDarkBackground,
      isVisible: theme.showTakeaway,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || takeaway.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDarkBackground ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              takeaway,
              style: TextStyle(
                color: isDarkBackground ? Colors.white : const Color(0xFF0F172A),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontFamily: fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide Counter (e.g. 01 / 07).
class CarouselSlideCounterComponent extends StatelessWidget {
  final int current;
  final int total;
  final Color accentColor;
  final String? fontFamily;
  final SlideCounterStyle style;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselSlideCounterComponent({
    super.key,
    required this.current,
    required this.total,
    this.accentColor = const Color(0xFF0D9488),
    this.fontFamily,
    this.style = SlideCounterStyle.fractionPill,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  factory CarouselSlideCounterComponent.fromTheme({
    Key? key,
    required int current,
    required int total,
    required CarouselTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return CarouselSlideCounterComponent(
      key: key,
      current: current,
      total: total,
      accentColor: theme.getColorForComponent('slideCounter', defaultColor: theme.accentColor),
      fontFamily: theme.getFontForComponent('slideCounter', defaultFont: theme.bodyFontFamily),
      style: theme.slideCounterStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showSlideCounter,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final text = '${current.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkBackground ? Colors.black54 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDarkBackground ? Colors.white : const Color(0xFF1E293B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}

/// Brand Watermark / Handle (e.g. @app.quickpost).
class CarouselPageHandleComponent extends StatelessWidget {
  final String handle;
  final Color accentColor;
  final String? fontFamily;
  final HandleStyle style;
  final bool showVerifiedBadge;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselPageHandleComponent({
    super.key,
    required this.handle,
    this.accentColor = const Color(0xFF0D9488),
    this.fontFamily,
    this.style = HandleStyle.pillBadge,
    this.showVerifiedBadge = true,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  factory CarouselPageHandleComponent.fromTheme({
    Key? key,
    required String handle,
    required CarouselTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return CarouselPageHandleComponent(
      key: key,
      handle: handle,
      accentColor: theme.getColorForComponent('pageHandle', defaultColor: theme.accentColor),
      fontFamily: theme.getFontForComponent('pageHandle', defaultFont: theme.bodyFontFamily),
      style: theme.handleStyle,
      showVerifiedBadge: theme.showVerifiedBadge,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showWatermark,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || handle.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDarkBackground ? Colors.black45 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            handle,
            style: TextStyle(
              color: isDarkBackground ? Colors.white : const Color(0xFF0F172A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamily,
            ),
          ),
          if (showVerifiedBadge) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified, size: 12, color: accentColor),
          ],
        ],
      ),
    );
  }
}

/// Swipe Indicator Cue (e.g. Swipe to read ->).
class CarouselSwipeIndicatorComponent extends StatelessWidget {
  final String label;
  final Color accentColor;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselSwipeIndicatorComponent({
    super.key,
    required this.label,
    this.accentColor = const Color(0xFF0D9488),
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: accentColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward_rounded, size: 13, color: accentColor),
      ],
    );
  }
}

/// Hook Tag Component (e.g. DAILY WISDOM, GUIDE).
class CarouselHookTagComponent extends StatelessWidget {
  final String tag;
  final Color accentColor;
  final String? fontFamily;
  final HookTagStyle style;
  final bool isDarkBackground;
  final bool isVisible;

  const CarouselHookTagComponent({
    super.key,
    required this.tag,
    this.accentColor = const Color(0xFF0D9488),
    this.fontFamily,
    this.style = HookTagStyle.neonGlow,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  factory CarouselHookTagComponent.fromTheme({
    Key? key,
    required String tag,
    required CarouselTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return CarouselHookTagComponent(
      key: key,
      tag: tag,
      accentColor: theme.getColorForComponent('hookTag', defaultColor: theme.accentColor),
      fontFamily: theme.getFontForComponent('hookTag', defaultFont: theme.titleFontFamily),
      style: theme.hookTagStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showHookTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || tag.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        tag.toUpperCase(),
        style: TextStyle(
          color: accentColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}
