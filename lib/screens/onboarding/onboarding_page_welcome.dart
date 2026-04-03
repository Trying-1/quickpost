import 'package:flutter/material.dart';
import 'onboarding_page_template.dart';
import '../../config/app_theme.dart';

class OnboardingPageWelcome extends StatelessWidget {
  const OnboardingPageWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      heroIcon: Icons.auto_awesome_rounded,
      title: 'Welcome to QuickPost',
      subtitle: 'The all-in-one toolkit for modern creators and social managers.',
      accentColor: AppColors.primary,
      features: [
        FeatureItem(
          text: 'Professional Templates',
          detail: 'Design stunning posts in seconds',
          icon: Icons.dashboard_customize_rounded,
        ),
        FeatureItem(
          text: 'Advanced Video Tools',
          detail: 'Add captions, titles, and text overlays',
          icon: Icons.video_settings_rounded,
        ),
        FeatureItem(
          text: 'Smart Organization',
          detail: 'Manage your creative assets effortlessly',
          icon: Icons.inventory_2_rounded,
        ),
      ],
    );
  }
}

// Private classes were defined in template, but I'll use simple data here 
// because I redefined the template to accept a specific structure.
// Wait, I need to make sure the template's _FeatureItem and _FeatureRow are accessible if I use them, 
// or define them in the template file as public if I want to use 'const'.
// I'll update the template to make them public or just pass primitive data.
// Actually, I'll update the template to have them public.
