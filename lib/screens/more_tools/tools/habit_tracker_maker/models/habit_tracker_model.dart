import 'package:flutter/material.dart';

/// Available time spans for the habit contribution graph.
enum HabitTimeSpan {
  quarter(
    id: '90 Days',
    label: 'Quarter (13 Wks)',
    weeks: 13,
    icon: Icons.calendar_view_week_rounded,
  ),
  hundredDays(
    id: '100 Days',
    label: '100-Day Challenge',
    weeks: 15,
    icon: Icons.flag_rounded,
  ),
  halfYear(
    id: '180 Days',
    label: 'Half Year (26 Wks)',
    weeks: 26,
    icon: Icons.date_range_rounded,
  ),
  fullYear(
    id: '365 Days',
    label: 'Full Year (52 Wks)',
    weeks: 52,
    icon: Icons.calendar_month_rounded,
  );

  final String id;
  final String label;
  final int weeks;
  final IconData icon;

  const HabitTimeSpan({
    required this.id,
    required this.label,
    required this.weeks,
    required this.icon,
  });

  int get totalDays => weeks * 7;
}

/// Canvas aspect ratio for social media exports.
enum HabitRatio {
  portrait4x5(id: '4:5 Feed', widthRatio: 4, heightRatio: 5, icon: Icons.crop_portrait_rounded),
  square1x1(id: '1:1 Square', widthRatio: 1, heightRatio: 1, icon: Icons.crop_square_rounded),
  vertical9x16(id: '9:16 Story', widthRatio: 9, heightRatio: 16, icon: Icons.stay_current_portrait_rounded),
  cardOnly(id: 'Card Only', widthRatio: 1, heightRatio: 1, icon: Icons.view_compact_rounded);

  final String id;
  final double widthRatio;
  final double heightRatio;
  final IconData icon;

  const HabitRatio({
    required this.id,
    required this.widthRatio,
    required this.heightRatio,
    required this.icon,
  });

  double get aspectRatio => widthRatio / heightRatio;
}

/// Dot shape options for individual contribution heatmap tiles.
enum HabitDotShape {
  roundedSquare(id: 'rounded', label: 'Rounded', radius: 3.0, icon: Icons.crop_square_rounded),
  squircle(id: 'squircle', label: 'Squircle', radius: 6.0, icon: Icons.circle_outlined),
  circle(id: 'circle', label: 'Circle', radius: 12.0, icon: Icons.circle),
  pixelSharp(id: 'sharp', label: '8-Bit Sharp', radius: 0.0, icon: Icons.square_outlined);

  final String id;
  final String label;
  final double radius;
  final IconData icon;

  const HabitDotShape({
    required this.id,
    required this.label,
    required this.radius,
    required this.icon,
  });
}

/// Milestone celebration stamps on the post.
enum HabitMilestoneBadge {
  none(id: 'none', label: 'None / Off', text: ''),
  streak30(id: 'streak30', label: '🔥 30 Days Streak', text: '🔥 30 DAYS STREAK'),
  club50(id: 'club50', label: '🎉 50 Days Done', text: '🎉 50 DAYS COMPLETED'),
  club100(id: 'club100', label: '💯 100 Days Club', text: '💯 100 DAYS CLUB'),
  unlocked365(id: 'unlocked365', label: '👑 Level 365', text: '👑 LEVEL 365 UNLOCKED'),
  goalReached(id: 'goalReached', label: '🏆 Goal Reached', text: '🏆 GOAL REACHED');

  final String id;
  final String label;
  final String text;

  const HabitMilestoneBadge({
    required this.id,
    required this.label,
    required this.text,
  });
}

