import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';

class SubscriptionPlanScreen extends StatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  State<SubscriptionPlanScreen> createState() => _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState extends State<SubscriptionPlanScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Subscription Plans');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Subscription Plan'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current Plan
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Current Plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[400]!, Colors.green[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Free Plan',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Forever Free',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Features
            _buildFeaturesSection(),

            const SizedBox(height: 16),

            // Upgrade Plans
            _buildUpgradePlansSection(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text(
            'Free Plan Includes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              _buildFeatureItem('Post Maker', 'Create social media posts', true),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Image Cropper', 'Batch crop and resize images', true),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Video Creator', 'Generate videos with templates', true),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Text Box Overlay', 'Add text to videos', true),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Audio Library', 'Extract and manage audio', true),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Ad-Free Experience', 'No advertisements', false),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Cloud Backup', 'Save projects to cloud', false),
              Divider(height: 1, color: Colors.grey[200]),
              _buildFeatureItem('Priority Support', 'Priority customer support', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String title, String description, bool included) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: included ? Colors.green[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                included ? Icons.check : Icons.close,
                color: included ? Colors.green[700] : Colors.grey[500],
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: included ? Colors.black : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePlansSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text(
            'Premium Plans',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildPlanCard(
                name: 'Pro Plan',
                price: '\$4.99',
                period: '/month',
                color: Colors.blue,
                features: [
                  'All Free features',
                  'Ad-Free Experience',
                  'Cloud Backup (5GB)',
                  'Priority Support',
                  'Advanced Filters',
                ],
                onTap: () => _showComingSoon(context),
              ),
              const SizedBox(height: 12),
              _buildPlanCard(
                name: 'Premium Plan',
                price: '\$9.99',
                period: '/month',
                color: Colors.purple,
                features: [
                  'All Pro features',
                  'Unlimited Cloud Storage',
                  'AI-Powered Features',
                  'Priority Support 24/7',
                  'Exclusive Templates',
                  'Advanced Analytics',
                ],
                onTap: () => _showComingSoon(context),
                isPremium: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required String period,
    required Color color,
    required List<String> features,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPremium ? color : Colors.grey[300]!,
          width: isPremium ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          TextSpan(
                            text: period,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onTap,
                child: const Text(
                  'Upgrade Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    AnalyticsService().logEvent(name: 'upgrade_plan_clicked');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Premium plans coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
