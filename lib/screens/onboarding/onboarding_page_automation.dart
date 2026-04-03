import 'package:flutter/material.dart';
import 'onboarding_page_template.dart';
import '../../config/app_theme.dart';

class OnboardingPageAutomation extends StatelessWidget {
  const OnboardingPageAutomation({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageTemplate(
      heroIcon: Icons.auto_mode_rounded,
      title: 'Smart Automation',
      subtitle: 'Let the app do the heavy lifting. Generate batches of content in minutes.',
      accentColor: AppColors.primary,
      features: [
        FeatureItem(
          text: 'Batch Processing',
          detail: 'Avoid repetitive tasks with smart workflows',
          icon: Icons.bolt_rounded,
        ),
        FeatureItem(
          text: 'Content Scheduling',
          detail: 'Plan and prepare your posts in advance',
          icon: Icons.calendar_month_rounded,
        ),
        FeatureItem(
          text: 'Consistent Growth',
          detail: 'Always have high-quality content ready',
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }
}
