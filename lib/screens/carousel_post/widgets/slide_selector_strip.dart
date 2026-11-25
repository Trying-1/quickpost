import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';

/// Horizontal ribbon showing all carousel slides as selectable thumbnails
/// styled to match the Quick Post light theme.
class SlideSelectorStrip extends StatelessWidget {
  final List<CarouselSlide> slides;
  final int activeIndex;
  final CarouselTemplateTheme theme;
  final ValueChanged<int> onSelectSlide;
  final VoidCallback onAddContentSlide;
  final ValueChanged<int> onDeleteSlide;

  const SlideSelectorStrip({
    super.key,
    required this.slides,
    required this.activeIndex,
    required this.theme,
    required this.onSelectSlide,
    required this.onAddContentSlide,
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
        itemCount: slides.length + 1,
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
    CarouselSlide slide,
    int index,
    bool isSelected,
  ) {
    IconData icon;
    String slideLabel;
    if (slide.type == SlideType.cover) {
      icon = Icons.auto_awesome_rounded;
      slideLabel = 'Cover';
    } else if (slide.type == SlideType.cta) {
      icon = Icons.chat_bubble_outline_rounded;
      slideLabel = 'CTA';
    } else {
      icon = Icons.article_rounded;
      slideLabel = '${index + 1}';
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
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or solid color
              if (slide.bgImagePath != null && File(slide.bgImagePath!).existsSync())
                Image.file(
                  File(slide.bgImagePath!),
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: isSelected ? AppColors.primarySurface : Colors.grey.shade100,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? AppColors.primary : Colors.grey.shade500,
                    ),
                  ),
                ),

              // Delete button (on long press or top right if content slide)
              if (slide.type == SlideType.content && slides.where((s) => s.type == SlideType.content).length > 1)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onDeleteSlide(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                ),

              // Bottom label chip
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Text(
                    slideLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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
    return InkWell(
      onTap: onAddContentSlide,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 60,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
            SizedBox(height: 2),
            Text(
              '+ Slide',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

