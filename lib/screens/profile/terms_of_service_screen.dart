import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
                    'Terms of Service',
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
              title: '1. Acceptance of Terms',
              content:
                  'By accessing and using the QuickPost application ("Service"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
            ),

            _buildSection(
              title: '2. Use License',
              content:
                  'Permission is granted to temporarily download one copy of the materials (information or software) on QuickPost for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title, and under this license you may not:\n\n'
                  '• Modify or copy the materials\n'
                  '• Use the materials for any commercial purpose or for any public display\n'
                  '• Attempt to decompile or reverse engineer any software contained on the Service\n'
                  '• Remove any copyright or other proprietary notations from the materials\n'
                  '• Transfer the materials to another person or "mirror" the materials on any other server',
            ),

            _buildSection(
              title: '3. Disclaimer',
              content:
                  'The materials on QuickPost are provided on an "as is" basis. QuickPost makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.',
            ),

            _buildSection(
              title: '4. Limitations',
              content:
                  'In no event shall QuickPost or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on QuickPost, even if QuickPost or an authorized representative has been notified orally or in writing of the possibility of such damage.',
            ),

            _buildSection(
              title: '5. Accuracy of Materials',
              content:
                  'The materials appearing on QuickPost could include technical, typographical, or photographic errors. QuickPost does not warrant that any of the materials on its Service are accurate, complete, or current. QuickPost may make changes to the materials contained on its Service at any time without notice.',
            ),

            _buildSection(
              title: '6. Materials and Content',
              content:
                  'QuickPost does not claim any ownership rights in the text, images, videos, or other content you create or process using our Service. You retain all rights to your content. However, by using our Service, you grant us a limited license to use your content for the purpose of providing and improving our Service.',
            ),

            _buildSection(
              title: '7. Links',
              content:
                  'QuickPost has not reviewed all of the sites linked to its Service and is not responsible for the contents of any such linked site. The inclusion of any link does not imply endorsement by QuickPost of the site. Use of any such linked website is at the user\'s own risk.',
            ),

            _buildSection(
              title: '8. Modifications',
              content:
                  'QuickPost may revise these terms of service for its Service at any time without notice. By using this Service, you are agreeing to be bound by the then current version of these terms of service.',
            ),

            _buildSection(
              title: '9. Governing Law',
              content:
                  'These terms and conditions are governed by and construed in accordance with the laws of the jurisdiction in which QuickPost operates, and you irrevocably submit to the exclusive jurisdiction of the courts in that location.',
            ),

            _buildSection(
              title: '10. User Responsibilities',
              content:
                  'You agree to use QuickPost only for lawful purposes and in a way that does not infringe upon the rights of others or restrict their use and enjoyment of the Service. Prohibited behavior includes:\n\n'
                  '• Harassing or causing distress or inconvenience to any person\n'
                  '• Obscene or abusive language\n'
                  '• Disrupting the normal flow of dialogue within our Service\n'
                  '• Uploading or distributing viruses or malicious code\n'
                  '• Creating content that violates intellectual property rights',
            ),

            _buildSection(
              title: '11. Limitation of Liability',
              content:
                  'To the fullest extent permitted by law, in no event will QuickPost, its affiliates, or their respective officers, directors, employees, agents, or representatives be liable to you for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly.',
            ),

            _buildSection(
              title: '12. Contact Information',
              content:
                  'If you have any questions about these Terms of Service, please contact us at:\n\n'
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
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please read these terms carefully before using our Service.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
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
