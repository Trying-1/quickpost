import 'package:flutter/material.dart';
import 'onboarding_page_template.dart';

class OnboardingPageVideoText extends StatelessWidget {
  const OnboardingPageVideoText({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      title: 'Powerful Video Tools',
      subtitle: 'Add professional captions and overlays optimized for Shorts, Reels, and TikTok.',
      accentColor: const Color(0xFFE65100), // Orange accent for video
      features: [
        FeatureItem(
          text: 'Dynamic Text Overlays',
          detail: 'Perfectly positioned titles and highlights',
          icon: Icons.text_fields_rounded,
        ),
        FeatureItem(
          text: 'Precision Watermarking',
          detail: 'Protect your content with custom branding',
          icon: Icons.branding_watermark_rounded,
        ),
        FeatureItem(
          text: 'Video Cropping',
          detail: 'Smart aspect ratios for social media',
          icon: Icons.video_label_rounded,
        ),
      ],
    );
  }
}
