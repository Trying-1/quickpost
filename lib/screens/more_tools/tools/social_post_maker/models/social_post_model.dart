import 'package:flutter/material.dart';

/// Verified badge types.
enum VerifiedBadgeType {
  none(label: 'None'),
  blue(label: 'Blue Verified', color: Color(0xFF1D9BF0)),
  gold(label: 'Gold Official', color: Color(0xFFEAB308));

  final String label;
  final Color? color;
  const VerifiedBadgeType({required this.label, this.color});
}

/// Canvas aspect ratio choices for the social post graphic.
enum SocialPostRatio {
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
  story9x16(
    id: '9:16',
    label: '9:16 Story / Reels',
    ratio: 9 / 16,
    icon: Icons.stay_current_portrait_rounded,
  ),
  cardOnly(
    id: 'Card',
    label: 'Card Only (Overlay)',
    ratio: 0.0, // wrap content
    icon: Icons.credit_card_rounded,
  );

  final String id;
  final String label;
  final double ratio;
  final IconData icon;

  const SocialPostRatio({
    required this.id,
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// Color theme for the social card.
enum SocialCardTheme {
  darkOled(
    name: 'OLED Black',
    cardBg: Color(0xFF000000),
    cardBorder: Color(0xFF2F3336),
    primaryText: Colors.white,
    secondaryText: Color(0xFF71767B),
    accentColor: Color(0xFF1D9BF0),
  ),
  dimNavy(
    name: 'Dim Navy',
    cardBg: Color(0xFF15202B),
    cardBorder: Color(0xFF38444D),
    primaryText: Colors.white,
    secondaryText: Color(0xFF8B98A5),
    accentColor: Color(0xFF1D9BF0),
  ),
  cleanLight(
    name: 'Clean White',
    cardBg: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFCFD9DE),
    primaryText: Color(0xFF0F1419),
    secondaryText: Color(0xFF536471),
    accentColor: Color(0xFF1D9BF0),
  );

  final String name;
  final Color cardBg;
  final Color cardBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;

  const SocialCardTheme({
    required this.name,
    required this.cardBg,
    required this.cardBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.accentColor,
  });
}

/// Curated gradient presets for the canvas backdrop around the card.
class SocialBackdropPreset {
  final String name;
  final List<Color> colors;

  const SocialBackdropPreset({required this.name, required this.colors});

  static const List<SocialBackdropPreset> presets = [
    SocialBackdropPreset(
      name: 'Cyber Slate',
      colors: [Color(0xFF0B0F19), Color(0xFF1E293B)],
    ),
    SocialBackdropPreset(
      name: 'Midnight Purple',
      colors: [Color(0xFF130924), Color(0xFF2E1065)],
    ),
    SocialBackdropPreset(
      name: 'Sunset Ember',
      colors: [Color(0xFF260D1A), Color(0xFF4C0519)],
    ),
    SocialBackdropPreset(
      name: 'Deep Emerald',
      colors: [Color(0xFF041C15), Color(0xFF064E3B)],
    ),
    SocialBackdropPreset(
      name: 'Warm Mocha',
      colors: [Color(0xFF1C130D), Color(0xFF3E2723)],
    ),
    SocialBackdropPreset(
      name: 'Solid Dark',
      colors: [Color(0xFF0A0A0A), Color(0xFF0A0A0A)],
    ),
  ];
}

/// The core domain configuration model for the social post mockup.
class SocialPost {
  final String displayName;
  final String username;
  final String? avatarPath;
  final VerifiedBadgeType verifiedBadge;
  final String content;
  final String timestamp;
  final String viewsCount;
  final String repostsCount;
  final String quotesCount;
  final String likesCount;
  final String bookmarksCount;
  final String? attachedImagePath;
  final SocialPostRatio ratio;
  final SocialCardTheme cardTheme;
  final int backdropIndex;
  final String? customWallpaperPath;
  final bool showMetrics;
  final bool showTimestamp;

  const SocialPost({
    this.displayName = 'Alex Rivera',
    this.username = 'alexrivera',
    this.avatarPath,
    this.verifiedBadge = VerifiedBadgeType.blue,
    this.content = 'Stop waiting for the right moment. The right moment is the one you create today. #mindset #growth',
    this.timestamp = '10:42 PM · Nov 8, 2026',
    this.viewsCount = '2.4M',
    this.repostsCount = '18.5K',
    this.quotesCount = '3.8K',
    this.likesCount = '142K',
    this.bookmarksCount = '12.4K',
    this.attachedImagePath,
    this.ratio = SocialPostRatio.portrait4x5,
    this.cardTheme = SocialCardTheme.darkOled,
    this.backdropIndex = 0,
    this.customWallpaperPath,
    this.showMetrics = true,
    this.showTimestamp = true,
  });

  SocialBackdropPreset get backdrop =>
      SocialBackdropPreset.presets[backdropIndex.clamp(0, SocialBackdropPreset.presets.length - 1)];

  SocialPost copyWith({
    String? displayName,
    String? username,
    String? avatarPath,
    VerifiedBadgeType? verifiedBadge,
    String? content,
    String? timestamp,
    String? viewsCount,
    String? repostsCount,
    String? quotesCount,
    String? likesCount,
    String? bookmarksCount,
    String? attachedImagePath,
    SocialPostRatio? ratio,
    SocialCardTheme? cardTheme,
    int? backdropIndex,
    String? customWallpaperPath,
    bool? showMetrics,
    bool? showTimestamp,
    bool clearAvatar = false,
    bool clearAttachedImage = false,
    bool clearWallpaper = false,
  }) {
    return SocialPost(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      verifiedBadge: verifiedBadge ?? this.verifiedBadge,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      viewsCount: viewsCount ?? this.viewsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      quotesCount: quotesCount ?? this.quotesCount,
      likesCount: likesCount ?? this.likesCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      attachedImagePath: clearAttachedImage ? null : (attachedImagePath ?? this.attachedImagePath),
      ratio: ratio ?? this.ratio,
      cardTheme: cardTheme ?? this.cardTheme,
      backdropIndex: backdropIndex ?? this.backdropIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      showMetrics: showMetrics ?? this.showMetrics,
      showTimestamp: showTimestamp ?? this.showTimestamp,
    );
  }

  /// Default starting post
  static SocialPost get initialDefault => const SocialPost();

  /// Viral pre-configured templates
  static List<SocialPost> get viralTemplates => [
        // 1. Mindset & Discipline
        const SocialPost(
          displayName: 'Daily Motivation',
          username: 'dailymindset',
          verifiedBadge: VerifiedBadgeType.blue,
          content: 'You don\'t lack time. You lack focus.\n\n2 hours of deep unbroken focus will beat 10 hours of distracted multitasking every single day. #focus #discipline',
          timestamp: '8:30 AM · Nov 8, 2026',
          viewsCount: '4.8M',
          repostsCount: '32.1K',
          quotesCount: '6.4K',
          likesCount: '215K',
          bookmarksCount: '48.9K',
          cardTheme: SocialCardTheme.darkOled,
          ratio: SocialPostRatio.portrait4x5,
          backdropIndex: 0,
        ),

        // 2. Creator Advice
        const SocialPost(
          displayName: 'Creator Secrets',
          username: 'creatorplaybook',
          verifiedBadge: VerifiedBadgeType.gold,
          content: 'The 3-second hook is 80% of your video\'s virality.\n\nIf they don\'t stop scrolling in 3 seconds, the next 60 seconds of value literally do not exist. #contentcreator #reels',
          timestamp: '2:15 PM · Nov 8, 2026',
          viewsCount: '1.9M',
          repostsCount: '14.8K',
          quotesCount: '2.9K',
          likesCount: '98.4K',
          bookmarksCount: '24.2K',
          cardTheme: SocialCardTheme.dimNavy,
          ratio: SocialPostRatio.portrait4x5,
          backdropIndex: 1,
        ),

        // 3. Relatable Humor
        const SocialPost(
          displayName: 'Nobody Asked',
          username: 'relatablethoughts',
          verifiedBadge: VerifiedBadgeType.none,
          content: 'My brain at 3:00 AM: "Remember that mildly awkward thing you said in 7th grade? Let\'s analyze it from 14 different camera angles." 💀',
          timestamp: '3:04 AM · Nov 8, 2026',
          viewsCount: '7.2M',
          repostsCount: '64.2K',
          quotesCount: '11.5K',
          likesCount: '580K',
          bookmarksCount: '31.0K',
          cardTheme: SocialCardTheme.darkOled,
          ratio: SocialPostRatio.square1x1,
          backdropIndex: 2,
        ),

        // 4. Clean White Minimal
        const SocialPost(
          displayName: 'Quiet Ambition',
          username: 'quietambition',
          verifiedBadge: VerifiedBadgeType.blue,
          content: 'Work so quietly that they think you gave up.\n\nThen let your results do all the explaining.',
          timestamp: '9:00 PM · Nov 8, 2026',
          viewsCount: '3.1M',
          repostsCount: '26.4K',
          quotesCount: '4.1K',
          likesCount: '188K',
          bookmarksCount: '37.8K',
          cardTheme: SocialCardTheme.cleanLight,
          ratio: SocialPostRatio.portrait4x5,
          backdropIndex: 5,
        ),
      ];
}

