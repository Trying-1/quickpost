import 'dart:io';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_template_theme.dart';

/// Horizontal ribbon showing all carousel slides as selectable thumbnails
/// styled to match the Quick Post light theme.
class SlideSelectorStrip extends StatelessWidget {
  final List<AnimeCarouselSlide> slides;
  final int activeIndex;
  final AnimeTemplateTheme theme;
  final ValueChanged<int> onSelectSlide;
  final VoidCallback onAddAnimeSlide;
  final ValueChanged<int> onDeleteSlide;

  const SlideSelectorStrip({
    super.key,
    required this.slides,
    required this.activeIndex,
    required this.theme,
    required this.onSelectSlide,
    required this.onAddAnimeSlide,
    required this.onDeleteSlide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: slides.length + 1, // +1 for "Add Anime Slide" button
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == slides.length) {
            return _buildAddSlideButton();
          }
          final slide = slides[index];
          final isSelected = index == activeIndex;
          return _buildSlideThumbnail(context, slide, index, isSelected);
        },
      ),
    );
  }

  Widget _buildSlideThumbnail(
    BuildContext context,
    AnimeCarouselSlide slide,
    int index,
    bool isSelected,
  ) {
    IconData icon;
    String slideLabel;
    if (slide.type == SlideType.cover) {
      icon = Icons.movie_filter_rounded;
      slideLabel = 'Cover';
    } else if (slide.type == SlideType.cta) {
      icon = Icons.chat_bubble_outline_rounded;
      slideLabel = 'CTA';
    } else {
      icon = Icons.tv_rounded;
      slideLabel = '#${slide.rank}';
    }

    return GestureDetector(
      onTap: () => onSelectSlide(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.5),
          child: Stack(
            children: [
              // Background image preview if available
              if (slide.imagePath != null && File(slide.imagePath!).existsSync())
                Positioned.fill(
                  child: Image.file(
                    File(slide.imagePath!),
                    fit: BoxFit.cover,
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Icon(
                        icon,
                        size: 22,
                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),

              // Bottom slide label overlay for instant identification
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Text(
                    slideLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Delete button top-right (only if more than 3 slides)
              if (slides.length > 3 && slide.type == SlideType.anime)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onDeleteSlide(index),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddSlideButton() {
    return GestureDetector(
      onTap: onAddAnimeSlide,
      child: Container(
        width: 60,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Add Slide',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
