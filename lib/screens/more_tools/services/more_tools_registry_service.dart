import 'package:flutter/material.dart';
import '../models/misc_tool_item.dart';
import '../tools/grid_post_maker/grid_post_maker_screen.dart';
import '../tools/collage_maker/collage_maker_screen.dart';
import '../tools/audio_extractor/audio_extractor_screen.dart';
import '../tools/aspect_ratio_calculator/widgets/aspect_ratio_calculator_sheet.dart';
import '../tools/hashtag_vault/widgets/hashtag_vault_sheet.dart';
import '../tools/color_palette/color_palette_screen.dart';
import '../tools/photo_color_fx/photo_color_fx_screen.dart';
import '../tools/dummy_chat_maker/dummy_chat_maker_screen.dart';
import '../tools/poll_quiz_maker/poll_quiz_maker_screen.dart';
import '../tools/social_post_maker/social_post_maker_screen.dart';
import '../tools/music_lyrics_maker/music_lyrics_maker_screen.dart';
import '../tools/notification_maker/notification_maker_screen.dart';
import '../tools/habit_tracker_maker/habit_tracker_maker_screen.dart';
import '../tools/year_progress_maker/year_progress_maker_screen.dart';
import '../tools/receipt_maker/receipt_maker_screen.dart';
import '../tools/flip_clock_maker/flip_clock_maker_screen.dart';
import '../tools/pixel_art_maker/pixel_art_maker_screen.dart';
import '../tools/shape_mask_maker/shape_mask_maker_screen.dart';
import '../tools/ascii_art_maker/ascii_art_maker_screen.dart';
import '../tools/anime_db/anime_db_studio_screen.dart';
import '../../font_library/font_library_screen.dart';
import '../../background_remover/background_remover_screen.dart';
import '../../caption_store/caption_store_screen.dart';
import '../../audio_library/audio_library_screen_with_folders.dart';
import '../../tutorials/tutorials_screen.dart';

/// Central registry service responsible for managing, registering,
/// and searching miscellaneous tools.
class MoreToolsRegistryService {
  static final MoreToolsRegistryService _instance = MoreToolsRegistryService._internal();
  factory MoreToolsRegistryService() => _instance;
  MoreToolsRegistryService._internal();

