import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../../models/carousel_template_theme.dart';
import '../carousel_detail_components.dart';
import 'carousel_card_backdrop.dart';
import 'canvas_positioned_component.dart';
import 'drag_handle_indicator.dart';

/// Encapsulates the runtime context, styling, and builder helpers
/// for rendering a slide's components across different layouts.
class SlideRenderContext {
  final CarouselSlide slide;
  final CarouselTemplateTheme theme;
  final int slideIndex;
  final int totalSlides;
  final bool isInteractive;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;
  final void Function(String componentKey, Offset delta)? onDragComponent;
  final ValueChanged<Offset>? onDragContent;
  final ValueChanged<Offset>? onDragHeader;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  final bool hasImage;
  final bool isDarkBackground;
  final Color effectiveTitleColor;
  final Color effectiveBodyColor;

  SlideRenderContext({
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.totalSlides,
    this.isInteractive = false,
    this.activeComponentKey,
    this.onSelectComponent,
    this.onDragComponent,
    this.onDragContent,
    this.onDragHeader,
    this.onDragStart,
    this.onDragEnd,
  })  : hasImage = slide.imagePath != null && File(slide.imagePath!).existsSync(),
        isDarkBackground = (slide.imagePath != null && File(slide.imagePath!).existsSync()) ||
            (theme.canvasBackgroundColor.computeLuminance() < 0.45),
        effectiveTitleColor = theme.getColorForComponent(
          SlideComponentId.title,
          defaultColor: theme.titleTextColor ??
              (((slide.imagePath != null && File(slide.imagePath!).existsSync()) ||
                      (theme.canvasBackgroundColor.computeLuminance() < 0.45))
                  ? Colors.white
                  : const Color(0xFF0F172A)),
        ),
        effectiveBodyColor = theme.getColorForComponent(
          SlideComponentId.bodyText,
          defaultColor: theme.bodyTextColor ??
              (((slide.imagePath != null && File(slide.imagePath!).existsSync()) ||
                      (theme.canvasBackgroundColor.computeLuminance() < 0.45))
                  ? Colors.white.withValues(alpha: 0.90)
                  : const Color(0xFF334155)),
        );

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
      onSelectComponent: onSelectComponent,
      onDragComponent: onDragComponent,
      onDragContent: onDragContent,
      onDragHeader: onDragHeader,
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
      child: child,
    );
  }

  /// Builds standard headline and subtitle / author column with selectable title card style.
  Widget buildTitleColumn({double? customFontSize}) {
    final titleStyle = theme.titleCardStyle;
    final isBanner = titleStyle == TitleCardStyle.editorialTag;
    final textColor = isBanner ? Colors.white : effectiveTitleColor;
    final fontSize = customFontSize ?? theme.titleFontSize;

    Widget titleTextWidget = Text(
      slide.title,
      style: TextStyle(
        fontFamily: theme.getFontForComponent(SlideComponentId.title, defaultFont: theme.titleFontFamily),
        color: textColor,
        fontSize: fontSize,
        fontWeight: theme.titleFontWeight,
        height: 1.15,
        shadows: hasImage && theme.titleTextColor == null && !isBanner
            ? const [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 6)]
            : null,
      ),
    );

    if (titleStyle == TitleCardStyle.editorialTag) {
      titleTextWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.accentColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: titleTextWidget,
      );
    } else if (titleStyle == TitleCardStyle.neonUnderline) {
      titleTextWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleTextWidget,
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: 45,
            decoration: BoxDecoration(
              color: theme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );
    }

    return titleTextWidget;
  }

  /// Builds a responsive card backdrop widget for layouts.
  Widget buildCardBackdrop({
    required double width,
    required double height,
    double? borderRadius,
  }) {
    return CarouselCardBackdrop(
      theme: theme,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

