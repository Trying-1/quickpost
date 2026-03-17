import 'package:flutter/material.dart';

import 'onboarding_page_template.dart';

class OnboardingPageVideoText extends StatelessWidget {
  const OnboardingPageVideoText({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      gradient: [
        Color(0xFF111827),
        Color(0xFF7C3AED),
        Color(0xFFF97316),
      ],
      heroIcon: Icons.subtitles_outlined,
      title: 'Video text overlays',
      description: 'Add captions, titles, and text boxes with precise positioning — perfect for Reels and Shorts.',
      bullets: [
        'Text boxes + captions on video',
        'Works great for Shorts/Reels',
        'Preview exactly how it exports',
      ],
    );
  }
}
