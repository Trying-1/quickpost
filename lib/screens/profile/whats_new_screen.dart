import 'package:flutter/material.dart';

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('What\'s New'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Latest Version Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Latest Features',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Released on December 14, 2024',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Features List
            _buildFeatureSection(
              title: 'New Features',
              features: [
                FeatureItem(
                  icon: Icons.create,
                  title: 'Enhanced Post Maker',
                  description: 'Create stunning social media posts with improved templates',
                ),
                FeatureItem(
                  icon: Icons.video_call,
                  title: 'Video Creator',
                  description: 'Generate videos with fade-in and zoom effects',
                ),
                FeatureItem(
                  icon: Icons.text_fields,
                  title: 'Text Box Overlay',
                  description: 'Add customizable text overlays to your videos',
                ),
                FeatureItem(
                  icon: Icons.library_music,
                  title: 'Audio Library',
                  description: 'Extract and manage audio files from videos',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Improvements
            _buildFeatureSection(
              title: 'Improvements',
              features: [
                FeatureItem(
                  icon: Icons.speed,
                  title: 'Faster Processing',
                  description: 'Optimized video encoding for quicker exports',
                ),
                FeatureItem(
                  icon: Icons.bug_report,
                  title: 'Bug Fixes',
                  description: 'Fixed frame timing issues and synchronization problems',
                ),
                FeatureItem(
                  icon: Icons.design_services,
                  title: 'UI Improvements',
                  description: 'Better user interface and smoother navigation',
                ),
                FeatureItem(
                  icon: Icons.storage,
                  title: 'Better Performance',
                  description: 'Reduced app size and improved memory usage',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Coming Soon
            _buildFeatureSection(
              title: 'Coming Soon',
              features: [
                FeatureItem(
                  icon: Icons.cloud,
                  title: 'Cloud Backup',
                  description: 'Save your projects to the cloud',
                ),
                FeatureItem(
                  icon: Icons.share,
                  title: 'Direct Sharing',
                  description: 'Share directly to social media platforms',
                ),
                FeatureItem(
                  icon: Icons.palette,
                  title: 'More Templates',
                  description: 'Additional design templates and styles',
                ),
                FeatureItem(
                  icon: Icons.auto_awesome,
                  title: 'AI Features',
                  description: 'AI-powered design suggestions and enhancements',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Text(
                    'Thank you for using QuickPost!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re constantly working to improve your experience.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection({
    required String title,
    required List<FeatureItem> features,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: features
                .asMap()
                .entries
                .map(
                  (entry) => Column(
                    children: [
                      _buildFeatureItem(entry.value),
                      if (entry.key < features.length - 1)
                        Divider(height: 1, color: Colors.grey[200]),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(FeatureItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                item.icon,
                color: Colors.purple,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
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
}

class FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
