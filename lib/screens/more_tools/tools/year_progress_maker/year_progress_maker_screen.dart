import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/year_progress_model.dart';
import 'services/year_progress_service.dart';
import 'widgets/year_progress_canvas_view.dart';

/// Year Progress & 365-Day Calendar Studio:
/// - Visualizes 365 days of the year (Circle to Square dot matrix, 12 month clusters, or hero progress stream)
/// - Live percentage of year passed, days remaining countdown, weeks left, and quarter indicators
/// - Watermark-screen-style integrated control tabs (Date, Layout, Dots, Content, Theme, Format, Backdrop, Badges)
/// - Curated viral reflection quotes library
/// - High-resolution 1080p+ capture with automatic MediaStore gallery saving to Pictures/Quick Post Year Progress
class YearProgressMakerScreen extends StatefulWidget {
  const YearProgressMakerScreen({super.key});

  @override
  State<YearProgressMakerScreen> createState() => _YearProgressMakerScreenState();
}

class _YearProgressMakerScreenState extends State<YearProgressMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  YearProgressPost _post = YearProgressPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _authorController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Year Progress Maker Studio');
    _titleController = TextEditingController(text: _post.title);
    _subtitleController = TextEditingController(text: _post.subtitle);
    _authorController = TextEditingController(text: _post.authorHandle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _syncControllersFromPost(YearProgressPost post) {
    _titleController.text = post.title;
    _subtitleController.text = post.subtitle;
    _authorController.text = post.authorHandle;
  }

  void _onDayTapped(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      _post = _post.copyWith(currentDayOfYear: day);
    });
  }

  Future<void> _pickAvatar() async {
    final file = await YearProgressService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(authorAvatarPath: file.path);
      });
    }
  }

  Future<void> _pickWallpaper() async {
    final file = await YearProgressService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _post = _post.copyWith(customWallpaperPath: file.path);
      });
    }
  }

  Future<void> _exportToGallery() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await YearProgressService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await YearProgressService().saveYearProgressToGallery(
        pngBytes,
        _post.title,
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
                    'Year Progress saved to Gallery! (Pictures/Quick Post Year Progress)',
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
      debugPrint('Error saving year progress: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareGraphic() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await YearProgressService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await YearProgressService().saveYearProgressToGallery(
          pngBytes,
          _post.title,
        );
      }
    }

    if (_lastSavedPath != null) {
      await YearProgressService().shareYearProgress(_lastSavedPath!);
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
          'Year Progress Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<YearProgressPost>(
            tooltip: 'Load Viral Year Preset',
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
                child: Text('VIRAL YEAR PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...YearProgressPost.viralPresets.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.theme.passedColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(preset.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
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
                    child: YearProgressCanvasView(
                      post: _post,
                      onDayTapped: _onDayTapped,
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
          _buildTabItem(0, Icons.today_rounded, 'Date', const Color(0xFFF97316)),
          _buildTabItem(1, Icons.dashboard_customize_rounded, 'Layout', const Color(0xFF00796B)),
          _buildTabItem(2, Icons.circle_outlined, 'Dots', const Color(0xFF0284C7)),
          _buildTabItem(3, Icons.edit_note_rounded, 'Content', AppColors.primary),
          _buildTabItem(4, Icons.palette_rounded, 'Theme', const Color(0xFF8B5CF6)),
          _buildTabItem(5, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
          _buildTabItem(6, Icons.wallpaper_rounded, 'Backdrop', const Color(0xFFEC4899)),
          _buildTabItem(7, Icons.tune_rounded, 'Badges', const Color(0xFFEAB308)),
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
        return _buildDateTab();
      case 1:
        return _buildLayoutTab();
      case 2:
        return _buildDotsTab();
      case 3:
        return _buildContentTab();
      case 4:
        return _buildThemeTab();
      case 5:
        return _buildFormatTab();
      case 6:
        return _buildBackdropTab();
      case 7:
        return _buildBadgesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Date & Progress Slider ───
  Widget _buildDateTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE DAY: ${_post.currentDayOfYear} OF ${_post.totalDaysInYear}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            Text(
              _post.formattedCurrentDate,
              style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins'),
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
            value: _post.currentDayOfYear.clamp(1, _post.totalDaysInYear).toDouble(),
            min: 1,
            max: _post.totalDaysInYear.toDouble(),
            onChanged: (v) {
              setState(() => _post = _post.copyWith(currentDayOfYear: v.toInt()));
            },
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'MILESTONE DATE PRESETS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                final now = DateTime.now();
                setState(() => _post = _post.copyWith(currentDayOfYear: YearProgressPost.computeDayOfYear(now)));
              },
              icon: const Icon(Icons.today_rounded, size: 13),
              label: const Text("Today's Date", style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _post = _post.copyWith(currentDayOfYear: 265)), // 100 days remaining
              icon: const Icon(Icons.hourglass_top_rounded, size: 13),
              label: const Text('100 Days Left', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF97316),
                side: BorderSide(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _post = _post.copyWith(currentDayOfYear: 182)), // 50%
              icon: const Icon(Icons.pie_chart_outline_rounded, size: 13),
              label: const Text('Mid-Year 50%', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                side: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _post = _post.copyWith(currentDayOfYear: _post.totalDaysInYear)),
              icon: const Icon(Icons.flag_rounded, size: 13),
              label: const Text('Year Complete 100%', style: TextStyle(fontSize: 10.5, fontFamily: 'Poppins')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Tab 1: Layout Arrangement ───
  Widget _buildLayoutTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GRID VISUALIZATION ARRANGEMENT',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        Column(
          children: YearGridLayout.values.map((ly) {
            final isSelected = ly == _post.layout;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? const Color(0xFF00796B) : Colors.grey.shade300),
                ),
                tileColor: isSelected ? const Color(0xFF00796B).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                dense: true,
                leading: Icon(ly.icon, color: isSelected ? const Color(0xFF00796B) : AppColors.textSecondary),
                title: Text(
                  ly.label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF00796B) : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    fontFamily: 'Poppins',
                  ),
                ),
                subtitle: Text(
                  ly.subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontFamily: 'Poppins'),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00796B), size: 18)
                    : null,
                onTap: () => setState(() => _post = _post.copyWith(layout: ly)),
              ),
            );
          }).toList(),
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
          'DAY DOT SHAPE (CIRCULAR TO SQUARE)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Row(
          children: YearDotShape.values.map((sh) {
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
              'DOT SPACING',
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
            max: 5.0,
            onChanged: (v) => setState(() => _post = _post.copyWith(dotSpacing: v)),
          ),
        ),

        // Highlight Today Glow Toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Highlight Today with Ring & Glow', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontFamily: 'Poppins')),
          value: _post.highlightToday,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(highlightToday: v)),
        ),
      ],
    );
  }

  // ─── Tab 3: Content & Viral Quotes ───
  Widget _buildContentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year Title Input
        TextField(
          controller: _titleController,
          onChanged: (val) => setState(() => _post = _post.copyWith(title: val.trim())),
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'GRAPHIC TITLE',
            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontFamily: 'Poppins'),
            filled: true,
            fillColor: AppColors.background,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle / Reflection Input
        TextField(
          controller: _subtitleController,
          onChanged: (val) => setState(() => _post = _post.copyWith(subtitle: val.trim())),
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins', fontSize: 12),
          decoration: InputDecoration(
            labelText: 'SUBTITLE / TIME REFLECTION',
            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontFamily: 'Poppins'),
            filled: true,
            fillColor: AppColors.background,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 6),

        // Viral Quotes Selector
        const Text(
          'TIME REFLECTION QUOTES (1-TAP APPLY)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: YearQuotesLibrary.quotes.map((q) {
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
                      _post = _post.copyWith(subtitle: q);
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Author handle & Avatar row
        Row(
          children: [
            Expanded(
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

  // ─── Tab 4: Theme ───
  Widget _buildThemeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLOR THEME PALETTE',
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
          itemCount: YearTheme.values.length,
          itemBuilder: (ctx, idx) {
            final th = YearTheme.values[idx];
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
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: th.passedColor, shape: BoxShape.circle)),
                        const SizedBox(width: 3),
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: th.todayColor, shape: BoxShape.circle)),
                        const SizedBox(width: 3),
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: th.remainingColor, shape: BoxShape.circle)),
                      ],
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

  // ─── Tab 5: Format & Aspect Ratio ───
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
          children: YearRatio.values.map((r) {
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

        // Transparent PNG Overlay Toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Transparent Background (PNG Overlay)', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontFamily: 'Poppins')),
          subtitle: const Text('No background fill, ideal for video overlays in CapCut/Premiere', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontFamily: 'Poppins')),
          value: _post.transparentBg,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(transparentBg: v)),
        ),
      ],
    );
  }

  // ─── Tab 6: Backdrop & Wallpaper ───
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
            itemCount: YearBackdropPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = YearBackdropPreset.presets[index];
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

  // ─── Tab 7: Badges & Toggles ───
  Widget _buildBadgesTab() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Hero Progress Bar', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
          value: _post.showProgressBar,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(showProgressBar: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Countdown Stats Badges', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
          subtitle: const Text('Days Passed, Days Left, Weeks Left, Quarter', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontFamily: 'Poppins')),
          value: _post.showStatsBadges,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _post = _post.copyWith(showStatsBadges: v)),
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
              tooltip: 'Reset to live date',
              onPressed: () {
                setState(() {
                  _post = YearProgressPost.initialDefault;
                  _syncControllersFromPost(YearProgressPost.initialDefault);
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
              tooltip: 'Share Year Progress',
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
                  _lastSavedPath != null ? 'Saved to Gallery' : 'Export Year Progress',
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

