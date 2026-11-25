import 'package:flutter/material.dart';

/// Available app icon archetypes for simulated notifications.
enum NotificationAppType {
  banking(
    name: 'Banking / Cash',
    appName: 'CHASE BANK',
    icon: Icons.account_balance_rounded,
    iconColor: Color(0xFF10B981),
    iconBg: Color(0xFF064E3B),
  ),
  messages(
    name: 'Messages',
    appName: 'MESSAGES',
    icon: Icons.chat_bubble_rounded,
    iconColor: Color(0xFF38BDF8),
    iconBg: Color(0xFF0284C7),
  ),
  social(
    name: 'Social Network',
    appName: 'INSTA SOCIAL',
    icon: Icons.favorite_rounded,
    iconColor: Color(0xFFF43F5E),
    iconBg: Color(0xFFE11D48),
  ),
  youtube(
    name: 'Video Platform',
    appName: 'STUDIO CREATOR',
    icon: Icons.play_arrow_rounded,
    iconColor: Color(0xFFEF4444),
    iconBg: Color(0xFF991B1B),
  ),
  reminders(
    name: 'Notes & Goals',
    appName: 'REMINDERS',
    icon: Icons.check_circle_outline_rounded,
    iconColor: Color(0xFFFACC15),
    iconBg: Color(0xFF854D0E),
  ),
  custom(
    name: 'Custom Alert',
    appName: 'NOTIFICATION',
    icon: Icons.notifications_active_rounded,
    iconColor: Color(0xFF00E5FF),
    iconBg: Color(0xFF0369A1),
  );