/// Visual color themes inspired by GitHub, QuickPost Teal, and high-contrast creative palettes.
enum HabitColorTheme {
  githubDark(
    id: 'github_dark',
    name: 'GitHub Dark',
    cardBg: Color(0xFF0D1117),
    cardBorder: Color(0xFF30363D),
    primaryText: Colors.white,
    secondaryText: Color(0xFF8B949E),
    accentColor: Color(0xFF39D353),
    levels: [
      Color(0xFF161B22), // 0: empty
      Color(0xFF0E4429), // 1
      Color(0xFF006D32), // 2
      Color(0xFF26A641), // 3
      Color(0xFF39D353), // 4: max
    ],
  ),
  quickpostTeal(
    id: 'quickpost_teal',
    name: 'QuickPost Teal',
    cardBg: Color(0xFF051D1A),
    cardBorder: Color(0xFF004D40),
    primaryText: Colors.white,
    secondaryText: Color(0xFF80CBC4),
    accentColor: Color(0xFF26A69A),
    levels: [
      Color(0xFF0B2D29), // 0
      Color(0xFF004D40), // 1
      Color(0xFF00796B), // 2
      Color(0xFF00897B), // 3
      Color(0xFF26A69A), // 4
    ],
  ),
  electricViolet(
    id: 'electric_violet',
    name: 'Neon Violet',
    cardBg: Color(0xFF110726),
    cardBorder: Color(0xFF3B1874),
    primaryText: Colors.white,
    secondaryText: Color(0xFFC084FC),
    accentColor: Color(0xFFA855F7),
    levels: [
      Color(0xFF1E0E3E), // 0
      Color(0xFF4C1D95), // 1
      Color(0xFF6D28D9), // 2
      Color(0xFF8B5CF6), // 3
      Color(0xFFC084FC), // 4
    ],
  ),
  sunsetFire(
    id: 'sunset_fire',
    name: 'Fire Orange',
    cardBg: Color(0xFF1A0A04),
    cardBorder: Color(0xFF5A220B),
    primaryText: Colors.white,
    secondaryText: Color(0xFFFDBA74),
    accentColor: Color(0xFFF97316),
    levels: [
      Color(0xFF2B1208), // 0
      Color(0xFF9A3412), // 1
      Color(0xFFC2410C), // 2
      Color(0xFFEA580C), // 3
      Color(0xFFFB923C), // 4
    ],
  ),
  cyberCyan(
    id: 'cyber_cyan',
    name: 'Cyber Cyan',
    cardBg: Color(0xFF061824),
    cardBorder: Color(0xFF0E3E5C),
    primaryText: Colors.white,
    secondaryText: Color(0xFF7DD3FC),
    accentColor: Color(0xFF0EA5E9),
    levels: [
      Color(0xFF0C273A), // 0
      Color(0xFF0369A1), // 1
      Color(0xFF0284C7), // 2
      Color(0xFF38BDF8), // 3
      Color(0xFF7DD3FC), // 4
    ],
  ),
  minimalWhite(
    id: 'minimal_white',
    name: 'Clean White',
    cardBg: Colors.white,
    cardBorder: Color(0xFFE2E8F0),
    primaryText: Color(0xFF1E293B),
    secondaryText: Color(0xFF64748B),
    accentColor: Color(0xFF10B981),
    levels: [
      Color(0xFFF1F5F9), // 0
      Color(0xFFBBF7D0), // 1
      Color(0xFF86EFAC), // 2
      Color(0xFF4ADE80), // 3
      Color(0xFF10B981), // 4
    ],
  );

  final String id;
  final String name;
  final Color cardBg;
  final Color cardBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;
  final List<Color> levels;

  const HabitColorTheme({
    required this.id,
    required this.name,
    required this.cardBg,
    required this.cardBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.accentColor,
    required this.levels,
  });

  Color colorForLevel(int level) {
    if (level <= 0) return levels[0];
    if (level >= levels.length) return levels.last;
    return levels[level];
  }
}

/// Curated gradient presets for canvas backdrop.
class HabitBackdropPreset {
  final String name;
  final List<Color> colors;

  const HabitBackdropPreset({required this.name, required this.colors});

