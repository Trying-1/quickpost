import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _newFeatures = true;
  bool _updates = true;
  bool _tips = true;
  bool _promotions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // General Notifications
            _buildSection(
              title: 'General',
              children: [
                _buildNotificationToggle(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: 'Receive notifications on your device',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                ),
                _buildNotificationToggle(
                  icon: Icons.email,
                  title: 'Email Notifications',
                  subtitle: 'Receive updates via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _emailNotifications = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content Notifications
            _buildSection(
              title: 'Content',
              children: [
                _buildNotificationToggle(
                  icon: Icons.star,
                  title: 'New Features',
                  subtitle: 'Get notified about new features',
                  value: _newFeatures,
                  onChanged: (value) {
                    setState(() {
                      _newFeatures = value;
                    });
                  },
                ),
                _buildNotificationToggle(
                  icon: Icons.system_update,
                  title: 'App Updates',
                  subtitle: 'Notifications about app updates',
                  value: _updates,
                  onChanged: (value) {
                    setState(() {
                      _updates = value;
                    });
                  },
                ),
                _buildNotificationToggle(
                  icon: Icons.lightbulb,
                  title: 'Tips & Tricks',
                  subtitle: 'Learn how to use QuickPost better',
                  value: _tips,
                  onChanged: (value) {
                    setState(() {
                      _tips = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Marketing Notifications
            _buildSection(
              title: 'Marketing',
              children: [
                _buildNotificationToggle(
                  icon: Icons.local_offer,
                  title: 'Promotions & Offers',
                  subtitle: 'Special deals and discounts',
                  value: _promotions,
                  onChanged: (value) {
                    setState(() {
                      _promotions = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quiet Hours Section
            Container(
              color: Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Quiet Hours',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  ListTile(
                    leading: Icon(Icons.schedule, color: Colors.purple),
                    title: const Text('Set Quiet Hours'),
                    subtitle: const Text('Disable notifications during specific times'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _showComingSoon(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        'You can manage notification permissions in your device settings',
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
    required List<Widget> children,
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
            children: children
                .asMap()
                .entries
                .map(
                  (entry) => Column(
                    children: [
                      entry.value,
                      if (entry.key < children.length - 1)
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

  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.purple),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.purple,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
}
