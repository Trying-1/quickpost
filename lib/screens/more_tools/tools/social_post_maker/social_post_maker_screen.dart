import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/social_post_model.dart';
import 'services/social_post_service.dart';
import 'widgets/social_post_card_view.dart';

/// Social Post / Tweet Card Studio:
/// - Generates pixel-perfect social cards for Reels, Shorts, and Feed posts
/// - Watermark-screen-style integrated control tabs (Author, Tweet, Metrics, Style, Format, Backdrop)
/// - Multiple aspect ratios: 4:5 Feed Portrait, 1:1 Square, 9:16 Story/Reels, or Card Only for video overlays
/// - Realistic author profile (avatar, username, blue/gold verified badge)
/// - Auto-highlighted hashtags, mentions, and photo attachments
/// - Customizable engagement metrics (Views, Likes, Reposts, Bookmarks)
/// - OLED Black, Dim Navy, and Clean White card styles with backdrop gradients or custom wallpapers
/// - Uncompressed 1080p+ canvas capture & MediaStore saving to Pictures/Quick Post Social Posts
class SocialPostMakerScreen extends StatefulWidget {
  const SocialPostMakerScreen({super.key});

  @override
  State<SocialPostMakerScreen> createState() => _SocialPostMakerScreenState();
}

class _SocialPostMakerScreenState extends State<SocialPostMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  SocialPost _post = SocialPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers
  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _contentController;
  late TextEditingController _timestampController;
  late TextEditingController _viewsController;
  late TextEditingController _repostsController;
  late TextEditingController _quotesController;
  late TextEditingController _likesController;
  late TextEditingController _bookmarksController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Social Post Studio');
    _displayNameController = TextEditingController(text: _post.displayName);
    _usernameController = TextEditingController(text: _post.username);
    _contentController = TextEditingController(text: _post.content);
    _timestampController = TextEditingController(text: _post.timestamp);
    _viewsController = TextEditingController(text: _post.viewsCount);
    _repostsController = TextEditingController(text: _post.repostsCount);
    _quotesController = TextEditingController(text: _post.quotesCount);
    _likesController = TextEditingController(text: _post.likesCount);
    _bookmarksController = TextEditingController(text: _post.bookmarksCount);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _contentController.dispose();
    _timestampController.dispose();
    _viewsController.dispose();
    _repostsController.dispose();
    _quotesController.dispose();
    _likesController.dispose();
    _bookmarksController.dispose();
    super.dispose();
  }

  void _syncControllersFromPost(SocialPost post) {
    _displayNameController.text = post.displayName;
    _usernameController.text = post.username;
    _contentController.text = post.content;
    _timestampController.text = post.timestamp;
    _viewsController.text = post.viewsCount;
    _repostsController.text = post.repostsCount;
    _quotesController.text = post.quotesCount;
    _likesController.text = post.likesCount;
    _bookmarksController.text = post.bookmarksCount;
  }

  Future<void> _pickAvatar() async {
    final file = await SocialPostService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(avatarPath: file.path);
      });
    }
  }

  Future<void> _pickAttachedImage() async {
    final file = await SocialPostService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(attachedImagePath: file.path);
      });
    }
  }

  Future<void> _pickWallpaper() async {
    final file = await SocialPostService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(customWallpaperPath: file.path);
      });
    }
  }

  Future<void> _exportPost() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await SocialPostService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await SocialPostService().saveSocialPostToGallery(
        pngBytes,
        _post.username.isNotEmpty ? _post.username : 'SocialPost',
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
                    'Social post saved to Gallery! (Pictures/Quick Post Social Posts)',
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
      debugPrint('Error exporting social post: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePost() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await SocialPostService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await SocialPostService().saveSocialPostToGallery(
          pngBytes,
          _post.username.isNotEmpty ? _post.username : 'SocialPost',
        );
      }
    }

    if (_lastSavedPath != null) {
      await SocialPostService().shareSocialPost(_lastSavedPath!);
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
          'Social Post Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<SocialPost>(
            tooltip: 'Load Viral Tweet Preset',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (template) {
              setState(() {
                _post = template;
                _syncControllersFromPost(template);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('VIRAL TWEET PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...SocialPost.viralTemplates.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.cardTheme.cardBg, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade400)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          preset.displayName,
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
                    child: SocialPostCardView(
                      post: _post,
                      onEditRequested: () {
                        setState(() {
                          _selectedTabIndex = 1;
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
          _buildTabItem(0, Icons.person_rounded, 'Author', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.edit_note_rounded, 'Tweet', const Color(0xFF1D9BF0)),
          _buildTabItem(2, Icons.bar_chart_rounded, 'Metrics', const Color(0xFF8B5CF6)),
          _buildTabItem(3, Icons.palette_rounded, 'Style', const Color(0xFFF97316)),
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
        width: 70,
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
        return _buildAuthorTab();
      case 1:
        return _buildTweetTab();
      case 2:
        return _buildMetricsTab();
      case 3:
        return _buildStyleTab();
      case 4:
        return _buildFormatTab();
      case 5:
        return _buildBackdropTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Author Settings ───
  Widget _buildAuthorTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Avatar picker
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _post.avatarPath != null && File(_post.avatarPath!).existsSync()
                        ? FileImage(File(_post.avatarPath!))
                        : null,
                    child: _post.avatarPath == null
                        ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 24)
                        : null,
                  ),
                  if (_post.avatarPath != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _post = _post.copyWith(clearAvatar: true));
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
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                    onChanged: (val) => setState(() => _post = _post.copyWith(displayName: val)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Handle (@username)',
                      labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                    onChanged: (val) => setState(() => _post = _post.copyWith(username: val)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'VERIFIED BADGE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: VerifiedBadgeType.values.map((badge) {
            final isSelected = _post.verifiedBadge == badge;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badge.color != null) ...[
                    Icon(Icons.verified_rounded, size: 14, color: badge.color),
                    const SizedBox(width: 4),
                  ],
                  Text(badge.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _post = _post.copyWith(verifiedBadge: badge));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 1: Tweet Content ───
  Widget _buildTweetTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _contentController,
          maxLines: 4,
          maxLength: 350,
          decoration: InputDecoration(
            labelText: 'Tweet Content (Supports #hashtags & @mentions)',
            labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(content: val)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: Text(
                  _post.attachedImagePath != null ? 'Change Attached Photo' : 'Attach Photo to Tweet',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickAttachedImage,
              ),
            ),
            if (_post.attachedImagePath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Remove photo',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(clearAttachedImage: true));
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Tab 2: Engagement Metrics & Timestamp ───
  Widget _buildMetricsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Engagement Metrics', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.showMetrics,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showMetrics: val)),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Timestamp & Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.showTimestamp,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showTimestamp: val)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _timestampController,
          decoration: InputDecoration(
            labelText: 'Timestamp string',
            labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12.5, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(timestamp: val)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildSmallMetricField('Views', _viewsController, (v) => _post = _post.copyWith(viewsCount: v))),
            const SizedBox(width: 8),
            Expanded(child: _buildSmallMetricField('Likes', _likesController, (v) => _post = _post.copyWith(likesCount: v))),
            const SizedBox(width: 8),
            Expanded(child: _buildSmallMetricField('Reposts', _repostsController, (v) => _post = _post.copyWith(repostsCount: v))),
            const SizedBox(width: 8),
            Expanded(child: _buildSmallMetricField('Bookmarks', _bookmarksController, (v) => _post = _post.copyWith(bookmarksCount: v))),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallMetricField(String label, TextEditingController controller, Function(String) onChanged) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10.5, fontFamily: 'Poppins'),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
      onChanged: (val) => setState(() => onChanged(val)),
    );
  }

  // ─── Tab 3: Card Style & Color Theme ───
  Widget _buildStyleTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CARD THEME',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: SocialCardTheme.values.map((theme) {
            final isSelected = _post.cardTheme == theme;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(cardTheme: theme));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                      Text(
                        theme.name,
                        style: TextStyle(
                          color: theme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@handle',
                        style: TextStyle(
                          color: theme.secondaryText,
                          fontSize: 10,
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
          children: SocialPostRatio.values.map((ratio) {
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
            itemCount: SocialBackdropPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = SocialBackdropPreset.presets[index];
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
                  _post.customWallpaperPath != null ? 'Change Custom Photo' : 'Custom Photo Backdrop',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickWallpaper,
              ),
            ),
            if (_post.customWallpaperPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.red),
                tooltip: 'Clear photo',
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
                  _post = SocialPost.initialDefault;
                  _syncControllersFromPost(_post);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share post',
              onPressed: _isSaving ? null : _sharePost,
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
                onPressed: _isSaving ? null : _exportPost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
