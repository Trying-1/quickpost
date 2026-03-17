import 'package:flutter/material.dart';

import 'onboarding_page_template.dart';

class OnboardingPageWelcome extends StatelessWidget {
  const OnboardingPageWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      gradient: [
        Color(0xFF2D1B69),
        Color(0xFF7C3AED),
        Color(0xFFEC4899),
      ],
      heroIcon: Icons.auto_awesome,
      title: 'Welcome to QuickPost',
      description: 'Create polished content fast — posts, reels, and story assets in one place.',
      bullets: [
        'Generate ready-to-post templates',
        'Overlay captions and text on videos',
        'Keep audios + captions organized',
      ],
    );
  }
}
