import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/music_card_model.dart';
import 'services/music_card_service.dart';
import 'widgets/music_card_view.dart';

/// Music Player & Synced Lyrics Card Studio:
/// - Generates aesthetic "Now Playing" audio cards with synced lyrics highlights
/// - Watermark-screen-style integrated control tabs (Track, Lyrics, Playback, Theme, Format, Backdrop)
/// - Multiple aspect ratios: 4:5 Feed Portrait, 1:1 Square, 9:16 Story/Reels, or Card Only for video overlays
/// - Custom album artwork picker, song title, artist, timeline scrubber, and waveform bars
/// - Spotify Dark, Apple Glass, Neon Cyber, and Minimal White card themes
/// - 6 backdrop gradients or custom wallpaper backing
/// - Uncompressed 1080p+ canvas capture & MediaStore saving to Pictures/Quick Post Music Cards
class MusicLyricsMakerScreen extends StatefulWidget {
  const MusicLyricsMakerScreen({super.key});

  @override
  State<MusicLyricsMakerScreen> createState() => _MusicLyricsMakerScreenState();
}

class _MusicLyricsMakerScreenState extends State<MusicLyricsMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  MusicCardPost _post = MusicCardPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers
  late TextEditingController _songTitleController;
  late TextEditingController _artistNameController;
  late TextEditingController _currentTimeController;
  late TextEditingController _totalDurationController;
  late TextEditingController _lyrics1Controller;
  late TextEditingController _lyrics2Controller;
  late TextEditingController _lyrics3Controller;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Music Lyrics Studio');
    _songTitleController = TextEditingController(text: _post.songTitle);
    _artistNameController = TextEditingController(text: _post.artistName);
    _currentTimeController = TextEditingController(text: _post.currentTime);
    _totalDurationController = TextEditingController(text: _post.totalDuration);
    _lyrics1Controller = TextEditingController(text: _post.lyricsLine1);
    _lyrics2Controller = TextEditingController(text: _post.lyricsLine2);
    _lyrics3Controller = TextEditingController(text: _post.lyricsLine3);
  }

  @override
  void dispose() {
    _songTitleController.dispose();
    _artistNameController.dispose();
    _currentTimeController.dispose();
    _totalDurationController.dispose();
    _lyrics1Controller.dispose();
    _lyrics2Controller.dispose();
    _lyrics3Controller.dispose();
    super.dispose();
  }

  void _syncAllFromPost(MusicCardPost post) {
    _songTitleController.text = post.songTitle;
    _artistNameController.text = post.artistName;
    _currentTimeController.text = post.currentTime;
    _totalDurationController.text = post.totalDuration;
    _lyrics1Controller.text = post.lyricsLine1;
    _lyrics2Controller.text = post.lyricsLine2;
    _lyrics3Controller.text = post.lyricsLine3;
  }

  Future<void> _pickAlbumArt() async {
    final file = await MusicCardService().pickImage();
    if (file != null && mounted) {
      setState(() => _post = _post.copyWith(albumArtPath: file.path));
    }
  }

  Future<void> _pickBackdrop() async {
    final file = await MusicCardService().pickImage();
    if (file != null && mounted) {
      setState(() => _post = _post.copyWith(customWallpaperPath: file.path));
    }
  }

  Future<void> _exportMusicCard() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await MusicCardService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await MusicCardService().saveMusicCardToGallery(
        pngBytes,
        _post.songTitle.isNotEmpty ? _post.songTitle : 'MusicCard',
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _lastSavedPath = path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primarySurface, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Music card saved to Gallery! (Pictures/Quick Post Music Cards)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting music card: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareMusicCard() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await MusicCardService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await MusicCardService().saveMusicCardToGallery(
          pngBytes,
          _post.songTitle.isNotEmpty ? _post.songTitle : 'MusicCard',
        );
      }
    }

    if (_lastSavedPath != null) {
      await MusicCardService().shareMusicCard(_lastSavedPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Music & Lyrics Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<MusicCardPost>(
            tooltip: 'Load Viral Music Preset',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (template) {
              setState(() {
                _post = template;
                _syncAllFromPost(template);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('VIRAL TRACK PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...MusicCardPost.viralTemplates.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.playerTheme.accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          preset.songTitle,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Center Interactive Canvas ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: MusicCardView(
                      post: _post,
                      onEditRequested: () {
                        setState(() {
                          _selectedTabIndex = 0;
                          _isTabContentExpanded = true;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Watermark-style Active Tab Content Panel ───
          if (_isTabContentExpanded) _buildActiveTabContent(),

          // ─── Watermark-style Horizontal Control Tabs Bar ───
          _buildControlTabsBar(),

          // ─── Bottom Sticky Action Dock (Reset, Share, Export) ───
          _buildBottomActionDock(),
        ],
      ),
    );
  }

  // ─── Horizontal Control Tabs Bar ───
  Widget _buildControlTabsBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          _buildTabItem(0, Icons.music_note_rounded, 'Track', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.format_quote_rounded, 'Lyrics', const Color(0xFF0284C7)),
          _buildTabItem(2, Icons.play_circle_outline_rounded, 'Playback', const Color(0xFFF59E0B)),
          _buildTabItem(3, Icons.palette_rounded, 'Theme', const Color(0xFF8B5CF6)),
          _buildTabItem(4, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
          _buildTabItem(5, Icons.wallpaper_rounded, 'Backdrop', const Color(0xFFEC4899)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_selectedTabIndex == index) {
            _isTabContentExpanded = !_isTabContentExpanded;
          } else {
            _selectedTabIndex = index;
            _isTabContentExpanded = true;
          }
        });
      },
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active Tab Content Container ───
  Widget _buildActiveTabContent() {
    return Container(
      height: 240,
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTrackTab();
      case 1:
        return _buildLyricsTab();
      case 2:
        return _buildPlaybackTab();
      case 3:
        return _buildThemeTab();
      case 4:
        return _buildFormatTab();
      case 5:
        return _buildBackdropTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Track & Cover Art ───
  Widget _buildTrackTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Album Art
            GestureDetector(
              onTap: _pickAlbumArt,
              child: Stack(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      image: _post.albumArtPath != null && File(_post.albumArtPath!).existsSync()
                          ? DecorationImage(image: FileImage(File(_post.albumArtPath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _post.albumArtPath == null
                        ? const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 24)
                        : null,
                  ),
                  if (_post.albumArtPath != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _post = _post.copyWith(clearAlbumArt: true));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _songTitleController,
                    decoration: InputDecoration(
                      labelText: 'Song Title',
                      labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    onChanged: (val) => setState(() => _post = _post.copyWith(songTitle: val)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _artistNameController,
                    decoration: InputDecoration(
                      labelText: 'Artist Name / Album',
                      labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    onChanged: (val) => setState(() => _post = _post.copyWith(artistName: val)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Liked Track (Heart Filled)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.isLiked,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(isLiked: val)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 1: Lyrics Highlights ───
  Widget _buildLyricsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Synced Lyrics / Highlight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            Switch(
              value: _post.showLyrics,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showLyrics: val)),
            ),
          ],
        ),
        if (_post.showLyrics) ...[
          const SizedBox(height: 6),
          const Text(
            'ACTIVE GLOWING LINE',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(3, (i) {
              final isSelected = _post.activeLyricIndex == i;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text('Line #${i + 1}', style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                    selected: isSelected,
                    selectedColor: AppColors.primarySurface,
                    onSelected: (_) => setState(() => _post = _post.copyWith(activeLyricIndex: i)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          _buildLyricField('Lyrics Line 1', _lyrics1Controller, (v) => _post = _post.copyWith(lyricsLine1: v)),
          const SizedBox(height: 6),
          _buildLyricField('Lyrics Line 2', _lyrics2Controller, (v) => _post = _post.copyWith(lyricsLine2: v)),
          const SizedBox(height: 6),
          _buildLyricField('Lyrics Line 3', _lyrics3Controller, (v) => _post = _post.copyWith(lyricsLine3: v)),
        ],
      ],
    );
  }

  Widget _buildLyricField(String label, TextEditingController controller, Function(String) onChanged) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
      onChanged: (val) => setState(() => onChanged(val)),
    );
  }

  // ─── Tab 2: Playback Timeline & Audio Wave ───
  Widget _buildPlaybackTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Progress: ${(_post.progressPercent * 100).round()}%', style: const TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            Expanded(
              child: Slider(
                value: _post.progressPercent.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _post = _post.copyWith(progressPercent: val)),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _currentTimeController,
                decoration: InputDecoration(
                  labelText: 'Current Time (e.g. 1:24)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                onChanged: (val) => setState(() => _post = _post.copyWith(currentTime: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _totalDurationController,
                decoration: InputDecoration(
                  labelText: 'Total Duration (e.g. 4:03)',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                onChanged: (val) => setState(() => _post = _post.copyWith(totalDuration: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Media Playback Controls', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            Switch(
              value: _post.showControls,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showControls: val)),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Animated Waveform Bars', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            Switch(
              value: _post.showWaveform,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showWaveform: val)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 3: Themes ───
  Widget _buildThemeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PLAYER CARD THEMES',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: MusicPlayerTheme.values.map((theme) {
            final isSelected = _post.playerTheme == theme;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(playerTheme: theme));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : theme.cardBorder,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: theme.accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.primaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 4: Aspect Ratio / Format ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANVAS ASPECT RATIO',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: MusicCardRatio.values.map((ratio) {
            final isSelected = _post.ratio == ratio;
            return ChoiceChip(
              avatar: Icon(ratio.icon, size: 16, color: isSelected ? AppColors.primary : Colors.grey.shade700),
              label: Text(ratio.label, style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _post = _post.copyWith(ratio: ratio));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 5: Backdrop & Wallpaper ───
  Widget _buildBackdropTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GRADIENT BACKDROP PRESETS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: MusicBackdropPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = MusicBackdropPreset.presets[index];
              final isSelected = _post.backdropIndex == index && _post.customWallpaperPath == null;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _post = _post.copyWith(backdropIndex: index, clearWallpaper: true);
                  });
                },
                child: Container(
                  width: 54,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: preset.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wallpaper_rounded, size: 18),
                label: Text(
                  _post.customWallpaperPath != null ? 'Change Custom Wallpaper' : 'Custom Photo Wallpaper',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickBackdrop,
              ),
            ),
            if (_post.customWallpaperPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.red),
                tooltip: 'Clear wallpaper',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(clearWallpaper: true));
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Bottom Sticky Action Dock ───
  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Reset Button
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              tooltip: 'Reset to default',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _post = MusicCardPost.initialDefault;
                  _syncAllFromPost(_post);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share music card',
              onPressed: _isSaving ? null : _shareMusicCard,
            ),

            const SizedBox(width: 8),

            // Export to Gallery Button
            Expanded(
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Exporting...' : 'Save to Gallery',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _exportMusicCard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
