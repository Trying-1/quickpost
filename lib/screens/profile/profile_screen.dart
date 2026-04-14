import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quickpost/utils/watermark_settings.dart';
import 'whats_new_screen.dart';
import 'language_screen.dart';
import 'notifications_screen.dart';
import 'subscription_plan_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'user_profile_screen.dart';
import '../../config/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late PackageInfo _packageInfo;
  bool _isLoading = true;
  bool _showWatermark = WatermarkSettings.showWatermark;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(),

                  const SizedBox(height: 24),

                  // Account Section
                  _buildSection(
                    title: 'Account',
                    children: [
                      _buildListTile(
                        icon: Icons.person,
                        title: 'User Profile',
                        subtitle: 'Manage your profile information',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserProfileScreen(),
                          ),
                        ),
                      ),
                      _buildListTile(
                        icon: Icons.star,
                        title: 'Subscription Plan',
                        subtitle: 'Free Plan',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Free',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionPlanScreen(),
                          ),
                        ),
                      ),
                      _buildListTile(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // App Information Section
                  _buildSection(
                    title: 'App Information',
                    children: [
                      _buildListTile(
                        icon: Icons.info,
                        title: 'What\'s New',
                        subtitle: 'View latest features and improvements',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WhatsNewScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Storage & Cache Section
                  _buildSection(
                    title: 'Storage & Cache',
                    children: [
                      _buildListTile(
                        icon: Icons.storage,
                        title: 'App Cache',
                        subtitle: 'Clear temporary files',
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[100],
                            foregroundColor: Colors.red[700],
                          ),
                          onPressed: () => _showClearCacheDialog(context),
                          child: const Text('Clear', style: TextStyle(fontSize: 12)),
                        ),
                        onTap: null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Preferences Section
                  _buildSection(
                    title: 'Preferences',
                    children: [
                      _buildListTile(
                        icon: Icons.dark_mode,
                        title: 'Theme',
                        subtitle: 'Light',
                        onTap: () => _showComingSoon(context),
                      ),
                      SwitchListTile(
                        value: _showWatermark,
                        onChanged: (value) {
                          setState(() {
                            _showWatermark = value;
                            WatermarkSettings.setShowWatermark(value);
                          });
                        },
                        title: const Text('Show watermark on posts'),
                        subtitle: const Text('"made in Quick Post Maker" label'),
                        secondary: const Icon(Icons.water_drop_outlined),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _buildListTile(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: 'English',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LanguageScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Legal & Support Section
                  _buildSection(
                    title: 'Legal & Support',
                    children: [
                      _buildListTile(
                        icon: Icons.privacy_tip,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy practices',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      _buildListTile(
                        icon: Icons.description,
                        title: 'Terms of Service',
                        subtitle: 'Review terms and conditions',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsOfServiceScreen(),
                          ),
                        ),
                      ),
                      _buildListTile(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help and report issues',
                        onTap: () => _sendSupportEmail(),
                      ),
                      _buildListTile(
                        icon: Icons.bug_report,
                        title: 'Report a Bug',
                        subtitle: 'Help us improve the app',
                        onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.quickpost.app'),
                      ),
                      _buildListTile(
                        icon: Icons.feedback,
                        title: 'Send Feedback',
                        subtitle: 'Share your suggestions',
                        onTap: () => _showFeedbackDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Social & Share Section
                  _buildSection(
                    title: 'Connect With Us',
                    children: [
                      _buildListTile(
                        icon: Icons.share,
                        title: 'Share App',
                        subtitle: 'Share with friends and family',
                        onTap: () => _shareApp(),
                      ),
                      _buildListTile(
                        icon: Icons.star_rate,
                        title: 'Rate Us',
                        subtitle: 'Leave a review on Play Store',
                        onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.quickpost.app'),
                      ),
                      _buildListTile(
                        icon: Icons.language,
                        title: 'Visit Website',
                        subtitle: 'quickpost.arisesolo.com',
                        onTap: () => _launchUrl('https://quickpost.arisesolo.com'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Danger Zone Section (Disabled for now - no auth implemented)
                  _buildSection(
                    title: 'Danger Zone',
                    children: [
                      _buildDisabledListTile(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out from your account (Coming with auth)',
                        titleColor: Colors.orange,
                      ),
                      _buildDisabledListTile(
                        icon: Icons.delete_forever,
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account and data (Coming with auth)',
                        titleColor: Colors.red,
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
                            'Meme Flow v${_packageInfo.version}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '© 2024 Meme Flow. All rights reserved.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Meme Flow User',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'user@memeflow.app',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Free Plan Member',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[400],
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (titleColor ?? AppColors.primary).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: titleColor ?? AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: titleColor ?? const Color(0xFF2D2D2D),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDisabledListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
  }) {
    return Container(
      color: Colors.grey[100],
      child: ListTile(
        leading: Icon(icon, color: (titleColor ?? AppColors.primary).withOpacity(0.5)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: (titleColor ?? AppColors.primary).withOpacity(0.5),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Soon',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text('This will remove temporary files and free up space.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully!')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully!')),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion initiated...')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We\'d love to hear your suggestions and ideas!'),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tell us what you think...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final feedback = feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                _sendFeedbackEmail(feedback);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you for your feedback!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your feedback')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeedbackEmail(String feedback) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'arisesoloapp@gmail.com',
      queryParameters: {
        'subject': 'Meme Flow Feedback - v${_packageInfo.version}',
        'body': 'User Feedback:\n\n$feedback\n\nApp Version: ${_packageInfo.version}\nBuild: ${_packageInfo.buildNumber}',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      // Fallback: show snackbar with email address
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please email us at: arisesoloapp@gmail.com'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out Meme Flow - Create stunning social media posts, videos, and more!\n\nhttps://play.google.com/store/apps/details?id=com.quickpost.app',
      subject: 'Download Meme Flow - Social Media Creator',
    );
  }

  Future<void> _sendSupportEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'arisesoloapp@gmail.com',
      queryParameters: {
        'subject': 'Meme Flow Support - v${_packageInfo.version}',
        'body': 'Hello,\n\nI need help with Meme Flow.\n\nApp Version: ${_packageInfo.version}\nBuild: ${_packageInfo.buildNumber}\n\nPlease describe your issue:\n',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please email us at: arisesoloapp@gmail.com'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
