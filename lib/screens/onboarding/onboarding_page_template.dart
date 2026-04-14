import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class OnboardingPageTemplate extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<FeatureItem> features;
  final Color accentColor;

  const OnboardingPageTemplate({
    super.key,
    required this.title,
    required this.subtitle,
    required this.features,
    this.accentColor = const Color(0xFF00796B),
  });

  // Keep the old constructor working for compatibility
  factory OnboardingPageTemplate.legacy({
    Key? key,
    required List<Color> gradient,
    required IconData heroIcon,
    required String title,
    required String description,
    required List<String> bullets,
  }) {
    return OnboardingPageTemplate(
      key: key,
      title: title,
      subtitle: description,
      features: bullets.map((b) => FeatureItem(text: b)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Feature Cards
              ...features.map((f) => FeatureRow(item: f, accentColor: accentColor)),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureItem {
  final String text;
  final String? detail;
  final IconData? icon;

  const FeatureItem({
    required this.text,
    this.detail,
    this.icon,
  });
}

class FeatureRow extends StatelessWidget {
  final FeatureItem item;
  final Color accentColor;

  const FeatureRow({
    super.key,
    required this.item,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon ?? Icons.check_circle_outline_rounded,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.detail!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
