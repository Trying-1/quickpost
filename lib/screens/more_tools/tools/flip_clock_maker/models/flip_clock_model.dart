import 'package:flutter/material.dart';

/// Display archetype for the Retro Flip Clock & Countdown studio.
enum FlipClockMode {
  eventCountdown(label: 'Event Countdown', icon: Icons.event_available_rounded),
  classicClock(label: 'Desk Flip Clock', icon: Icons.access_time_filled_rounded),
  focusTimer(label: 'Deep Focus Timer', icon: Icons.timer_rounded);

  final String label;
  final IconData icon;
  const FlipClockMode({required this.label, required this.icon});
}

/// Canvas aspect ratio choices.
enum FlipClockRatio {
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
  clockOnly(
    id: 'Clock',
    label: 'Clock Only (Overlay)',
    ratio: 0.0,
    icon: Icons.flip_to_front_rounded,
  );

  final String id;
  final String label;
  final double ratio;
  final IconData icon;

  const FlipClockRatio({
    required this.id,
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// Mechanical split-flap color themes.
enum FlipClockTheme {
  classicVintage(
    name: 'Vintage Flap',
    tileBgTop: Color(0xFF222225),
    tileBgBottom: Color(0xFF18181B),
    digitColor: Color(0xFFF5F5F4),
    accentColor: Color(0xFFF59E0B),
    canvasBg: Color(0xFF09090B),
    labelColor: Color(0xFFA1A1AA),
    dividerColor: Color(0xFF000000),
  ),
  airportBoard(
    name: 'Airport Board',
    tileBgTop: Color(0xFF1E293B),
    tileBgBottom: Color(0xFF0F172A),
    digitColor: Color(0xFFFACC15),
    accentColor: Color(0xFFFACC15),
    canvasBg: Color(0xFF020617),
    labelColor: Color(0xFF94A3B8),
    dividerColor: Color(0xFF020617),
  ),
  neonCyber(
    name: 'Neon Cyber',
    tileBgTop: Color(0xFF17153B),
    tileBgBottom: Color(0xFF0F0E26),
    digitColor: Color(0xFF00E5FF),
    accentColor: Color(0xFFEC4899),
    canvasBg: Color(0xFF090D16),
    labelColor: Color(0xFF94A3B8),
    dividerColor: Color(0xFF05080F),
  ),
  aestheticCream(
    name: 'Warm Cream',
    tileBgTop: Color(0xFF292524),
    tileBgBottom: Color(0xFF1C1917),
    digitColor: Color(0xFFFAF7F2),
    accentColor: Color(0xFFD97706),
    canvasBg: Color(0xFFF5F5F0),
    labelColor: Color(0xFF57534E),
    dividerColor: Color(0xFF0C0A09),
  ),
  matchaDesk(
    name: 'Matcha Desk',
    tileBgTop: Color(0xFF14532D),
    tileBgBottom: Color(0xFF052E16),
    digitColor: Color(0xFF4ADE80),
    accentColor: Color(0xFF22C55E),
    canvasBg: Color(0xFF022C22),
    labelColor: Color(0xFF86EFAC),
    dividerColor: Color(0xFF021F0E),
  ),
  minimalWhite(
    name: 'Minimal White',
    tileBgTop: Color(0xFFF1F5F9),
    tileBgBottom: Color(0xFFE2E8F0),
    digitColor: Color(0xFF0F172A),
    accentColor: Color(0xFF00796B),
    canvasBg: Color(0xFFFFFFFF),
    labelColor: Color(0xFF64748B),
    dividerColor: Color(0xFFCBD5E1),
  );

  final String name;
  final Color tileBgTop;
  final Color tileBgBottom;
  final Color digitColor;
  final Color accentColor;
  final Color canvasBg;
  final Color labelColor;
  final Color dividerColor;

  const FlipClockTheme({
    required this.name,
    required this.tileBgTop,
    required this.tileBgBottom,
    required this.digitColor,
    required this.accentColor,
    required this.canvasBg,
    required this.labelColor,
    required this.dividerColor,
  });
}

/// Curated backdrop gradients for the flip clock canvas.
class FlipClockBackdropPreset {
  final String name;
  final List<Color> colors;

  const FlipClockBackdropPreset({required this.name, required this.colors});

  static const List<FlipClockBackdropPreset> presets = [
    FlipClockBackdropPreset(
      name: 'Obsidian Matte',
      colors: [Color(0xFF09090B), Color(0xFF18181B)],
    ),
    FlipClockBackdropPreset(
      name: 'Cyber Indigo',
      colors: [Color(0xFF0B0F19), Color(0xFF1E1B4B)],
    ),
    FlipClockBackdropPreset(
      name: 'Sunset Ember',
      colors: [Color(0xFF240B13), Color(0xFF4C0519)],
    ),
    FlipClockBackdropPreset(
      name: 'Emerald Studio',
      colors: [Color(0xFF041C15), Color(0xFF064E3B)],
    ),
    FlipClockBackdropPreset(
      name: 'Warm Coffee',
      colors: [Color(0xFF1C130D), Color(0xFF3E2723)],
    ),
    FlipClockBackdropPreset(
      name: 'Linen Minimal',
      colors: [Color(0xFFF5F5F0), Color(0xFFE7E5E4)],
    ),
  ];
}

/// Domain configuration model for Retro Flip Clock & Event Countdown Studio.
class FlipClockPost {
  final FlipClockMode mode;
  final String eventTitle;
  final String eventSubtitle;
  final String unit1Value;
  final String unit1Label;
  final String unit2Value;
  final String unit2Label;
  final String unit3Value;
  final String unit3Label;
  final String unit4Value;
  final String unit4Label;
  final bool showUnit4;
  final String amPmBadge;
  final bool showProgressBar;
  final double progressPercent;
  final String progressLabel;
  final String creatorHandle;
  final FlipClockTheme theme;
  final FlipClockRatio ratio;
  final int backdropIndex;
  final String? customWallpaperPath;
  final bool transparentBg;

  const FlipClockPost({
    this.mode = FlipClockMode.eventCountdown,
    this.eventTitle = 'NEW YEAR 2027',
    this.eventSubtitle = 'COUNTDOWN TO JANUARY 1 • MIDNIGHT',
    this.unit1Value = '52',
    this.unit1Label = 'DAYS',
    this.unit2Value = '12',
    this.unit2Label = 'HOURS',
    this.unit3Value = '45',
    this.unit3Label = 'MINS',
    this.unit4Value = '18',
    this.unit4Label = 'SECS',
    this.showUnit4 = false,
    this.amPmBadge = 'LIVE',
    this.showProgressBar = true,
    this.progressPercent = 0.86,
    this.progressLabel = '86% OF 2026 COMPLETED',
    this.creatorHandle = '@quickpost.studio',
    this.theme = FlipClockTheme.classicVintage,
    this.ratio = FlipClockRatio.portrait4x5,
    this.backdropIndex = 0,
    this.customWallpaperPath,
    this.transparentBg = false,
  });

  FlipClockBackdropPreset get backdrop =>
      FlipClockBackdropPreset.presets[backdropIndex.clamp(0, FlipClockBackdropPreset.presets.length - 1)];

  FlipClockPost copyWith({
    FlipClockMode? mode,
    String? eventTitle,
    String? eventSubtitle,
    String? unit1Value,
    String? unit1Label,
    String? unit2Value,
    String? unit2Label,
    String? unit3Value,
    String? unit3Label,
    String? unit4Value,
    String? unit4Label,
    bool? showUnit4,
    String? amPmBadge,
    bool? showProgressBar,
    double? progressPercent,
    String? progressLabel,
    String? creatorHandle,
    FlipClockTheme? theme,
    FlipClockRatio? ratio,
    int? backdropIndex,
    String? customWallpaperPath,
    bool? transparentBg,
    bool clearWallpaper = false,
  }) {
    return FlipClockPost(
      mode: mode ?? this.mode,
      eventTitle: eventTitle ?? this.eventTitle,
      eventSubtitle: eventSubtitle ?? this.eventSubtitle,
      unit1Value: unit1Value ?? this.unit1Value,
      unit1Label: unit1Label ?? this.unit1Label,
      unit2Value: unit2Value ?? this.unit2Value,
      unit2Label: unit2Label ?? this.unit2Label,
      unit3Value: unit3Value ?? this.unit3Value,
      unit3Label: unit3Label ?? this.unit3Label,
      unit4Value: unit4Value ?? this.unit4Value,
      unit4Label: unit4Label ?? this.unit4Label,
      showUnit4: showUnit4 ?? this.showUnit4,
      amPmBadge: amPmBadge ?? this.amPmBadge,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      progressPercent: progressPercent ?? this.progressPercent,
      progressLabel: progressLabel ?? this.progressLabel,
      creatorHandle: creatorHandle ?? this.creatorHandle,
      theme: theme ?? this.theme,
      ratio: ratio ?? this.ratio,
      backdropIndex: backdropIndex ?? this.backdropIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      transparentBg: transparentBg ?? this.transparentBg,
    );
  }

  /// Calculates remaining Days/Hours/Minutes/Seconds to any selected target DateTime.
  FlipClockPost withTargetDate(DateTime target) {
    final now = DateTime.now();
    final diff = target.isAfter(now) ? target.difference(now) : Duration.zero;
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    final secs = diff.inSeconds % 60;

    return copyWith(
      mode: FlipClockMode.eventCountdown,
      unit1Value: days < 10 ? '0$days' : '$days',
      unit1Label: 'DAYS',
      unit2Value: hours < 10 ? '0$hours' : '$hours',
      unit2Label: 'HOURS',
      unit3Value: mins < 10 ? '0$mins' : '$mins',
      unit3Label: 'MINS',
      unit4Value: secs < 10 ? '0$secs' : '$secs',
      unit4Label: 'SECS',
    );
  }

  static FlipClockPost get initialDefault => const FlipClockPost();

  static List<FlipClockPost> get viralPresets => [
        // 1. New Year Countdown
        initialDefault,

        // 2. Aesthetic Desk Flip Clock
        const FlipClockPost(
          mode: FlipClockMode.classicClock,
          eventTitle: 'AESTHETIC STUDY DESK',
          eventSubtitle: 'TUE NOV 10, 2026 • LATE NIGHT GRIND',
          unit1Value: '11',
          unit1Label: 'HOUR',
          unit2Value: '15',
          unit2Label: 'MINUTE',
          unit3Value: '42',
          unit3Label: 'SECOND',
          showUnit4: false,
          amPmBadge: 'AM',
          showProgressBar: false,
          theme: FlipClockTheme.aestheticCream,
          backdropIndex: 5,
        ),

        // 3. Deep Focus Pomodoro
        const FlipClockPost(
          mode: FlipClockMode.focusTimer,
          eventTitle: 'DEEP WORK SESSION',
          eventSubtitle: 'NO DISTRACTIONS • LOCK IN MODE',
          unit1Value: '50',
          unit1Label: 'MINS',
          unit2Value: '00',
          unit2Label: 'SECS',
          unit3Value: '02',
          unit3Label: 'CYCLE',
          showUnit4: false,
          amPmBadge: 'FOCUS',
          showProgressBar: true,
          progressPercent: 0.65,
          progressLabel: 'SESSION 2 OF 4 IN PROGRESS',
          theme: FlipClockTheme.matchaDesk,
          backdropIndex: 3,
        ),

        // 4. Airport Departure Board Launch
        const FlipClockPost(
          mode: FlipClockMode.eventCountdown,
          eventTitle: 'TOKYO FLIGHT DEPARTURE ✈️',
          eventSubtitle: 'GATE B12 • BOARDING SOON',
          unit1Value: '14',
          unit1Label: 'DAYS',
          unit2Value: '08',
          unit2Label: 'HOURS',
          unit3Value: '20',
          unit3Label: 'MINS',
          unit4Value: '00',
          unit4Label: 'SECS',
          showUnit4: true,
          amPmBadge: 'ON TIME',
          showProgressBar: true,
          progressPercent: 0.90,
          progressLabel: 'PACKING CHECKLIST 90% READY',
          theme: FlipClockTheme.airportBoard,
          backdropIndex: 0,
        ),
      ];
}

