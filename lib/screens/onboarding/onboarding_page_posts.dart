import 'package:flutter/material.dart';

import 'onboarding_page_template.dart';

class OnboardingPagePosts extends StatelessWidget {
  const OnboardingPagePosts({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      gradient: [
        Color(0xFF0F172A),
        Color(0xFF1D4ED8),
        Color(0xFF06B6D4),
      ],
      heroIcon: Icons.photo_library_outlined,
      title: 'Create posts fast',
      description: 'Bulk crop images, build grids, and export clean templates made for social platforms.',
      bullets: [
        'Bulk crop images in one go',
        'Grid & story-ready layouts',
        'Templates that match your style',
      ],
    );
  }
}
