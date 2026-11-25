import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_template_theme.dart';
import 'anime_detail_components.dart';
import 'preview/film_grain_overlay.dart';
import 'preview/layouts/slide_layout_factory.dart';
import 'preview/slide_render_context.dart';

/// Renders a single slide of the anime carousel post.
/// Orchestrates canvas backgrounds, cinematic gradient overlays, top bar brand elements,
/// and delegates layout presentation to modular layout builders.
class AnimeSlidePreview extends StatelessWidget {
  final AnimeCarouselSlide slide;
  final AnimeTemplateTheme theme;
  final int slideIndex;
  final int totalSlides;
  final GlobalKey? repaintKey;
  final bool isInteractive;
  final String? activeComponentKey;
  final bool showSelectionOverlay;
  final ValueChanged<String>? onSelectComponent;
  final void Function(String componentKey, Offset delta)? onDragComponent;
  final ValueChanged<Offset>? onDragContent;
  final ValueChanged<Offset>? onDragHeader;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onTapCanvas;

  const AnimeSlidePreview({
    super.key,
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.totalSlides,
    this.repaintKey,
    this.isInteractive = false,
    this.activeComponentKey,
    this.showSelectionOverlay = true,
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
      showSelectionOverlay: showSelectionOverlay,
      onSelectComponent: onSelectComponent,
      onDragComponent: onDragComponent,
      onDragContent: onDragContent,
      onDragHeader: onDragHeader,
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
    );

    final effectiveLayout = slide.getEffectiveLayout(theme);
    final usesFullBleed = effectiveLayout.usesFullBleedBackground;

    return RepaintBoundary(
      key: repaintKey,
      child: AspectRatio(
        aspectRatio: theme.aspectRatioPreset.aspectValue,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTapCanvas?.call(),
          child: Container(
            decoration: BoxDecoration(
              color: theme.canvasBgColor,
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
                // 1. Background image / art (for full-bleed wallpaper layout)
                if (usesFullBleed)
                  _buildBackgroundImage(),

                // 2. Dark vignette & cinematic gradient overlays (for full-bleed layout)
                if (usesFullBleed)
                  _buildGradientOverlay(),

                // 3. Top bar: Brand watermark & slide counter (for standard stack layout)
                if (effectiveLayout == SlideLayout.defaultLayout)
                  ..._buildTopBarComponents(renderContext),

                // 4. Main Slide Content Area (Modular Layout Dispatcher)
                ...SlideLayoutFactory.buildSlideContent(renderContext),

                // 5. Cinematic Edge Vignette Overlay
                if (theme.enableVignette)
                  Positioned.fill(
                    child: VignetteOverlay(
                      intensity: theme.vignetteIntensity,
                    ),
                  ),

                // 6. 35mm Analog Film Grain Texture Overlay
                if (theme.enableFilmGrain)
                  Positioned.fill(
                    child: FilmGrainOverlay(
                      intensity: theme.filmGrainIntensity,
                    ),
                  ),
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
      return Container(color: theme.canvasBgColor);
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
            Colors.black.withValues(alpha: theme.gradientDarkness * 0.4),
            Colors.black.withValues(alpha: theme.gradientDarkness),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopBarComponents(SlideRenderContext context) {
    final hasImage = context.hasImage;
    final List<Widget> list = [];

    // 1. Watermark / Brand Handle
    if (theme.showWatermark) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.pageHandle,
          label: 'Watermark',
          baseLeft: 16,
          baseTop: 14,
          useGroupOffset: false,
          child: AnimePageHandleComponent.fromTheme(
            theme: theme,
            isDarkBackground: hasImage,
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
          baseTop: 14,
          useGroupOffset: false,
          child: AnimeSlideCounterComponent.fromTheme(
            slideIndex: slideIndex,
            totalSlides: totalSlides,
            theme: theme,
            isDarkBackground: hasImage,
          ),
        ),
      );
    }

    return list;
  }
}
