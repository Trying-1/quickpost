import 'package:flutter/material.dart';

/// Canvas aspect ratio choices for the music player card graphic.
enum MusicCardRatio {
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
    ratio: 0.0,
    icon: Icons.credit_card_rounded,
  );

  final String id;
  final String label;
  final double ratio;
  final IconData icon;

  const MusicCardRatio({
    required this.id,
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// Aesthetic player card themes.
enum MusicPlayerTheme {
  spotifyDark(
    name: 'Spotify Dark',
    cardBg: Color(0xFF121212),
    cardBorder: Color(0xFF282828),
    accentColor: Color(0xFF1DB954),
    primaryText: Colors.white,
    secondaryText: Color(0xFFB3B3B3),
  ),
  appleGlass(
    name: 'Apple Glass',
    cardBg: Color(0xCC1E1B2E),
    cardBorder: Color(0x4DFA2D48),
    accentColor: Color(0xFFFA2D48),
    primaryText: Colors.white,
    secondaryText: Color(0xFFA1A1AA),
  ),
  neonCyber(
    name: 'Neon Cyber',
    cardBg: Color(0xFF0F172A),
    cardBorder: Color(0xFF00E5FF),
    accentColor: Color(0xFF00E5FF),
    primaryText: Colors.white,
    secondaryText: Color(0xFF94A3B8),
  ),
  minimalWhite(
    name: 'Minimal White',
    cardBg: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE2E8F0),
    accentColor: Color(0xFF0F172A),
    primaryText: Color(0xFF0F172A),
    secondaryText: Color(0xFF64748B),
  );

  final String name;
  final Color cardBg;
  final Color cardBorder;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;

  const MusicPlayerTheme({
    required this.name,
    required this.cardBg,
    required this.cardBorder,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
  });
}

/// Curated backdrop presets for the canvas around the player card.
class MusicBackdropPreset {
  final String name;
  final List<Color> colors;

  const MusicBackdropPreset({required this.name, required this.colors});

  static const List<MusicBackdropPreset> presets = [
    MusicBackdropPreset(
      name: 'Midnight Fade',
      colors: [Color(0xFF0B0F19), Color(0xFF1E1B4B)],
    ),
    MusicBackdropPreset(
      name: 'Neon Violet',
      colors: [Color(0xFF180A2E), Color(0xFF3B0764)],
    ),
    MusicBackdropPreset(
      name: 'Crimson Dusk',
      colors: [Color(0xFF20070E), Color(0xFF4C0519)],
    ),
    MusicBackdropPreset(
      name: 'Deep Forest',
      colors: [Color(0xFF051B14), Color(0xFF064E3B)],
    ),
    MusicBackdropPreset(
      name: 'Warm Mocha',
      colors: [Color(0xFF1A120B), Color(0xFF3E2723)],
    ),
    MusicBackdropPreset(
      name: 'Solid Black',
      colors: [Color(0xFF0A0A0A), Color(0xFF0A0A0A)],
    ),
  ];
}

/// Domain configuration model representing the entire music player post.
class MusicCardPost {
  final String songTitle;
  final String artistName;
  final String? albumArtPath;
  final String currentTime;
  final String totalDuration;
  final double progressPercent; // 0.0 - 1.0
  final bool showLyrics;
  final String lyricsLine1;
  final String lyricsLine2;
  final String lyricsLine3;
  final int activeLyricIndex; // 0, 1, 2
  final MusicCardRatio ratio;
  final MusicPlayerTheme playerTheme;
  final int backdropIndex;
  final String? customWallpaperPath;
  final bool showControls;
  final bool showWaveform;
  final bool isLiked;

  const MusicCardPost({
    this.songTitle = 'Midnight City',
    this.artistName = 'M83 · Hurry Up, We\'re Dreaming',
    this.albumArtPath,
    this.currentTime = '1:24',
    this.totalDuration = '4:03',
    this.progressPercent = 0.35,
    this.showLyrics = true,
    this.lyricsLine1 = 'Waiting in a car',
    this.lyricsLine2 = 'Waiting for a ride in the dark',
    this.lyricsLine3 = 'The city is my church, it wraps in the blinding twilight',
    this.activeLyricIndex = 1,
    this.ratio = MusicCardRatio.portrait4x5,
    this.playerTheme = MusicPlayerTheme.spotifyDark,
    this.backdropIndex = 0,
    this.customWallpaperPath,
    this.showControls = true,
    this.showWaveform = true,
    this.isLiked = true,
  });

  MusicBackdropPreset get backdrop =>
      MusicBackdropPreset.presets[backdropIndex.clamp(0, MusicBackdropPreset.presets.length - 1)];

  MusicCardPost copyWith({
    String? songTitle,
    String? artistName,
    String? albumArtPath,
    String? currentTime,
    String? totalDuration,
    double? progressPercent,
    bool? showLyrics,
    String? lyricsLine1,
    String? lyricsLine2,
    String? lyricsLine3,
    int? activeLyricIndex,
    MusicCardRatio? ratio,
    MusicPlayerTheme? playerTheme,
    int? backdropIndex,
    String? customWallpaperPath,
    bool? showControls,
    bool? showWaveform,
    bool? isLiked,
    bool clearAlbumArt = false,
    bool clearWallpaper = false,
  }) {
    return MusicCardPost(
      songTitle: songTitle ?? this.songTitle,
      artistName: artistName ?? this.artistName,
      albumArtPath: clearAlbumArt ? null : (albumArtPath ?? this.albumArtPath),
      currentTime: currentTime ?? this.currentTime,
      totalDuration: totalDuration ?? this.totalDuration,
      progressPercent: progressPercent ?? this.progressPercent,
      showLyrics: showLyrics ?? this.showLyrics,
      lyricsLine1: lyricsLine1 ?? this.lyricsLine1,
      lyricsLine2: lyricsLine2 ?? this.lyricsLine2,
      lyricsLine3: lyricsLine3 ?? this.lyricsLine3,
      activeLyricIndex: activeLyricIndex ?? this.activeLyricIndex,
      ratio: ratio ?? this.ratio,
      playerTheme: playerTheme ?? this.playerTheme,
      backdropIndex: backdropIndex ?? this.backdropIndex,
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      showControls: showControls ?? this.showControls,
      showWaveform: showWaveform ?? this.showWaveform,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  /// Default starting music card
  static MusicCardPost get initialDefault => const MusicCardPost();

  /// Viral pre-configured templates
  static List<MusicCardPost> get viralTemplates => [
        // 1. Synthwave / Night Drive
        const MusicCardPost(
          songTitle: 'Starboy',
          artistName: 'The Weeknd · Daft Punk',
          currentTime: '2:15',
          totalDuration: '3:50',
          progressPercent: 0.58,
          showLyrics: true,
          lyricsLine1: 'I\'m in love with the feeling',
          lyricsLine2: 'Look what you\'ve done, I\'m a starboy',
          lyricsLine3: 'Every day a star is born, climb into the light',
          activeLyricIndex: 1,
          ratio: MusicCardRatio.portrait4x5,
          playerTheme: MusicPlayerTheme.appleGlass,
          backdropIndex: 1,
        ),

        // 2. Lofi Chill & Study
        const MusicCardPost(
          songTitle: 'Coffee & Rain ☕',
          artistName: 'Lofi Fruits Music · Peaceful Beats',
          currentTime: '1:02',
          totalDuration: '2:30',
          progressPercent: 0.40,
          showLyrics: true,
          lyricsLine1: 'Quiet mornings with warm coffee',
          lyricsLine2: 'Let the raindrops wash the noise away',
          lyricsLine3: 'Peace of mind in every gentle second',
          activeLyricIndex: 1,
          ratio: MusicCardRatio.square1x1,
          playerTheme: MusicPlayerTheme.spotifyDark,
          backdropIndex: 4,
        ),

        // 3. Motivational Gym / Energy
        const MusicCardPost(
          songTitle: 'Can\'t Be Touched',
          artistName: 'Roy Jones Jr. · Body Head Bangerz',
          currentTime: '0:45',
          totalDuration: '3:34',
          progressPercent: 0.22,
          showLyrics: true,
          lyricsLine1: 'Can\'t be touched, can\'t be stopped',
          lyricsLine2: 'When you put the work in, they can never take it',
          lyricsLine3: 'Relentless until the very last bell',
          activeLyricIndex: 1,
          ratio: MusicCardRatio.portrait4x5,
          playerTheme: MusicPlayerTheme.neonCyber,
          backdropIndex: 0,
        ),

        // 4. Romantic / Acoustic
        const MusicCardPost(
          songTitle: 'Golden Hour',
          artistName: 'JVKE · this is what ____ feels like',
          currentTime: '2:40',
          totalDuration: '3:29',
          progressPercent: 0.76,
          showLyrics: true,
          lyricsLine1: 'It was just two lovers',
          lyricsLine2: 'Sittin\' in the car, listening to Blonde',
          lyricsLine3: 'Falling for each other, pink and orange skies',
          activeLyricIndex: 1,
          ratio: MusicCardRatio.story9x16,
          playerTheme: MusicPlayerTheme.minimalWhite,
          backdropIndex: 2,
        ),
      ];
}

