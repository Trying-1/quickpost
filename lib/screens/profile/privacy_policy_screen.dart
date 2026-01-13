import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: December 14, 2024',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content
            _buildSection(
              title: '1. Introduction',
              content:
                  'QuickPost ("we", "us", "our", or "Company") operates the QuickPost mobile application (the "Service"). This page informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service and the choices you have associated with that data.',
            ),

            _buildSection(
              title: '2. Information Collection and Use',
              content:
                  'We collect several different types of information for various purposes to provide and improve our Service to you.\n\n'
                  '• Device Information: We may collect information about your device, including device model, operating system, and unique device identifiers.\n\n'
                  '• Usage Information: We collect information about how you interact with our Service, including features used and actions taken.\n\n'
                  '• Media Files: Any images, videos, or audio files you create or process using QuickPost are stored locally on your device. We do not automatically upload or store these files on our servers unless you explicitly choose to use cloud backup features.',
            ),

            _buildSection(
              title: '3. Use of Data',
              content:
                  'QuickPost uses the collected data for various purposes:\n\n'
                  '• To provide and maintain our Service\n'
                  '• To notify you about changes to our Service\n'
                  '• To allow you to participate in interactive features of our Service\n'
                  '• To provide customer support\n'
                  '• To gather analysis or valuable information so that we can improve our Service\n'
                  '• To monitor the usage of our Service\n'
                  '• To detect, prevent and address technical issues',
            ),

            _buildSection(
              title: '4. Security of Data',
              content:
                  'The security of your data is important to us but remember that no method of transmission over the Internet or method of electronic storage is 100% secure. While we strive to use commercially acceptable means to protect your personal data, we cannot guarantee its absolute security.',
            ),

            _buildSection(
              title: '5. Third-Party Services',
              content:
                  'Our Service may contain links to third-party websites and services that are not operated by us. This Privacy Policy does not apply to third-party websites, and we are not responsible for their privacy practices. We encourage you to review the privacy policies of any third-party services before providing your information.',
            ),

            _buildSection(
              title: '6. Children\'s Privacy',
              content:
                  'Our Service does not address anyone under the age of 13 ("Children"). We do not knowingly collect personally identifiable information from children under 13. If you are a parent or guardian and you are aware that your child has provided us with personal data, please contact us immediately.',
            ),

            _buildSection(
              title: '7. Changes to This Privacy Policy',
              content:
                  'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date at the top of this Privacy Policy.',
            ),

            _buildSection(
              title: '8. Contact Us',
              content:
                  'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                  'Email: arisesoloapp@gmail.com\n'
                  'Website: https://quickpost.arisesolo.com',
            ),

            const SizedBox(height: 24),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your privacy is important to us. Please read this policy carefully.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
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
          padding: const EdgeInsets.all(16),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
