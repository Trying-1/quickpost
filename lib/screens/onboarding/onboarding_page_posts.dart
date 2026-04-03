import 'package:flutter/material.dart';
import 'onboarding_page_template.dart';

class OnboardingPagePosts extends StatelessWidget {
  const OnboardingPagePosts({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      heroIcon: Icons.photo_library_rounded,
      title: 'Professional Post Maker',
      subtitle: 'Stop wasting time on manual design. Create stunning grids and stories instantly.',
      accentColor: const Color(0xFF0D47A1), // Blue accent for posts
      features: [
        FeatureItem(
          text: 'Bulk Image Cropper',
          detail: 'Adjust and crop dozens of images at once',
          icon: Icons.crop_rotate_rounded,
        ),
        FeatureItem(
          text: 'Grid & Story Layouts',
          detail: 'Clean, modern templates for every platform',
          icon: Icons.grid_view_rounded,
        ),
        FeatureItem(
          text: 'Visual Consistency',
          detail: 'Maintain your brand identity across all posts',
          icon: Icons.palette_rounded,
        ),
      ],
    );
  }
}
