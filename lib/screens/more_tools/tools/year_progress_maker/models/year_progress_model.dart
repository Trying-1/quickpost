import 'package:flutter/material.dart';

/// Layout arrangement for the 365-day dots visualization.
enum YearGridLayout {
  matrix(
    id: 'matrix',
    label: '365 Dot Matrix',
    subtitle: 'Full continuous 365 dots matrix',
    icon: Icons.grid_view_rounded,
  ),
  monthBlocks(
    id: 'month_blocks',
    label: '12 Month Clusters',
    subtitle: 'Grouped by Jan–Dec monthly calendars',
    icon: Icons.calendar_month_rounded,
  ),
  stream(
    id: 'stream',
    label: 'Progress Bar & Stats',
    subtitle: 'Large linear progress & summary breakdown',
    icon: Icons.linear_scale_rounded,
  );

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  const YearGridLayout({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

/// Canvas format / aspect ratio.
enum YearRatio {
  portrait4x5(id: '4:5 Feed', widthRatio: 4, heightRatio: 5, icon: Icons.crop_portrait_rounded),
  square1x1(id: '1:1 Square', widthRatio: 1, heightRatio: 1, icon: Icons.crop_square_rounded),
  vertical9x16(id: '9:16 Story', widthRatio: 9, heightRatio: 16, icon: Icons.stay_current_portrait_rounded),
  cardOnly(id: 'Card Only', widthRatio: 1, heightRatio: 1, icon: Icons.view_compact_rounded);

  final String id;
  final double widthRatio;
  final double heightRatio;
  final IconData icon;

  const YearRatio({
    required this.id,
    required this.widthRatio,
    required this.heightRatio,
    required this.icon,
  });

  double get aspectRatio => widthRatio / heightRatio;
}

/// Dot shape options for individual day dots (Circular to Square).
enum YearDotShape {
  circle(id: 'circle', label: 'Circle', radius: 12.0, icon: Icons.circle),
  squircle(id: 'squircle', label: 'Squircle', radius: 5.0, icon: Icons.circle_outlined),
  roundedSquare(id: 'rounded', label: 'Rounded', radius: 2.5, icon: Icons.crop_square_rounded),
  pixelSharp(id: 'sharp', label: '8-Bit Sharp', radius: 0.0, icon: Icons.square_outlined);

  final String id;
  final String label;
  final double radius;
  final IconData icon;

  const YearDotShape({
    required this.id,
    required this.label,
    required this.radius,
    required this.icon,
  });
}

/// Visual theme palettes for the Year Progress post.
enum YearTheme {
  oledDark(
    id: 'oled_dark',
    name: 'OLED Cyber Dark',
    cardBg: Color(0xFF090D16),
    cardBorder: Color(0xFF1E293B),
    primaryText: Colors.white,
    secondaryText: Color(0xFF94A3B8),
    passedColor: Color(0xFF10B981),
    todayColor: Color(0xFF38BDF8),
    remainingColor: Color(0xFF1E293B),
    progressBarGradient: [Color(0xFF059669), Color(0xFF34D399)],
  ),
  quickpostTeal(
    id: 'quickpost_teal',
    name: 'QuickPost Teal',
    cardBg: Color(0xFF041C19),
    cardBorder: Color(0xFF004D40),
    primaryText: Colors.white,
    secondaryText: Color(0xFF80CBC4),
    passedColor: Color(0xFF00897B),
    todayColor: Color(0xFF80CBC4),
    remainingColor: Color(0xFF0B332F),
    progressBarGradient: [Color(0xFF004D40), Color(0xFF26A69A)],
  ),
  sunsetFire(
    id: 'sunset_fire',
    name: 'Countdown Fire',
    cardBg: Color(0xFF180A04),
    cardBorder: Color(0xFF4A1B07),
    primaryText: Colors.white,
    secondaryText: Color(0xFFFDBA74),
    passedColor: Color(0xFFEA580C),
    todayColor: Color(0xFFFACC15),
    remainingColor: Color(0xFF2E1308),
    progressBarGradient: [Color(0xFFC2410C), Color(0xFFFB923C)],
  ),
  electricPurple(
    id: 'electric_purple',
    name: 'Neon Violet',
    cardBg: Color(0xFF100726),
    cardBorder: Color(0xFF341566),
    primaryText: Colors.white,
    secondaryText: Color(0xFFC084FC),
    passedColor: Color(0xFF9333EA),
    todayColor: Color(0xFFE879F9),
    remainingColor: Color(0xFF200F42),
    progressBarGradient: [Color(0xFF7E22CE), Color(0xFFC084FC)],
  ),
  cyberCyan(
    id: 'cyber_cyan',
    name: 'Glacier Blue',
    cardBg: Color(0xFF051622),
    cardBorder: Color(0xFF0B354F),
    primaryText: Colors.white,
    secondaryText: Color(0xFF7DD3FC),
    passedColor: Color(0xFF0284C7),
    todayColor: Color(0xFF38BDF8),
    remainingColor: Color(0xFF0C2B3E),
    progressBarGradient: [Color(0xFF0369A1), Color(0xFF38BDF8)],
  ),
  cleanWhite(
    id: 'clean_white',
    name: 'Minimal White',
    cardBg: Colors.white,
    cardBorder: Color(0xFFE2E8F0),
    primaryText: Color(0xFF0F172A),
    secondaryText: Color(0xFF64748B),
    passedColor: Color(0xFF0F172A),
    todayColor: Color(0xFF10B981),
    remainingColor: Color(0xFFE2E8F0),
    progressBarGradient: [Color(0xFF334155), Color(0xFF0F172A)],
  );

  final String id;
  final String name;
  final Color cardBg;
  final Color cardBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color passedColor;
  final Color todayColor;
  final Color remainingColor;
  final List<Color> progressBarGradient;

  const YearTheme({
    required this.id,
    required this.name,
    required this.cardBg,
    required this.cardBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.passedColor,
    required this.todayColor,
    required this.remainingColor,
    required this.progressBarGradient,
  });
}

/// Curated gradient presets for canvas backdrop.
class YearBackdropPreset {
  final String name;
  final List<Color> colors;

  const YearBackdropPreset({required this.name, required this.colors});

  static const List<YearBackdropPreset> presets = [
    YearBackdropPreset(
      name: 'Pure Card Background',
      colors: [Color(0xFF090D16), Color(0xFF090D16)],
    ),
    YearBackdropPreset(
      name: 'Deep Midnight Slate',
      colors: [Color(0xFF0B0F19), Color(0xFF1E293B)],
    ),
    YearBackdropPreset(
      name: 'Emerald Aurora',
      colors: [Color(0xFF022C22), Color(0xFF064E3B)],
    ),
    YearBackdropPreset(
      name: 'Cosmic Violet',
      colors: [Color(0xFF180A2E), Color(0xFF2E1065)],
    ),
    YearBackdropPreset(
      name: 'Warm Obsidian',
      colors: [Color(0xFF1C1917), Color(0xFF292524)],
    ),
  ];
}

/// Curated viral time & year reflection quotes.
class YearQuotesLibrary {
  static const List<String> quotes = [
    'Time is the only non-renewable resource you have.',
    'You cannot pause the year. Make every single day count.',
    'Don’t count the days. Make the days count.',
    'The days are long, but the years are short.',
    'It’s not about having time, it’s about making time.',
    '68% of the year has slipped away. What will you do with the rest?',
    'Action cures anxiety. Build what matters today.',
    'One day or Day One? The clock is running.',
    'You do not lack time, you lack focus.',
    'Finish the year stronger than you started.',
  ];
}

/// Core data model representing the Year Progress graphic.
class YearProgressPost {
  final int year;
  final int currentDayOfYear; // 1 to 365 (or 366)
  final int totalDaysInYear; // 365 or 366
  final String title;
  final String subtitle;
  final String authorHandle;
  final String? authorAvatarPath;
  final YearGridLayout layout;
  final YearDotShape dotShape;
  final double dotSpacing;
  final YearTheme theme;
  final YearRatio ratio;
  final int backdropIndex;
  final String? customWallpaperPath;
  final bool transparentBg;
  final bool showProgressBar;
  final bool showStatsBadges;
  final bool showAuthorBadge;
  final bool highlightToday;

  const YearProgressPost({
    required this.year,
    required this.currentDayOfYear,
    this.totalDaysInYear = 365,
    required this.title,
    required this.subtitle,
    required this.authorHandle,
    this.authorAvatarPath,
    this.layout = YearGridLayout.matrix,
    this.dotShape = YearDotShape.circle,
    this.dotSpacing = 3.0,
    required this.theme,
    required this.ratio,
    required this.backdropIndex,
    this.customWallpaperPath,
    this.transparentBg = false,
    this.showProgressBar = true,
    this.showStatsBadges = true,
    this.showAuthorBadge = true,
    this.highlightToday = true,
  });

  /// Percentage of year completed (0.0 to 100.0).
  double get percentageCompleted => (currentDayOfYear / totalDaysInYear) * 100.0;

  /// Number of days remaining in the year.
  int get daysRemaining => totalDaysInYear - currentDayOfYear;

  /// Weeks remaining in the year.
  int get weeksRemaining => (daysRemaining / 7).ceil();

  /// Estimated current month (1..12).
  int get currentMonth {
    final now = DateTime(year, 1, 1).add(Duration(days: currentDayOfYear - 1));
    return now.month;
  }

  /// Formatted date string for current day (e.g. "September 13, 2026").
  String get formattedCurrentDate {
    final now = DateTime(year, 1, 1).add(Duration(days: currentDayOfYear - 1));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, $year';
  }

  YearProgressPost copyWith({
    int? year,
    int? currentDayOfYear,
    int? totalDaysInYear,
    String? title,
    String? subtitle,
    String? authorHandle,
    String? authorAvatarPath,
    bool clearAvatar = false,
    YearGridLayout? layout,
    YearDotShape? dotShape,
    double? dotSpacing,
    YearTheme? theme,
    YearRatio? ratio,
    int? backdropIndex,
    String? customWallpaperPath,
    bool clearWallpaper = false,
    bool? transparentBg,
    bool? showProgressBar,
    bool? showStatsBadges,
    bool? showAuthorBadge,
    bool? highlightToday,
  }) {
    return YearProgressPost(
      year: year ?? this.year,
      currentDayOfYear: currentDayOfYear ?? this.currentDayOfYear,
      totalDaysInYear: totalDaysInYear ?? this.totalDaysInYear,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      authorHandle: authorHandle ?? this.authorHandle,
      authorAvatarPath: clearAvatar ? null : (authorAvatarPath ?? this.authorAvatarPath),
      layout: layout ?? this.layout,
      dotShape: dotShape ?? this.dotShape,
      dotSpacing: dotSpacing ?? this.dotSpacing,
      theme: theme ?? this.theme,
      ratio: ratio ?? this.ratio,
      backdropIndex: backdropIndex ?? this.backdropIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      transparentBg: transparentBg ?? this.transparentBg,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      showStatsBadges: showStatsBadges ?? this.showStatsBadges,
      showAuthorBadge: showAuthorBadge ?? this.showAuthorBadge,
      highlightToday: highlightToday ?? this.highlightToday,
    );
  }

  /// Computes day of year for today's date.
  static int computeDayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  /// Default starting configuration.
  static YearProgressPost get initialDefault {
    final now = DateTime.now();
    final year = now.year;
    final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    final totalDays = isLeap ? 366 : 365;
    final dayOfYear = computeDayOfYear(now).clamp(1, totalDays);

    return YearProgressPost(
      year: year,
      currentDayOfYear: dayOfYear,
      totalDaysInYear: totalDays,
      title: '$year YEAR PROGRESS',
      subtitle: 'Time waits for no one. Make every single day count.',
      authorHandle: '@year_tracker',
      layout: YearGridLayout.matrix,
      dotShape: YearDotShape.circle,
      dotSpacing: 3.0,
      theme: YearTheme.oledDark,
      ratio: YearRatio.portrait4x5,
      backdropIndex: 0,
      showProgressBar: true,
      showStatsBadges: true,
      showAuthorBadge: true,
      highlightToday: true,
    );
  }

  /// 4 Curated Viral Starter Presets
  static List<YearProgressPost> get viralPresets {
    final now = DateTime.now();
    final year = now.year;

    return [
      // 1. Current Live Date
      YearProgressPost(
        year: year,
        currentDayOfYear: computeDayOfYear(now),
        title: '$year YEAR IN PROGRESS',
        subtitle: 'The days are long, but the years are short.',
        authorHandle: '@live_progress',
        layout: YearGridLayout.matrix,
        dotShape: YearDotShape.circle,
        theme: YearTheme.oledDark,
        ratio: YearRatio.portrait4x5,
        backdropIndex: 0,
      ),

      // 2. Final 100 Days Countdown
      YearProgressPost(
        year: year,
        currentDayOfYear: 265, // exactly 100 days remaining
        title: '⏳ FINAL 100 DAYS OF $year',
        subtitle: '100 days left to achieve the goals you promised yourself.',
        authorHandle: '@100_days_push',
        layout: YearGridLayout.monthBlocks,
        dotShape: YearDotShape.roundedSquare,
        theme: YearTheme.sunsetFire,
        ratio: YearRatio.portrait4x5,
        backdropIndex: 0,
      ),

      // 3. Half-Year Milestone (50% Reached)
      YearProgressPost(
        year: year,
        currentDayOfYear: 182, // mid year
        title: '🎯 $year MID-YEAR AUDIT',
        subtitle: '50% of the year is done. How is your vision coming along?',
        authorHandle: '@quarter_review',
        layout: YearGridLayout.matrix,
        dotShape: YearDotShape.squircle,
        theme: YearTheme.quickpostTeal,
        ratio: YearRatio.square1x1,
        backdropIndex: 0,
      ),

      // 4. Memento Mori / 9:16 Story Reel
      YearProgressPost(
        year: year,
        currentDayOfYear: computeDayOfYear(now),
        title: 'MEMENTO MORI $year',
        subtitle: 'Time is slipping. You do not lack time, you lack focus.',
        authorHandle: '@mindset_shift',
        layout: YearGridLayout.stream,
        dotShape: YearDotShape.circle,
        theme: YearTheme.electricPurple,
        ratio: YearRatio.vertical9x16,
        backdropIndex: 0,
      ),
    ];
  }
}