  static const List<HabitBackdropPreset> presets = [
    HabitBackdropPreset(
      name: 'Pure Card Background',
      colors: [Color(0xFF0D1117), Color(0xFF0D1117)],
    ),
    HabitBackdropPreset(
      name: 'Deep Slate',
      colors: [Color(0xFF0B0F19), Color(0xFF1E293B)],
    ),
    HabitBackdropPreset(
      name: 'Forest Emerald',
      colors: [Color(0xFF022C22), Color(0xFF064E3B)],
    ),
    HabitBackdropPreset(
      name: 'Midnight Velvet',
      colors: [Color(0xFF180A2E), Color(0xFF2E1065)],
    ),
    HabitBackdropPreset(
      name: 'Ocean Abyss',
      colors: [Color(0xFF082F49), Color(0xFF0C4A6E)],
    ),
    HabitBackdropPreset(
      name: 'Warm Charcoal',
      colors: [Color(0xFF1C1917), Color(0xFF292524)],
    ),
    HabitBackdropPreset(
      name: 'Studio Clean Grey',
      colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
    ),
  ];
}

/// Curated viral quotes creators love for habits and challenges.
class HabitQuotesLibrary {
  static const List<String> quotes = [
    'Consistency beats talent when talent doesn’t show up.',
    'Small daily wins compound into extraordinary results.',
    'You fall to the level of your systems. Show up every day.',
    'Day 1 or One Day? You decide.',
    'Discipline is choosing between what you want now and what you want most.',
    'Progress over perfection. One square at a time.',
    'Action cures anxiety. Trust the process.',
    'Success isn’t always about greatness. It’s about consistency.',
    'Building habits that outlast motivation.',
    'Mastering the art of showing up.',
  ];
}

/// The core post data model for Habit Tracking Grid cards.
class HabitGridPost {
  final String habitTitle;
  final String habitSubtitle;
  final String yearLabel;
  final String authorHandle;
  final String? authorAvatarPath;
  final HabitTimeSpan timeSpan;
  final HabitColorTheme theme;
  final HabitRatio ratio;
  final HabitDotShape dotShape;
  final double dotSpacing;
  final bool enableDotGlow;
  final HabitMilestoneBadge milestone;
  final int backdropIndex;
  final String? customWallpaperPath;
  final bool transparentBg;
  final List<int> tileIntensities; // length equals timeSpan.totalDays, values 0..4
  final bool showStatsRow;
  final bool showDayLabels;
  final bool showMonthLabels;
  final bool showAuthorBadge;
  final int manualStreak;

  const HabitGridPost({
    required this.habitTitle,
    required this.habitSubtitle,
    required this.yearLabel,
    required this.authorHandle,
    this.authorAvatarPath,
    required this.timeSpan,
    required this.theme,
    required this.ratio,
    this.dotShape = HabitDotShape.roundedSquare,
    this.dotSpacing = 3.0,
    this.enableDotGlow = false,
    this.milestone = HabitMilestoneBadge.none,
    required this.backdropIndex,
    this.customWallpaperPath,
    this.transparentBg = false,
    required this.tileIntensities,
    this.showStatsRow = true,
    this.showDayLabels = true,
    this.showMonthLabels = true,
    this.showAuthorBadge = true,
    this.manualStreak = 42,
  });

  /// Computed total days completed (intensity > 0).
  int get completedDays => tileIntensities.where((lvl) => lvl > 0).length;

  /// Computed completion percentage.
  double get completionPercentage {
    if (tileIntensities.isEmpty) return 0.0;
    return (completedDays / tileIntensities.length) * 100.0;
  }

