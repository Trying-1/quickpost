import 'package:flutter/material.dart';
import 'onboarding_page_template.dart';

class OnboardingPageLibrary extends StatelessWidget {
  const OnboardingPageLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      heroIcon: Icons.library_music_rounded,
      title: 'Content Library',
      subtitle: 'Your personal vault for tracks and captions. Copy-paste has never been easier.',
      accentColor: const Color(0xFF1B5E20), // Green accent for library
      features: [
        FeatureItem(
          text: 'Audio Folder System',
          detail: 'Organize your trending music and SFX',
          icon: Icons.folder_special_rounded,
        ),
        FeatureItem(
          text: 'Caption Store',
          detail: 'Save your best performing copy and hashtags',
          icon: Icons.closed_caption_rounded,
        ),
        FeatureItem(
          text: 'Cloud Backup',
          detail: 'Import and export your entire workflow',
          icon: Icons.cloud_done_rounded,
        ),
      ],
    );
  }
}