  final String name;
  final String appName;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const NotificationAppType({
    required this.name,
    required this.appName,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

/// A single push notification alert item.
class NotificationItem {
  final String id;
  final NotificationAppType appType;
  final String customAppName;
  final String timeHeader;
  final String title;
  final String message;

  const NotificationItem({
    required this.id,
    this.appType = NotificationAppType.banking,
    this.customAppName = '',
    this.timeHeader = 'now',
    this.title = 'Chase Alert: Direct Deposit',
    this.message = 'Account (...4821) credited: +\$12,500.00 from Stripe Payments.',
  });

  String get displayAppName =>
      customAppName.isNotEmpty ? customAppName.toUpperCase() : appType.appName;

  NotificationItem copyWith({
    String? id,
    NotificationAppType? appType,
    String? customAppName,
    String? timeHeader,
    String? title,
    String? message,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      appType: appType ?? this.appType,
      customAppName: customAppName ?? this.customAppName,
      timeHeader: timeHeader ?? this.timeHeader,
      title: title ?? this.title,
      message: message ?? this.message,
    );
  }
}

/// Canvas aspect ratio choices.
enum NotificationRatio {
  story9x16(
    id: '9:16',
    label: '9:16 Lock Screen',
    ratio: 9 / 16,
    icon: Icons.stay_current_portrait_rounded,
  ),
  portrait4x5(
    id: '4:5',
    label: '4:5 Feed Portrait',
    ratio: 4 / 5,
    icon: Icons.portrait_rounded,
  ),
  square1x1(
    id: '1:1',
    label: '1:1 Square Feed',
    ratio: 1.0,
    icon: Icons.crop_square_rounded,
  ),
  cardOnly(
    id: 'Card',
    label: 'Card Only (Overlay)',
    ratio: 0.0,
    icon: Icons.credit_card_rounded,
  );

  final String id;
  final String label;
  final double ratio;
  final IconData icon;

  const NotificationRatio({
    required this.id,
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// Curated lock screen background wallpapers.
class NotificationWallpaperPreset {
  final String name;
  final List<Color> colors;

  const NotificationWallpaperPreset({required this.name, required this.colors});

  static const List<NotificationWallpaperPreset> presets = [
    NotificationWallpaperPreset(
      name: 'Cyber Aurora',
      colors: [Color(0xFF0F172A), Color(0xFF0369A1), Color(0xFF090D16)],
    ),
    NotificationWallpaperPreset(
      name: 'Midnight Purple',
      colors: [Color(0xFF130924), Color(0xFF3B0764), Color(0xFF090514)],
    ),
    NotificationWallpaperPreset(
      name: 'Moody Obsidian',
      colors: [Color(0xFF18181B), Color(0xFF09090B), Color(0xFF000000)],
    ),
    NotificationWallpaperPreset(
      name: 'Sunset Crimson',
      colors: [Color(0xFF450A0A), Color(0xFF1C060B), Color(0xFF090514)],
    ),
    NotificationWallpaperPreset(
      name: 'Emerald Matrix',
      colors: [Color(0xFF064E3B), Color(0xFF022C22), Color(0xFF031610)],
    ),
  ];
}

/// The entire lock screen notification mockup model.
class NotificationPost {
  final List<NotificationItem> items;
  final String clockTime;
  final String clockDate;
  final NotificationRatio ratio;
  final int wallpaperIndex;
  final String? customWallpaperPath;
  final bool isGlassmorphic;
  final bool showLockHeader; // shows lock icon + big clock

  const NotificationPost({
    required this.items,
    this.clockTime = '09:41',
    this.clockDate = 'Sunday, November 8',
    this.ratio = NotificationRatio.story9x16,
    this.wallpaperIndex = 0,
    this.customWallpaperPath,
    this.isGlassmorphic = true,
    this.showLockHeader = true,
  });

  NotificationWallpaperPreset get wallpaper =>
      NotificationWallpaperPreset.presets[wallpaperIndex.clamp(0, NotificationWallpaperPreset.presets.length - 1)];

  NotificationPost copyWith({
    List<NotificationItem>? items,
    String? clockTime,
    String? clockDate,
    NotificationRatio? ratio,
    int? wallpaperIndex,
    String? customWallpaperPath,
    bool? isGlassmorphic,
    bool? showLockHeader,
    bool clearWallpaper = false,
  }) {
    return NotificationPost(
      items: items ?? List.from(this.items),
      clockTime: clockTime ?? this.clockTime,
      clockDate: clockDate ?? this.clockDate,
      ratio: ratio ?? this.ratio,
      wallpaperIndex: wallpaperIndex ?? this.wallpaperIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      isGlassmorphic: isGlassmorphic ?? this.isGlassmorphic,
      showLockHeader: showLockHeader ?? this.showLockHeader,
    );
  }

  /// Default starting notification
  static NotificationPost get initialDefault => const NotificationPost(
        items: [
          NotificationItem(
            id: 'n1',
            appType: NotificationAppType.banking,
            timeHeader: 'now',
            title: 'Deposit Received 💰',
            message: 'Your account was credited +\$14,850.00 from Stripe Payments.',
          ),
          NotificationItem(
            id: 'n2',
            appType: NotificationAppType.social,
            timeHeader: '2m ago',
            title: 'Viral Video Alert 🚀',
            message: 'Your latest reel just crossed 1,000,000 views in 3 hours!',
          ),
        ],
        clockTime: '09:41',
        clockDate: 'Sunday, November 8',
        ratio: NotificationRatio.story9x16,
      );

  /// Viral pre-configured notification presets
  static List<NotificationPost> get viralTemplates => [
        // 1. High Net Worth Hook
        const NotificationPost(
          items: [
            NotificationItem(
              id: 'v1',
              appType: NotificationAppType.banking,
              timeHeader: 'now',
              title: 'Wire Transfer Completed',
              message: '+\$50,000.00 has been deposited to your business checking account.',
            ),
          ],
          clockTime: '06:00',
          clockDate: 'Monday, November 9',
          wallpaperIndex: 0,
        ),

        // 2. Emotional / Dramatic Text Hook
        const NotificationPost(
          items: [
            NotificationItem(
              id: 'et1',
              appType: NotificationAppType.messages,
              timeHeader: '3:14 AM',
              title: 'Crush 💖',
              message: 'I know it\'s late... but I can\'t stop thinking about what you said.',
            ),
          ],
          clockTime: '03:15',
          clockDate: 'Tonight',
          wallpaperIndex: 1,
        ),

        // 3. Creator Milestone Hook
        const NotificationPost(
          items: [
            NotificationItem(
              id: 'cm1',
              appType: NotificationAppType.youtube,
              timeHeader: 'now',
              title: 'Gold Creator Award 🏆',
              message: 'Congratulations! Your channel just passed 1,000,000 subscribers.',
            ),
            NotificationItem(
              id: 'cm2',
              appType: NotificationAppType.social,
              timeHeader: '1m ago',
              title: 'Brand Deal Offer 💼',
              message: 'Sony has sent you a contract proposal: \$25,000 sponsorship.',
            ),
          ],
          clockTime: '12:00',
          clockDate: 'Friday, November 13',
          wallpaperIndex: 2,
        ),
      ];
}

