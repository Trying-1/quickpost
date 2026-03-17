import 'package:flutter/material.dart';

import 'onboarding_page_template.dart';

class OnboardingPageLibrary extends StatelessWidget {
  const OnboardingPageLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      gradient: [
        Color(0xFF052E16),
        Color(0xFF16A34A),
        Color(0xFF22C55E),
      ],
      heroIcon: Icons.library_music_outlined,
      title: 'Save your workflow',
      description: 'Keep audios and captions organized so posting becomes copy–paste simple.',
      bullets: [
        'Audio Library with folders',
        'Caption Store with variants',
        'Export/import backups anytime',
      ],
    );
  }
}