  /// Computed longest consecutive streak.
  int get calculatedLongestStreak {
    int maxStreak = 0;
    int current = 0;
    for (final lvl in tileIntensities) {
      if (lvl > 0) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 0;
      }
    }
    return maxStreak;
  }

  /// Active display streak.
  int get displayStreak => manualStreak > 0 ? manualStreak : calculatedLongestStreak;

  HabitGridPost copyWith({
    String? habitTitle,
    String? habitSubtitle,
    String? yearLabel,
    String? authorHandle,
    String? authorAvatarPath,
    bool clearAvatar = false,
    HabitTimeSpan? timeSpan,
    HabitColorTheme? theme,
    HabitRatio? ratio,
    HabitDotShape? dotShape,
    double? dotSpacing,
    bool? enableDotGlow,
    HabitMilestoneBadge? milestone,
    int? backdropIndex,
    String? customWallpaperPath,
    bool clearWallpaper = false,
    bool? transparentBg,
    List<int>? tileIntensities,
    bool? showStatsRow,
    bool? showDayLabels,
    bool? showMonthLabels,
    bool? showAuthorBadge,
    int? manualStreak,
  }) {
    return HabitGridPost(
      habitTitle: habitTitle ?? this.habitTitle,
      habitSubtitle: habitSubtitle ?? this.habitSubtitle,
      yearLabel: yearLabel ?? this.yearLabel,
      authorHandle: authorHandle ?? this.authorHandle,
      authorAvatarPath: clearAvatar ? null : (authorAvatarPath ?? this.authorAvatarPath),
      timeSpan: timeSpan ?? this.timeSpan,
      theme: theme ?? this.theme,
      ratio: ratio ?? this.ratio,
      dotShape: dotShape ?? this.dotShape,
      dotSpacing: dotSpacing ?? this.dotSpacing,
      enableDotGlow: enableDotGlow ?? this.enableDotGlow,
      milestone: milestone ?? this.milestone,
      backdropIndex: backdropIndex ?? this.backdropIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      transparentBg: transparentBg ?? this.transparentBg,
      tileIntensities: tileIntensities ?? this.tileIntensities,
      showStatsRow: showStatsRow ?? this.showStatsRow,
      showDayLabels: showDayLabels ?? this.showDayLabels,
      showMonthLabels: showMonthLabels ?? this.showMonthLabels,
      showAuthorBadge: showAuthorBadge ?? this.showAuthorBadge,
      manualStreak: manualStreak ?? this.manualStreak,
    );
  }

  /// Helper to generate sample realistic intensity patterns.
  static List<int> generatePattern({
    required int totalDays,
    required double density,
    int endingStreak = 30,
  }) {
    final list = List<int>.filled(totalDays, 0);
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < totalDays; i++) {
      if (i >= totalDays - endingStreak) {
        list[i] = 1 + ((i * 7 + now) % 4);
      } else {
        final pseudoRandom = ((i * 137 + 41) % 100) / 100.0;
        if (pseudoRandom < density) {
          list[i] = 1 + ((i * 3 + 17) % 4);
        } else {
          list[i] = 0;
        }
      }
    }
    return list;
  }

  /// Ramping Up pattern: Starts sporadic and builds momentum towards 100% density
  static List<int> generateRampingPattern(int totalDays) {
    final list = List<int>.filled(totalDays, 0);
    for (int i = 0; i < totalDays; i++) {
      final progress = i / totalDays; // 0.0 to 1.0
      final threshold = 0.2 + (progress * 0.75); // 20% to 95%
      final pseudo = ((i * 109 + 23) % 100) / 100.0;
      if (pseudo < threshold) {
        final lvl = (1 + (progress * 3.5)).clamp(1, 4).toInt();
        list[i] = lvl;
      } else {
        list[i] = 0;
      }
    }
    return list;
  }

  /// Weekdays Only pattern: Active Monday-Friday (indices 0..4 in 7-day week), resting on weekends (5,6)
  static List<int> generateWeekdaysPattern(int totalDays) {
    final list = List<int>.filled(totalDays, 0);
    for (int i = 0; i < totalDays; i++) {
      final dayOfWeek = i % 7;
      if (dayOfWeek < 5) {
        list[i] = 2 + ((i * 5) % 3); // 2..4
      } else {
        list[i] = 0; // weekend
      }
    }
    return list;
  }

  /// Alternating Days pattern: Active every other day
  static List<int> generateAlternatingPattern(int totalDays) {
    final list = List<int>.filled(totalDays, 0);
    for (int i = 0; i < totalDays; i++) {
      if (i % 2 == 0) {
        list[i] = 2 + ((i * 7) % 3);
      } else {
        list[i] = 0;
      }
    }
    return list;
  }

  /// Default starting preset: 100 Days of Code
  static HabitGridPost get initialDefault {
    const span = HabitTimeSpan.quarter;
    return HabitGridPost(
      habitTitle: '💻 100 Days of Code',
      habitSubtitle: 'Consistency is what transforms average into excellence.',
      yearLabel: '2026 CHALLENGE',
      authorHandle: '@alex_codes',
      timeSpan: span,
      theme: HabitColorTheme.githubDark,
      ratio: HabitRatio.portrait4x5,
      dotShape: HabitDotShape.roundedSquare,
      dotSpacing: 3.5,
      milestone: HabitMilestoneBadge.streak30,
      backdropIndex: 0,
      manualStreak: 45,
      tileIntensities: generatePattern(
        totalDays: span.totalDays,
        density: 0.78,
        endingStreak: 45,
      ),
    );
  }

  /// 4 Curated Viral Starter Templates
  static List<HabitGridPost> get viralTemplates => [
    // 1. 100 Days of Code (GitHub Emerald)
    HabitGridPost(
      habitTitle: '💻 100 Days of Code',
      habitSubtitle: 'Building in public. Showing up every single day.',
      yearLabel: '2026 TECH STREAK',
      authorHandle: '@dev_streak',
      timeSpan: HabitTimeSpan.quarter,
      theme: HabitColorTheme.githubDark,
      ratio: HabitRatio.portrait4x5,
      dotShape: HabitDotShape.roundedSquare,
      milestone: HabitMilestoneBadge.club100,
      backdropIndex: 0,
      manualStreak: 48,
      tileIntensities: generatePattern(
        totalDays: HabitTimeSpan.quarter.totalDays,
        density: 0.82,
        endingStreak: 48,
      ),
    ),

    // 2. 75 Hard Fitness & Gym (Fire Orange)
    HabitGridPost(
      habitTitle: '💪 75 Hard Fitness Streak',
      habitSubtitle: '2x workouts, clean diet, 1 gallon water, zero excuses.',
      yearLabel: 'FITNESS DISCIPLINE',
      authorHandle: '@marcus_fit',
      timeSpan: HabitTimeSpan.hundredDays,
      theme: HabitColorTheme.sunsetFire,
      ratio: HabitRatio.portrait4x5,
      dotShape: HabitDotShape.squircle,
      milestone: HabitMilestoneBadge.club50,
      backdropIndex: 0,
      manualStreak: 56,
      tileIntensities: generatePattern(
        totalDays: HabitTimeSpan.hundredDays.totalDays,
        density: 0.90,
        endingStreak: 56,
      ),
    ),

    // 3. Daily 30 Mins Reading (QuickPost Teal)
    HabitGridPost(
      habitTitle: '📚 Read 30 Mins Daily',
      habitSubtitle: 'Small daily steps compound into life-changing wisdom.',
      yearLabel: 'MINDSET 2026',
      authorHandle: '@growth_reads',
      timeSpan: HabitTimeSpan.halfYear,
      theme: HabitColorTheme.quickpostTeal,
      ratio: HabitRatio.square1x1,
      dotShape: HabitDotShape.circle,
      milestone: HabitMilestoneBadge.streak30,
      backdropIndex: 0,
      manualStreak: 72,
      tileIntensities: generatePattern(
        totalDays: HabitTimeSpan.halfYear.totalDays,
        density: 0.80,
        endingStreak: 72,
      ),
    ),

    // 4. Morning Meditation & Mindfulness (Neon Violet)
    HabitGridPost(
      habitTitle: '🧘 Morning Mindfulness',
      habitSubtitle: '10 minutes of quiet clarity before the world wakes up.',
      yearLabel: 'INNER PEACE',
      authorHandle: '@zen_journey',
      timeSpan: HabitTimeSpan.fullYear,
      theme: HabitColorTheme.electricViolet,
      ratio: HabitRatio.vertical9x16,
      dotShape: HabitDotShape.pixelSharp,
      milestone: HabitMilestoneBadge.unlocked365,
      backdropIndex: 0,
      manualStreak: 120,
      tileIntensities: generatePattern(
        totalDays: HabitTimeSpan.fullYear.totalDays,
        density: 0.85,
        endingStreak: 120,
      ),
    ),
  ];
}
