import 'package:flutter/material.dart';
import 'onboarding_page_template.dart';
import '../../config/app_theme.dart';

class OnboardingPageFinal extends StatelessWidget {
  const OnboardingPageFinal({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      heroIcon: Icons.rocket_launch_rounded,
      title: 'Ready to Create?',
      subtitle: 'Join creators who use QuickPost to grow their digital presence.',
      accentColor: AppColors.primary,
      features: [
        FeatureItem(
          text: 'No Account Needed',
          detail: 'Start creating immediately, no signup required',
          icon: Icons.person_off_rounded,
        ),
        FeatureItem(
          text: 'Privacy First',
          detail: 'Your data stays on your device',
          icon: Icons.security_rounded,
        ),
        FeatureItem(
          text: 'Everything Unlockable',
          detail: 'All premium features at your fingertips',
          icon: Icons.stars_rounded,
        ),
      ],
    );
  }
}
