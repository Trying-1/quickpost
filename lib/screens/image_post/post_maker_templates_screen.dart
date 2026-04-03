import '../../config/app_theme.dart';
import 'package:flutter/material.dart';

import 'grid_post_screen.dart';
import 'single_image_post_screen.dart';
import 'text_post_screen.dart';
import 'instagram_quote_post_screen.dart';
import 'instagram_quote_post_screen2.dart';
import 'carousel_post_screen.dart';
import 'countdown_post_screen.dart';
import 'year_grid_post_screen.dart';

class PostMakerTemplatesScreen extends StatelessWidget {
  final List<String>? sharedImagePaths;

  const PostMakerTemplatesScreen({
    super.key,
    this.sharedImagePaths,
  });

  @override
  Widget build(BuildContext context) {
    final templates = [
      _TemplateTileData(
        id: 'ig_quote_post',
        title: 'IG Quote Post',
        description: 'Theme-page style quote card with handle and avatar.',
        icon: Icons.format_quote,
        color: AppColors.primary,
      ),
      _TemplateTileData(
        id: 'ig_quote_handle_post',
        title: 'IG Quote (Handle Only)',
        description: 'Quote card with just your @handle, no avatar.',
        icon: Icons.alternate_email,
        color: AppColors.primaryDark,
      ),
      _TemplateTileData(
        id: 'single_image_post',
        title: 'Single Image Post',
        description: 'Create a post with one main image and text overlay.',
        icon: Icons.image,
        color: AppColors.primary,
      ),
      _TemplateTileData(
        id: 'carousel_post',
        title: 'Carousel Post',
        description: 'Create multi-slide posts. Edit each slide individually.',
        icon: Icons.view_carousel,
        color: Colors.amber,
      ),
      _TemplateTileData(
        id: 'grid_post',
        title: 'Grid Post',
        description: 'Arrange multiple images in a clean grid layout.',
        icon: Icons.grid_view,
        color: AppColors.primary,
      ),
      _TemplateTileData(
        id: 'text_post',
        title: 'Simple Text Post',
        description: 'Create a clean text post on a plain background.',
        icon: Icons.text_fields,
        color: Colors.teal,
      ),
      _TemplateTileData(
        id: 'countdown_post',
        title: 'Daily Progress',
        description: 'Displays current date and counts days left in the year.',
        icon: Icons.timer_outlined,
        color: const Color(0xFF6C63FF),
      ),
      _TemplateTileData(
        id: 'year_grid_post',
        title: 'Year Grid',
        description: '365-day visual grid to track your yearly journey.',
        icon: Icons.grid_on_rounded,
        color: const Color(0xFF2ECC71),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a template'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // Adjusted childAspectRatio to accommodate 4:5 image + text
            childAspectRatio: 0.65,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final t = templates[index];
            return _TemplateTile(
              data: t,
              onTap: () {
                switch (t.id) {
                  case 'grid_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GridPostScreen(
                          sharedImagePaths: sharedImagePaths,
                          sharedPurpose: 'grid_post',
                        ),
                      ),
                    );
                    break;
                  case 'ig_quote_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InstagramQuotePostScreen(),
                      ),
                    );
                    break;
                  case 'ig_quote_handle_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InstagramQuoteHandlePostScreen(),
                      ),
                    );
                    break;
                  case 'text_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TextPostScreen(),
                      ),
                    );
                    break;
                  case 'countdown_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CountdownPostScreen(),
                      ),
                    );
                    break;
                  case 'year_grid_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const YearGridPostScreen(),
                      ),
                    );
                    break;
                  case 'carousel_post':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CarouselPostScreen(
                          sharedImagePaths: sharedImagePaths,
                          sharedPurpose: 'carousel_post',
                        ),
                      ),
                    );
                    break;
                  case 'single_image_post':
                  default:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SingleImagePostScreen(
                          sharedImagePaths: sharedImagePaths,
                          sharedPurpose: 'single_image_post',
                        ),
                      ),
                    );
                    break;
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _TemplateTileData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _TemplateTileData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _TemplateTile extends StatelessWidget {
  final _TemplateTileData data;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Map template IDs to preview images
    String? previewAsset;
    switch (data.id) {
      case 'ig_quote_post':
      case 'ig_quote_handle_post':
        previewAsset = 'assets/images/post_template_images/qp_preview1.jpeg';
        break;
      case 'single_image_post':
        previewAsset = 'assets/images/post_template_images/single_image_post.jpg';
        break;
      case 'grid_post':
        previewAsset = 'assets/images/post_template_images/grid_image_post.jpg';
        break;
      case 'text_post':
      case 'countdown_post':
      case 'year_grid_post':
      default:
        previewAsset = 'assets/images/post_template_images/simple_text_post.jpg';
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Full-card preview area (image or gradient fallback)
                    Positioned.fill(
                      child: previewAsset != null
                          ? Image.asset(
                              previewAsset,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    data.color.withOpacity(0.24),
                                    data.color.withOpacity(0.06),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                    ),
                    // HOT badge removed
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
