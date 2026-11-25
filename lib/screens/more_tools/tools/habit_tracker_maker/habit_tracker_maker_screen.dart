import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/habit_tracker_model.dart';
import 'services/habit_tracker_service.dart';
import 'widgets/habit_canvas_view.dart';

/// Habit & Streak Contribution Studio:
/// - GitHub commit-style square dot heatmap graphics for habit tracking, Reels, Shorts & Feed
/// - Integrated Watermark-style horizontal Control Tabs bar:
///   Content, Streak, Dots (Shapes & Glow), Milestone, Theme, Duration, Format, Backdrop, Badges
/// - Interactive live editing: tap on canvas square dots to cycle intensity or paint with Brush Tool
/// - Advanced consistency patterns: 85% Consistent, 60% Moderate, Ramping Momentum, Weekdays Only, Alternating
/// - Custom Dot Shapes: Rounded Squares, Squircles, Circles, 8-Bit Sharp Squares
/// - Milestone celebration ribbons, top month labels, transparent PNG video overlay toggle
/// - 1080p+ capture with automatic MediaStore gallery saving to Pictures/Quick Post Habit Grids
class HabitTrackerMakerScreen extends StatefulWidget {
  const HabitTrackerMakerScreen({super.key});

  @override
  State<HabitTrackerMakerScreen> createState() => _HabitTrackerMakerScreenState();
}

