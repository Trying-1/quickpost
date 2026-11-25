import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../carousel_post_screen.dart';
import '../countdown_post_screen.dart';
import '../quote_card_post_screen.dart';
import '../text_post_screen.dart';
import '../textbox_image_screen.dart';
import '../year_grid_post_screen.dart';

/// Metadata and route factory for a Post Maker template option.
class PostTemplateItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function(List<String>? sharedImagePaths) screenBuilder;

  const PostTemplateItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.screenBuilder,
  });
}

/// Central catalog of Post Maker templates.
class PostTemplateCatalog {
  const PostTemplateCatalog._();

  static final List<PostTemplateItem> items = [
    PostTemplateItem(
      id: 'quote_card_post',
      title: 'Quote Card',
      description: 'Theme-page quote card with full profile or @handle-only mode.',
      icon: Icons.format_quote,
      color: AppColors.primary,
      screenBuilder: (_) => const QuoteCardPostScreen(),
    ),
    PostTemplateItem(
      id: 'single_image_post',
      title: 'Textbox Image',
      description: 'Create a single-photo or 2x2 grid post with styled text box.',
      icon: Icons.photo_library_outlined,
      color: AppColors.primary,
      screenBuilder: (paths) => TextboxImageScreen(
        isGridMode: (paths?.length ?? 0) > 1,
        sharedImagePaths: paths,
        sharedPurpose:
            (paths?.length ?? 0) > 1 ? 'grid_post' : 'single_image_post',
      ),
    ),
    PostTemplateItem(
      id: 'carousel_post',
      title: 'Carousel Post',
      description: 'Create multi-slide posts. Edit each slide individually.',
      icon: Icons.view_carousel,
      color: Colors.amber,
      screenBuilder: (paths) => CarouselPostScreen(
        sharedImagePaths: paths,
        sharedPurpose: 'carousel_post',
      ),
    ),
    PostTemplateItem(
      id: 'text_post',
      title: 'Simple Text Post',
      description: 'Create a clean text post on a plain background.',
      icon: Icons.text_fields,
      color: Colors.teal,
      screenBuilder: (_) => const TextPostScreen(),
    ),
    PostTemplateItem(
      id: 'countdown_post',
      title: 'Daily Progress',
      description: 'Displays current date and counts days left in the year.',
      icon: Icons.timer_outlined,
      color: const Color(0xFF6C63FF),
      screenBuilder: (_) => const CountdownPostScreen(),
    ),
    PostTemplateItem(
      id: 'year_grid_post',
      title: 'Year Grid',
      description: '365-day visual grid to track your yearly journey.',
      icon: Icons.grid_on_rounded,
      color: const Color(0xFF2ECC71),
      screenBuilder: (_) => const YearGridPostScreen(),
    ),
  ];
}

