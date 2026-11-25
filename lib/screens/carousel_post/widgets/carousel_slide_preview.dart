import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';
import 'carousel_detail_components.dart';
import 'preview/layouts/slide_layout_factory.dart';
import 'preview/slide_render_context.dart';

/// Renders a single slide of the Carousel Post.
/// Orchestrates canvas backgrounds, cinematic gradient overlays, top bar brand elements,
/// and delegates layout presentation to modular layout builders.
class CarouselSlidePreview extends StatelessWidget {
  final CarouselSlide slide;
  final CarouselTemplateTheme theme;
  final int slideIndex;
  final int totalSlides;
  final GlobalKey? repaintKey;
  final bool isInteractive;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;
  final void Function(String componentKey, Offset delta)? onDragComponent;
  final ValueChanged<Offset>? onDragContent;
  final ValueChanged<Offset>? onDragHeader;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onTapCanvas;

  const CarouselSlidePreview({
    super.key,
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.totalSlides,
    this.repaintKey,
    this.isInteractive = false,
    this.activeComponentKey,
    this.onSelectComponent,
    this.onDragComponent,
    this.onDragContent,
    this.onDragHeader,
    this.onDragStart,
    this.onDragEnd,
    this.onTapCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final renderContext = SlideRenderContext(
      slide: slide,
      theme: theme,
      slideIndex: slideIndex,
      totalSlides: totalSlides,
      isInteractive: isInteractive,
      activeComponentKey: activeComponentKey,
      onSelectComponent: onSelectComponent,
      onDragComponent: onDragComponent,
      onDragContent: onDragContent,
      onDragHeader: onDragHeader,
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
    );

    return RepaintBoundary(
      key: repaintKey,
      child: AspectRatio(
        aspectRatio: theme.aspectRatioPreset.ratio,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTapCanvas?.call(),
          child: Container(
            decoration: BoxDecoration(
              color: theme.canvasBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background image / art
                _buildBackgroundImage(),

                // 2. Dark vignette & cinematic gradient overlays
                _buildGradientOverlay(),

                // 3. Top bar: Brand watermark & slide counter
                ..._buildTopBarComponents(renderContext),

                // 4. Main Slide Content Area (Modular Layout Dispatcher)
                ...SlideLayoutFactory.buildSlideContent(renderContext),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    final hasImage = slide.imagePath != null && File(slide.imagePath!).existsSync();
    if (!hasImage) {
      return Container(color: theme.canvasBackgroundColor);
    }

    Widget imageWidget = Image.file(
      File(slide.imagePath!),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );

    if (theme.backgroundBlur > 0) {
      imageWidget = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: theme.backgroundBlur,
          sigmaY: theme.backgroundBlur,
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildGradientOverlay() {
    final hasImage = slide.imagePath != null && File(slide.imagePath!).existsSync();
    if (!hasImage) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 0.75, 1.0],
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: (1.0 - theme.backgroundBrightness) * 0.7),
            Colors.black.withValues(alpha: (1.0 - theme.backgroundBrightness)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopBarComponents(SlideRenderContext context) {
    final isDark = context.isDarkBackground;
    final headerY = slide.headerOffsetY.clamp(0.0, 100.0);

    final List<Widget> list = [];

    // 1. Watermark / Brand Handle
    if (theme.showWatermark) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.pageHandle,
          label: 'Watermark',
          baseLeft: 16,
          baseTop: 14 + headerY,
          useGroupOffset: false,
          child: CarouselPageHandleComponent.fromTheme(
            handle: theme.watermarkHandle,
            theme: theme,
            isDarkBackground: isDark,
          ),
        ),
      );
    }

    // 2. Slide Counter
    if (theme.showSlideCounter) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.slideCounter,
          label: 'Slide No',
          baseRight: 16,
          baseTop: 14 + headerY,
          useGroupOffset: false,
          child: CarouselSlideCounterComponent.fromTheme(
            current: slideIndex + 1,
            total: totalSlides,
            theme: theme,
            isDarkBackground: isDark,
          ),
        ),
      );
    }

    return list;
  }
}