  /// Default tool catalog registered in the hub.
  final List<MiscToolItem> _coreTools = [
    // ─── Quick Built-in Utilities ───
    MiscToolItem(
      id: 'audio_extractor',
      title: 'Audio Extractor',
      description: 'Extract MP3, lossless WAV, or AAC audio tracks from any video directly to Music gallery',
      icon: Icons.music_note_rounded,
      accentColor: const Color(0xFFFF7043),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'MP3 / WAV',
      badgeColor: const Color(0xFFF4511E),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AudioExtractorScreen()),
      ),
    ),
    MiscToolItem(
      id: 'grid_post_maker',
      title: '3-Post Profile Grid Maker',
      description: 'Split single landscape or banner images into seamless 3-post social profile rows',
      icon: Icons.view_column_rounded,
      accentColor: const Color(0xFFD81B60),
      category: MiscToolCategory.quickUtilities,
      badgeText: '3-Post Grid',
      badgeColor: const Color(0xFFC2185B),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const GridPostMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'collage_maker',
      title: 'New Grid Maker',
      description: 'Create beautiful photo collages with flexible grid layouts, borders, ratios & background styles',
      icon: Icons.dashboard_customize_rounded,
      accentColor: const Color(0xFF6C63FF),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Grid Collage',
      badgeColor: const Color(0xFF5B52E5),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const CollageMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'aspect_ratio_calc',
      title: 'Aspect Ratio Calculator',
      description: 'Instant resolution & dimensions calculation for 9:16, 4:5, 1:1, and 16:9',
      icon: Icons.aspect_ratio_rounded,
      accentColor: const Color(0xFF00897B),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Built-in',
      badgeColor: const Color(0xFF00796B),
      onTap: (ctx) => AspectRatioCalculatorSheet.show(ctx),
    ),
    MiscToolItem(
      id: 'viral_hashtags',
      title: 'Viral Hashtags Vault',
      description: 'Curated 1-tap copy hashtag bundles for Reels, TikTok, Anime, and Quotes',
      icon: Icons.tag_rounded,
      accentColor: const Color(0xFF7C4DFF),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Built-in',
      badgeColor: const Color(0xFF651FFF),
      onTap: (ctx) => HashtagVaultSheet.show(ctx),
    ),
    MiscToolItem(
      id: 'photo_color_fx',
      title: 'Photo Inverter & B&W FX',
      description: 'Color negative inversion, dramatic noir black & white, sepia, and analog monochrome effects',
      icon: Icons.invert_colors_rounded,
      accentColor: const Color(0xFF00E5FF),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Invert & B&W',
      badgeColor: const Color(0xFF00B0FF),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const PhotoColorFxScreen()),
      ),
    ),
    MiscToolItem(
      id: 'palette_contrast',
      title: 'Color Palette Studio',
      description: 'Extract palettes from photos, create harmonic schemes, test WCAG contrast, and export swatch cards to gallery',
      icon: Icons.palette_rounded,
      accentColor: const Color(0xFFFF6D00),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Extract & Export',
      badgeColor: const Color(0xFFE65100),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const ColorPaletteScreen()),
      ),
    ),
    MiscToolItem(
      id: 'dummy_chat_maker',
      title: 'Dummy Chat Creator',
      description: 'Create simulated iOS, Social DM & Green Chat viral conversation screenshots for Reels, Shorts & TikTok',
      icon: Icons.chat_bubble_outline_rounded,
      accentColor: const Color(0xFF007AFF),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Viral Chats',
      badgeColor: const Color(0xFF0051A8),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const DummyChatMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'poll_quiz_maker',
      title: 'Poll & Quiz Studio',
      description: 'Create viral 4-option trivia, This or That (VS), percentage polls, and debate graphics for Reels & Shorts',
      icon: Icons.poll_outlined,
      accentColor: const Color(0xFFF59E0B),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Trivia & VS',
      badgeColor: const Color(0xFFD97706),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const PollQuizMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'social_post_maker',
      title: 'Social Post / Tweet Studio',
      description: 'Create viral social tweet cards with verified badges, engagement metrics, and overlay cards for Reels & Shorts',
      icon: Icons.alternate_email_rounded,
      accentColor: const Color(0xFF1D9BF0),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Tweet Cards',
      badgeColor: const Color(0xFF0C7ABF),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const SocialPostMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'music_lyrics_maker',
      title: 'Music & Lyrics Studio',
      description: 'Create aesthetic "Now Playing" audio cards with equalizer waveforms and lyrics highlights for Reels & Stories',
      icon: Icons.music_note_rounded,
      accentColor: const Color(0xFF1DB954),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Lyrics & Audio',
      badgeColor: const Color(0xFF15803D),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const MusicLyricsMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'notification_maker',
      title: 'Push Notification Studio',
      description: 'Generate realistic lock screen push notification alerts, deposits, and stacked messages for hook videos',
      icon: Icons.notifications_active_rounded,
      accentColor: const Color(0xFF00E5FF),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Hook Alerts',
      badgeColor: const Color(0xFF0284C7),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const NotificationMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'habit_tracker_maker',
      title: 'Habit & Streak Studio',
      description: 'Create GitHub commit-style square dot contribution cards and habit streak graphics for Reels & Shorts',
      icon: Icons.grid_view_rounded,
      accentColor: const Color(0xFF10B981),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Habit Heatmap',
      badgeColor: const Color(0xFF059669),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const HabitTrackerMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'year_progress_maker',
      title: 'Year Progress & 365 Days',
      description: 'Create aesthetic 365-day calendar dot matrix, year progress bar, and days left countdown graphics for Reels & Stories',
      icon: Icons.hourglass_bottom_rounded,
      accentColor: const Color(0xFFF97316),
      category: MiscToolCategory.quickUtilities,
      badgeText: '365 Dots',
      badgeColor: const Color(0xFFEA580C),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const YearProgressMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'receipt_maker',
      title: 'Thermal Receipt Studio',
      description: 'Generate viral "Receiptify" cash register receipts for music playlists, daily habits, coffee runs, and year goals',
      icon: Icons.receipt_long_rounded,
      accentColor: const Color(0xFF00796B),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Receiptify',
      badgeColor: const Color(0xFF004D40),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const ReceiptMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'flip_clock_maker',
      title: 'Retro Flip Clock & Countdown',
      description: 'Create aesthetic split-flap mechanical flip clocks, event countdowns, and focus timers for Reels & Stories',
      icon: Icons.flip_to_front_rounded,
      accentColor: const Color(0xFFEAB308),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Split-Flap',
      badgeColor: const Color(0xFFCA8A04),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const FlipClockMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'pixel_art_maker',
      title: '8-Bit Pixel Art Studio',
      description: 'Pixelify photos into authentic Game Boy, NES, PICO-8, Arcade CRT & Win95 pixel art with Bayer dithering',
      icon: Icons.grid_4x4_rounded,
      accentColor: const Color(0xFF8B5CF6),
      category: MiscToolCategory.quickUtilities,
      badgeText: '8-Bit Pixel',
      badgeColor: const Color(0xFF7C3AED),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const PixelArtMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'shape_mask_maker',
      title: 'Shape Mask & Cutout Studio',
      description: 'Draw rectangles, circles, polygons & split lines with custom borders and tap closed areas to reveal or mask photos below',
      icon: Icons.auto_awesome_mosaic_rounded,
      accentColor: const Color(0xFF00796B),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'Mask & Split',
      badgeColor: const Color(0xFF004D40),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const ShapeMaskMakerScreen()),
      ),
    ),
    MiscToolItem(
      id: 'ascii_art_maker',
      title: 'ASCII Art Studio',
      description: 'Convert photos into Matrix terminals, ANSI shade blocks, True-Color typographic posters & copyable ASCII text',
      icon: Icons.terminal_rounded,
      accentColor: const Color(0xFF10B981),
      category: MiscToolCategory.quickUtilities,
      badgeText: 'ASCII FX',
      badgeColor: const Color(0xFF059669),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AsciiArtMakerScreen()),
      ),
    ),

    // ─── Creative Studios & Libraries ───
    MiscToolItem(
      id: 'anime_db_studio',
      title: 'Anime Database Studio',
      description: 'Explore, curate & manage your local anime vault. Filter by genre/studio, link tagged artwork, and prompt LLMs offline without APIs',
      icon: Icons.video_library_rounded,
      accentColor: const Color(0xFF6366F1),
      category: MiscToolCategory.librariesAndStudios,
      badgeText: 'Zero-API DB',
      badgeColor: const Color(0xFF4F46E5),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AnimeDbStudioScreen()),
      ),
    ),
    MiscToolItem(
      id: 'font_library',
      title: 'Google & Custom Fonts',
      description: 'Browse 90+ on-demand fonts, download typefaces, and import local TTF/OTF',
      icon: Icons.font_download_rounded,
      accentColor: const Color(0xFF1E88E5),
      category: MiscToolCategory.librariesAndStudios,
      badgeText: '90+ Fonts',
      badgeColor: const Color(0xFF1565C0),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const FontLibraryScreen(isActive: true)),
      ),
    ),
    MiscToolItem(
      id: 'bg_remover',
      title: 'AI Background Remover',
      description: '1-tap automatic background removal for product shots, portraits & stickers',
      icon: Icons.layers_clear_rounded,
      accentColor: const Color(0xFFE91E63),
      category: MiscToolCategory.librariesAndStudios,
      badgeText: 'AI Powered',
      badgeColor: const Color(0xFFC2185B),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const BackgroundRemoverScreen()),
      ),
    ),
    MiscToolItem(
      id: 'audio_library',
      title: 'Creator Audio Library',
      description: 'Curate trending background tracks, organized folders, and sound effects',
      icon: Icons.library_music_rounded,
      accentColor: const Color(0xFF43A047),
      category: MiscToolCategory.librariesAndStudios,
      badgeText: 'Audio Vault',
      badgeColor: const Color(0xFF2E7D32),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AudioLibraryScreenWithFolders(isActive: true)),
      ),
    ),
    MiscToolItem(
      id: 'caption_store',
      title: 'Caption & Quote Store',
      description: 'Inspirational quotes, hook templates, and dynamic timestamp date copying',
      icon: Icons.closed_caption_rounded,
      accentColor: const Color(0xFFFB8C00),
      category: MiscToolCategory.librariesAndStudios,
      badgeText: 'Captions',
      badgeColor: const Color(0xFFEF6C00),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const CaptionStoreScreen()),
      ),
    ),
    MiscToolItem(
      id: 'tutorials',
      title: 'Video Tutorials & Guides',
      description: 'Master 9:16 layout tips, viral captions, and watermarking best practices',
      icon: Icons.school_rounded,
      accentColor: const Color(0xFF5E35B1),
      category: MiscToolCategory.librariesAndStudios,
      badgeText: 'Academy',
      badgeColor: const Color(0xFF4527A0),
      onTap: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const TutorialsScreen()),
      ),
    ),

    // ─── Upcoming Creator Lab ───
    MiscToolItem(
      id: 'video_compressor',
      title: 'Video Compressor & Bitrate',
      description: 'Reduce file size while preserving 1080p crisp quality for quick uploads',
      icon: Icons.compress_rounded,
      accentColor: const Color(0xFF00ACC1),
      category: MiscToolCategory.creatorLab,
      badgeText: 'Coming Soon',
      badgeColor: Colors.blueGrey,
      onTap: (ctx) => _showComingSoonToast(ctx, 'Video Compressor'),
    ),
    MiscToolItem(
      id: 'tts_studio',
      title: 'AI Voiceover & Speech',
      description: 'Generate lifelike voiceovers for Reels and video narrations in seconds',
      icon: Icons.record_voice_over_rounded,
      accentColor: const Color(0xFF8E24AA),
      category: MiscToolCategory.creatorLab,
      badgeText: 'Coming Soon',
      badgeColor: Colors.blueGrey,
      onTap: (ctx) => _showComingSoonToast(ctx, 'AI Voiceover & Speech'),
    ),
    MiscToolItem(
      id: 'qr_generator',
      title: 'Custom Brand QR Codes',
      description: 'Generate customized QR codes for social profiles, links, and portfolios',
      icon: Icons.qr_code_2_rounded,
      accentColor: const Color(0xFF3949AB),
      category: MiscToolCategory.creatorLab,
      badgeText: 'Coming Soon',
      badgeColor: Colors.blueGrey,
      onTap: (ctx) => _showComingSoonToast(ctx, 'Custom Brand QR Codes'),
    ),
  ];

  final List<MiscToolItem> _customTools = [];

  /// Returns all registered tools.
  List<MiscToolItem> getAllTools() => [..._coreTools, ..._customTools];

  /// Allows registering custom or plugin tools dynamically at runtime.
  void registerCustomTool(MiscToolItem tool) {
    if (!_customTools.any((t) => t.id == tool.id)) {
      _customTools.add(tool);
    }
  }

  /// Filters tools according to search query across title, description, and category.
  List<MiscToolItem> searchTools(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return getAllTools();

    return getAllTools().where((t) {
      return t.title.toLowerCase().contains(cleanQuery) ||
          t.description.toLowerCase().contains(cleanQuery) ||
          t.category.displayName.toLowerCase().contains(cleanQuery);
    }).toList();
  }

  static void _showComingSoonToast(BuildContext context, String toolName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$toolName is in development and will arrive in upcoming releases!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

