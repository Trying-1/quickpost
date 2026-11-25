import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/anime_carousel_slide.dart';
import '../../models/anime_template_theme.dart';
import '../anime_detail_components.dart';
import 'anime_card_backdrop.dart';
import 'canvas_positioned_component.dart';
import 'outlined_text.dart';

/// Encapsulates the runtime context, styling, and builder helpers
/// for rendering a slide's components across different layouts.
class SlideRenderContext {
  final AnimeCarouselSlide slide;
  final AnimeTemplateTheme theme;
  final int slideIndex;
  final int totalSlides;
  final bool isInteractive;
  final String? activeComponentKey;
  final bool showSelectionOverlay;
  final ValueChanged<String>? onSelectComponent;
  final void Function(String componentKey, Offset delta)? onDragComponent;
  final ValueChanged<Offset>? onDragContent;
  final ValueChanged<Offset>? onDragHeader;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  final bool hasImage;
  final Color effectiveTitleColor;
  final Color effectiveBodyColor;

  SlideRenderContext({
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.totalSlides,
    this.isInteractive = false,
    this.activeComponentKey,
    this.showSelectionOverlay = true,
    this.onSelectComponent,
    this.onDragComponent,
    this.onDragContent,
    this.onDragHeader,
    this.onDragStart,
    this.onDragEnd,
  })  : hasImage = slide.imagePath != null && File(slide.imagePath!).existsSync(),
        effectiveTitleColor = theme.titleTextColor ??
            (slide.getEffectiveLayout(theme).usesFullBleedBackground
                ? ((slide.imagePath != null && File(slide.imagePath!).existsSync())
                    ? Colors.white
                    : const Color(0xFF1E293B))
                : (theme.canvasBgColor.computeLuminance() < 0.5
                    ? Colors.white
                    : const Color(0xFF111827))),
        effectiveBodyColor = theme.bodyTextColor ??
            (slide.getEffectiveLayout(theme).usesFullBleedBackground
                ? ((slide.imagePath != null && File(slide.imagePath!).existsSync())
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF475569))
                : (theme.canvasBgColor.computeLuminance() < 0.5
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF4B5563)));

  /// Builds an absolute positioned component with drag handles and selection styling.
  Widget buildPositioned({
    required String componentId,
    required String label,
    required Widget child,
    double? baseLeft,
    double? baseRight,
    double? baseTop,
    double? baseBottom,
    double? width,
    double? height,
    bool allowHorizontal = true,
    bool allowVertical = true,
    bool useGroupOffset = true,
    double groupYFactor = 1.0,
  }) {
    Widget effectiveChild = child;
    if (componentId == SlideComponentId.heroVisual && theme.enableAmbientGlow) {
      effectiveChild = buildHeroAmbientGlowStack(child: child);
    }

    return CanvasPositionedComponent(
      slide: slide,
      componentId: componentId,
      label: label,
      baseLeft: baseLeft,
      baseRight: baseRight,
      baseTop: baseTop,
      baseBottom: baseBottom,
      width: width,
      height: height,
      allowHorizontal: allowHorizontal,
      allowVertical: allowVertical,
      useGroupOffset: useGroupOffset,
      groupYFactor: groupYFactor,
      isInteractive: isInteractive,
      activeComponentKey: activeComponentKey,
      showSelectionOverlay: showSelectionOverlay,
      onSelectComponent: onSelectComponent,
      onDragComponent: onDragComponent,
      onDragContent: onDragContent,
      onDragHeader: onDragHeader,
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
      child: effectiveChild,
    );
  }

  /// Wraps a hero visual card with a soft, diffused ambient backlight glow
  /// sampled directly from the anime artwork or accent color.
  Widget buildHeroAmbientGlowStack({required Widget child, BorderRadius? borderRadius}) {
    if (!theme.enableAmbientGlow) return child;

    final intensity = theme.ambientGlowIntensity.clamp(0.0, 1.0);
    final blur = theme.ambientGlowBlur.clamp(5.0, 80.0);
    final spread = theme.ambientGlowSpread;
    final radius = borderRadius ??
        BorderRadius.circular(theme.getBorderRadiusForComponent(SlideComponentId.heroVisual, defaultRadius: 16.0));

    Widget glowVisual;
    if (hasImage) {
      glowVisual = Image.file(
        File(slide.imagePath!),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    } else {
      glowVisual = Container(
        decoration: BoxDecoration(
          color: theme.accentColor,
          borderRadius: radius,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          top: -spread,
          bottom: -spread,
          left: -spread,
          right: -spread,
          child: IgnorePointer(
            child: Opacity(
              opacity: intensity,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: glowVisual,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  /// Builds standard title and Japanese title column with selectable title card style.
  Widget buildTitleColumn({double? customFontSize, bool centered = false}) {
    final titleStyle = theme.titleCardStyle;
    final isBanner = titleStyle == TitleCardStyle.editorialTag;
    final textColor = isBanner ? Colors.white : effectiveTitleColor;

    final titleStrokeOnly = theme.isTextStrokeOnly(SlideComponentId.title);
    final titleStrokeWidth = theme.getTextStrokeWidth(
      SlideComponentId.title,
      defaultWidth: titleStrokeOnly ? 1.5 : 0.0,
    );
    final titleStrokeColor = theme.getTextStrokeColor(
      SlideComponentId.title,
      defaultColor: theme.accentColor,
    );

    final column = Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedText(
          text: slide.animeName,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
            fontSize: customFontSize ?? theme.titleFontSize,
            fontWeight: theme.titleFontWeight,
            height: 1.15,
          ),
          fillColor: textColor,
          strokeOnly: titleStrokeOnly,
          strokeWidth: titleStrokeWidth,
          strokeColor: titleStrokeColor,
          shadows: (hasImage && theme.titleTextColor == null && !isBanner && !titleStrokeOnly)
              ? const [Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 6)]
              : null,
        ),
        AnimeJapaneseTitleComponent(
          title: slide.japaneseName,
          fontFamily: theme.getFontForComponent(SlideComponentId.japaneseTitle, defaultFont: theme.bodyFontFamily),
          isDarkBackground: isBanner ? true : hasImage,
          isVisible: theme.showJapaneseTitle,
          isStrokeOnly: theme.isTextStrokeOnly(SlideComponentId.japaneseTitle),
          strokeWidth: theme.getTextStrokeWidth(SlideComponentId.japaneseTitle),
          strokeColor: theme.getTextStrokeColor(SlideComponentId.japaneseTitle, defaultColor: theme.accentColor),
        ),
        if (titleStyle == TitleCardStyle.accentUnderline)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 3.0,
            width: 36.0,
            decoration: BoxDecoration(
              color: theme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );

    Widget result = column;

    if (titleStyle == TitleCardStyle.glassBackplate) {
      result = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasImage ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasImage ? Colors.white.withValues(alpha: 0.2) : Colors.black12,
            width: 0.8,
          ),
        ),
        child: column,
      );
    } else if (titleStyle == TitleCardStyle.editorialTag) {
      result = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.accentColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: column,
      );
    }

    if (centered) {
      return SizedBox(
        width: double.infinity,
        child: Center(child: result),
      );
    }
    return result;
  }

  /// Builds a decorative card backdrop container.
  Widget buildCardBackdrop({
    required double width,
    required double height,
    double? borderRadius,
  }) {
    return AnimeCardBackdrop(
      theme: theme,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Builds a visual drag handle widget (deprecated and hidden).
  Widget buildDragHandle({String label = 'Drag to position'}) {
    return const SizedBox.shrink();
  }

  /// Applies custom background fill, border, radius, padding, and shadow overrides around child widget
  Widget wrapComponentBox({
    required String componentId,
    required Widget child,
    Color? defaultBgColor,
    double defaultRadius = 8.0,
    Color? defaultBorderColor,
    double defaultBorderWidth = 0.0,
    EdgeInsets? defaultPadding,
    bool defaultShadow = false,
  }) {
    final customBg = theme.getEffectiveBgColor(componentId, defaultColor: defaultBgColor);
    final customRadius = theme.getBorderRadiusForComponent(componentId, defaultRadius: defaultRadius);
    final customBorderColor = theme.getBorderColorForComponent(componentId, defaultColor: defaultBorderColor);
    final customBorderWidth = theme.getBorderWidthForComponent(componentId, defaultWidth: defaultBorderWidth) ?? 0.0;
    final customPaddingVal = theme.componentPaddings[componentId];
    final padding = customPaddingVal != null
        ? EdgeInsets.symmetric(horizontal: customPaddingVal, vertical: (customPaddingVal * 0.5).clamp(2.0, 16.0))
        : defaultPadding;
    final hasShadow = theme.hasShadowForComponent(componentId, defaultShadow: defaultShadow);

    final isDark = theme.canvasBgColor.computeLuminance() < 0.5;

    if (customBg == null && customBorderWidth <= 0 && !hasShadow && padding == null) {
      return child;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: customBg,
        borderRadius: BorderRadius.circular(customRadius),
        border: customBorderWidth > 0
            ? Border.all(
                color: customBorderColor ?? (isDark ? Colors.white24 : Colors.black12),
                width: customBorderWidth,
              )
            : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  /// Builds styled text for a component honoring all custom typography, colors, and outlines
  Widget buildStyledText({
    required String componentId,
    required String text,
    String? defaultFont,
    double? defaultFontSize,
    FontWeight defaultFontWeight = FontWeight.normal,
    double defaultLetterSpacing = 0.0,
    Color? defaultColor,
    TextAlign textAlign = TextAlign.start,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
    bool allowStroke = true,
  }) {
    final font = theme.getFontForComponent(componentId, defaultFont: defaultFont);
    final fontSize = theme.getFontSizeForComponent(componentId, defaultSize: defaultFontSize ?? 13.0);
    final fontWeight = theme.getFontWeightForComponent(componentId, defaultWeight: defaultFontWeight);
    final letterSpacing = theme.getLetterSpacingForComponent(componentId, defaultSpacing: defaultLetterSpacing);
    final color = theme.getColorForComponent(componentId, defaultColor: defaultColor) ??
        (componentId == SlideComponentId.title ? effectiveTitleColor : effectiveBodyColor);

    final strokeOnly = allowStroke && theme.isTextStrokeOnly(componentId);
    final strokeWidth = allowStroke ? theme.getTextStrokeWidth(componentId, defaultWidth: strokeOnly ? 1.5 : 0.0) : 0.0;
    final strokeColor = allowStroke ? theme.getTextStrokeColor(componentId, defaultColor: theme.accentColor) : Colors.transparent;

    final style = TextStyle(
      fontFamily: font,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1.2,
    );

    if (allowStroke && (strokeOnly || strokeWidth > 0)) {
      return OutlinedText(
        text: text,
        textAlign: textAlign,
        style: style,
        fillColor: color,
        strokeOnly: strokeOnly,
        strokeWidth: strokeWidth,
        strokeColor: strokeColor,
      );
    }

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style.copyWith(color: color),
    );
  }
}