class _HabitTrackerMakerScreenState extends State<HabitTrackerMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  HabitGridPost _post = HabitGridPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style bottom control tab state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Brush Tool Mode: -1 = Cycle (0->1->2->3->4->0), 0..4 = Paint specific level
  int _brushLevel = -1;

  // Controllers for text content
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _yearController;
  late TextEditingController _authorController;

  final List<String> _quickEmojis = ['💻', '💪', '📚', '🧘', '🎨', '💰', '🏃', '🔥', '🎯', '⚡'];

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Habit Tracker Maker Studio');
    _titleController = TextEditingController(text: _post.habitTitle);
    _subtitleController = TextEditingController(text: _post.habitSubtitle);
    _yearController = TextEditingController(text: _post.yearLabel);
    _authorController = TextEditingController(text: _post.authorHandle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _yearController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _syncControllersFromPost(HabitGridPost post) {
    _titleController.text = post.habitTitle;
    _subtitleController.text = post.habitSubtitle;
    _yearController.text = post.yearLabel;
    _authorController.text = post.authorHandle;
  }

  void _onTileTapped(int index) {
    if (index >= _post.tileIntensities.length) return;
    HapticFeedback.selectionClick();
    final list = List<int>.from(_post.tileIntensities);

    if (_brushLevel >= 0) {
      // Direct paint mode
      list[index] = _brushLevel;
    } else {
      // Cycle mode: 0 -> 1 -> 2 -> 3 -> 4 -> 0
      list[index] = (list[index] + 1) % 5;
    }

    setState(() {
      _post = _post.copyWith(tileIntensities: list);
    });
  }

  Future<void> _pickAvatar() async {
    final file = await HabitTrackerService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(authorAvatarPath: file.path);
      });
    }
  }

  Future<void> _pickWallpaper() async {
    final file = await HabitTrackerService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(customWallpaperPath: file.path);
      });
    }
  }

  void _applyQuickPattern(double density) {
    HapticFeedback.lightImpact();
    setState(() {
      _post = _post.copyWith(
        tileIntensities: HabitGridPost.generatePattern(
          totalDays: _post.timeSpan.totalDays,
          density: density,
          endingStreak: _post.manualStreak,
        ),
      );
    });
  }

  void _applyRampingPattern() {
    HapticFeedback.lightImpact();
    setState(() {
      _post = _post.copyWith(
        tileIntensities: HabitGridPost.generateRampingPattern(_post.timeSpan.totalDays),
      );
    });
  }

  void _applyWeekdaysPattern() {
    HapticFeedback.lightImpact();
    setState(() {
      _post = _post.copyWith(
        tileIntensities: HabitGridPost.generateWeekdaysPattern(_post.timeSpan.totalDays),
      );
    });
  }

  void _applyAlternatingPattern() {
    HapticFeedback.lightImpact();
    setState(() {
      _post = _post.copyWith(
        tileIntensities: HabitGridPost.generateAlternatingPattern(_post.timeSpan.totalDays),
      );
    });
  }

  Future<void> _exportToGallery() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await HabitTrackerService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await HabitTrackerService().saveHabitCardToGallery(
        pngBytes,
        _post.habitTitle,
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
                    'Habit card saved to Gallery! (Pictures/Quick Post Habit Grids)',
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
      debugPrint('Error saving habit card: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareGraphic() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await HabitTrackerService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await HabitTrackerService().saveHabitCardToGallery(
          pngBytes,
          _post.habitTitle,
        );
      }
    }

    if (_lastSavedPath != null) {
      await HabitTrackerService().shareHabitCard(_lastSavedPath!);
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
          'Habit Streak Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<HabitGridPost>(
            tooltip: 'Load Viral Habit Preset',
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
                child: Text('VIRAL HABIT PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...HabitGridPost.viralTemplates.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.theme.accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(preset.habitTitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
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
                    child: HabitCanvasView(
                      post: _post,
                      onTileTapped: _onTileTapped,
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

  // ─── Horizontal Control Tabs Bar (Watermark Style) ───
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
          _buildTabItem(0, Icons.edit_note_rounded, 'Content', AppColors.primary),
          _buildTabItem(1, Icons.local_fire_department_rounded, 'Streak', const Color(0xFFF97316)),
          _buildTabItem(2, Icons.grid_on_rounded, 'Dots', const Color(0xFF00796B)),
          _buildTabItem(3, Icons.stars_rounded, 'Milestone', const Color(0xFFEF4444)),
          _buildTabItem(4, Icons.palette_rounded, 'Theme', const Color(0xFF8B5CF6)),
          _buildTabItem(5, Icons.calendar_month_rounded, 'Duration', const Color(0xFF0D9488)),
          _buildTabItem(6, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0284C7)),
          _buildTabItem(7, Icons.wallpaper_rounded, 'Backdrop', const Color(0xFFEC4899)),
          _buildTabItem(8, Icons.tune_rounded, 'Badges', const Color(0xFFEAB308)),
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
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildContentTab();
      case 1:
        return _buildStreakTab();
      case 2:
        return _buildDotsTab();
      case 3:
        return _buildMilestoneTab();
      case 4:
        return _buildThemeTab();
      case 5:
        return _buildDurationTab();
      case 6:
        return _buildFormatTab();
      case 7:
        return _buildBackdropTab();
      case 8:
        return _buildBadgesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Content & Quotes ───
  Widget _buildContentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Emojis
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickEmojis.map((emoji) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    final cleanTitle = _titleController.text.replaceAll(RegExp(r'^[^\w\s]+ '), '');
                    final updatedText = '$emoji $cleanTitle';
                    setState(() {
                      _titleController.text = updatedText;
                      _post = _post.copyWith(habitTitle: updatedText);
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Habit Title Input
        TextField(
          controller: _titleController,
          onChanged: (val) => setState(() => _post = _post.copyWith(habitTitle: val.trim())),
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'HABIT / GOAL TITLE',
            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontFamily: 'Poppins'),
            filled: true,
            fillColor: AppColors.background,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle Input
        TextField(
          controller: _subtitleController,
          onChanged: (val) => setState(() => _post = _post.copyWith(habitSubtitle: val.trim())),
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins', fontSize: 12),
          decoration: InputDecoration(
            labelText: 'SUBTITLE / MOTIVATIONAL NOTE',
            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontFamily: 'Poppins'),
            filled: true,
            fillColor: AppColors.background,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 6),

        // Curated Viral Quotes Library
        const Text(
          'INSPIRATIONAL QUOTES (1-TAP TO APPLY)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HabitQuotesLibrary.quotes.map((q) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(
                    q.length > 32 ? '${q.substring(0, 32)}...' : q,
                    style: const TextStyle(fontSize: 10, fontFamily: 'Poppins'),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide(color: Colors.grey.shade300),
                  onPressed: () {
                    setState(() {
                      _subtitleController.text = q;
                      _post = _post.copyWith(habitSubtitle: q);
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Year & Author Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _yearController,
                onChanged: (val) => setState(() => _post = _post.copyWith(yearLabel: val.trim())),
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'CHALLENGE LABEL',
                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: AppColors.background,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _authorController,
                onChanged: (val) => setState(() => _post = _post.copyWith(authorHandle: val.trim())),
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins', fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'AUTHOR / HANDLE',
                  labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: AppColors.background,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: _post.authorAvatarPath != null ? FileImage(File(_post.authorAvatarPath!)) : null,
                child: _post.authorAvatarPath == null ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 16) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 1: Streak & Pattern Generators ───
  Widget _buildStreakTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CURRENT STREAK COUNT',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            Text(
              '🔥 ${_post.manualStreak} Days',
              style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFFF97316),
            thumbColor: const Color(0xFFF97316),
            inactiveTrackColor: Colors.grey.shade300,
          ),
          child: Slider(
            value: _post.manualStreak.clamp(0, _post.timeSpan.totalDays).toDouble(),
            min: 0,
            max: _post.timeSpan.totalDays.toDouble(),
            onChanged: (v) {
              setState(() {
                _post = _post.copyWith(
                  manualStreak: v.toInt(),
                  tileIntensities: HabitGridPost.generatePattern(
                    totalDays: _post.timeSpan.totalDays,
                    density: 0.75,
                    endingStreak: v.toInt(),
                  ),
                );
              });
            },
          ),
        ),
        const SizedBox(height: 6),

        // Brush Level Selector
        Row(
          children: [
            const Text(
              'TAP BRUSH: ',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Cycle 0-4'),
              selected: _brushLevel == -1,
              onSelected: (_) => setState(() => _brushLevel = -1),
              selectedColor: AppColors.primarySurface,
              labelStyle: TextStyle(
                color: _brushLevel == -1 ? AppColors.primary : AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ...List.generate(5, (lvl) {
              final isSel = _brushLevel == lvl;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () => setState(() => _brushLevel = lvl),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _post.theme.colorForLevel(lvl),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSel ? Colors.white : Colors.grey.shade400,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$lvl',
                      style: TextStyle(
                        color: lvl > 1 ? Colors.white : Colors.grey.shade600,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 10),
        const Text(
          'SMART PATTERN GENERATORS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () => _applyQuickPattern(0.85),
              icon: const Icon(Icons.auto_awesome_rounded, size: 13),
              label: const Text('85% Consistent', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _applyRampingPattern,
              icon: const Icon(Icons.trending_up_rounded, size: 13),
              label: const Text('Ramping Momentum', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                side: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _applyWeekdaysPattern,
              icon: const Icon(Icons.work_history_rounded, size: 13),
              label: const Text('Weekdays Only', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _applyAlternatingPattern,
              icon: const Icon(Icons.repeat_rounded, size: 13),
              label: const Text('Alternating Days', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _post = _post.copyWith(tileIntensities: List<int>.filled(_post.timeSpan.totalDays, 4));
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('100% Full', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _post = _post.copyWith(tileIntensities: List<int>.filled(_post.timeSpan.totalDays, 0));
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Clear Grid', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 2: Dots Customization ───
  Widget _buildDotsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DOT / SQUARE TILE SHAPE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Row(
          children: HabitDotShape.values.map((sh) {
            final isSelected = sh == _post.dotShape;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _post = _post.copyWith(dotShape: sh)),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primarySurface : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(sh.icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                        const SizedBox(height: 4),
                        Text(
                          sh.label,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Dot Spacing Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DOT SPACING / GAP',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            Text(
              '${_post.dotSpacing.toStringAsFixed(1)} px',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Poppins'),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: AppColors.primary,
            thumbColor: AppColors.primary,
            inactiveTrackColor: Colors.grey.shade300,
          ),
          child: Slider(
            value: _post.dotSpacing,
            min: 1.0,
            max: 6.0,
            onChanged: (v) => setState(() => _post = _post.copyWith(dotSpacing: v)),
          ),
        ),

        // Neon Glow Toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Neon Bloom / Glow on Level 4 Dots', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontFamily: 'Poppins')),
          value: _post.enableDotGlow,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(enableDotGlow: v)),
        ),
      ],
    );
  }

  // ─── Tab 3: Milestone Celebrations ───
  Widget _buildMilestoneTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CELEBRATION MILESTONE BADGE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Column(
          children: HabitMilestoneBadge.values.map((badge) {
            final isSelected = badge == _post.milestone;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? const Color(0xFFEF4444) : Colors.grey.shade300),
                ),
                tileColor: isSelected ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                dense: true,
                title: Text(
                  badge.label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFEF4444) : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFEF4444), size: 18)
                    : null,
                onTap: () => setState(() => _post = _post.copyWith(milestone: badge)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 4: Theme ───
  Widget _buildThemeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTRIBUTION COLOR THEME',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
          ),
          itemCount: HabitColorTheme.values.length,
          itemBuilder: (ctx, idx) {
            final th = HabitColorTheme.values[idx];
            final isSelected = th == _post.theme;
            return InkWell(
              onTap: () => setState(() => _post = _post.copyWith(theme: th)),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: th.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: List.generate(4, (i) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 2.5),
                          decoration: BoxDecoration(
                            color: th.levels[i + 1],
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      th.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: th.primaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Tab 5: Duration / Time Span ───
  Widget _buildDurationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GRID DURATION & NUMBER OF WEEKS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        Column(
          children: HabitTimeSpan.values.map((span) {
            final isSelected = span == _post.timeSpan;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                ),
                tileColor: isSelected ? AppColors.primarySurface : const Color(0xFFF1F5F9),
                dense: true,
                leading: Icon(span.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                title: Text(
                  span.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    fontFamily: 'Poppins',
                  ),
                ),
                trailing: Text(
                  '${span.totalDays} Days (${span.weeks} Wks)',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Poppins'),
                ),
                onTap: () {
                  setState(() {
                    _post = _post.copyWith(
                      timeSpan: span,
                      tileIntensities: HabitGridPost.generatePattern(
                        totalDays: span.totalDays,
                        density: 0.78,
                        endingStreak: _post.manualStreak,
                      ),
                    );
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 6: Format / Aspect Ratio & Transparency ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANVAS FORMAT & ASPECT RATIO',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        Row(
          children: HabitRatio.values.map((r) {
            final isSelected = r == _post.ratio;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _post = _post.copyWith(ratio: r)),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primarySurface : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(r.icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                        const SizedBox(height: 6),
                        Text(
                          r.id,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Transparent PNG Export Toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Transparent Background (PNG Overlay)', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontFamily: 'Poppins')),
          subtitle: const Text('No background fill, perfect for video editor overlays in CapCut/Premiere', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontFamily: 'Poppins')),
          value: _post.transparentBg,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(transparentBg: v)),
        ),
      ],
    );
  }

  // ─── Tab 7: Backdrop & Wallpaper ───
  Widget _buildBackdropTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BACKDROP PRESETS & WALLPAPER',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: HabitBackdropPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = HabitBackdropPreset.presets[index];
              final isSelected = index == _post.backdropIndex && _post.customWallpaperPath == null;

              return GestureDetector(
                onTap: () => setState(() {
                  _post = _post.copyWith(
                    backdropIndex: index,
                    clearWallpaper: true,
                  );
                }),
                child: Container(
                  width: 52,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: preset.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
                        : null,
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
                onPressed: _pickWallpaper,
                icon: const Icon(Icons.wallpaper_rounded, size: 16),
                label: Text(
                  _post.customWallpaperPath == null ? 'Custom Background Wallpaper' : 'Change Wallpaper',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (_post.customWallpaperPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _post = _post.copyWith(clearWallpaper: true)),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Tab 8: Badges & Toggles ───
  Widget _buildBadgesTab() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Display Stats Pill Row', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
          subtitle: const Text('Streak, Logged Days, Completion Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Poppins')),
          value: _post.showStatsRow,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(showStatsRow: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Left Day Labels (M, W, F, S)', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
          value: _post.showDayLabels,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(showDayLabels: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Top Month Headers (Jan, Feb, Mar...)', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
          value: _post.showMonthLabels,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(showMonthLabels: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Author Handle Badge', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
          value: _post.showAuthorBadge,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(showAuthorBadge: v)),
        ),
      ],
    );
  }

  // ─── Bottom Action Dock ───
  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Reset button
            IconButton(
              tooltip: 'Reset to default habit',
              onPressed: () {
                setState(() {
                  _post = HabitGridPost.initialDefault;
                  _syncControllersFromPost(HabitGridPost.initialDefault);
                });
              },
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),

            // Share button
            IconButton(
              tooltip: 'Share Habit Card',
              onPressed: _isSaving ? null : _shareGraphic,
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 10),

            // Export to Gallery CTA
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _exportToGallery,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _lastSavedPath != null ? 'Saved to Gallery' : 'Export Habit Card',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
