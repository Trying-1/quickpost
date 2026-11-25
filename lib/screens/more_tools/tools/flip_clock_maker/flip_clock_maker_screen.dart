import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/flip_clock_model.dart';
import 'services/flip_clock_service.dart';
import 'widgets/flip_clock_canvas_view.dart';

/// Retro Flip Clock & Event Countdown Studio:
/// - Generates realistic split-flap mechanical flip clocks & event countdown graphics for Reels, Shorts & Stories
/// - Watermark-screen-style integrated control tabs (Event, Digits, Progress, Theme, Format, Backdrop)
/// - 3 archetypes: Event Countdown (with calendar date auto-calculation), Desk Flip Clock, and Focus Timer
/// - 6 mechanical themes (Vintage Flap, Airport Board, Neon Cyber, Warm Cream, Matcha Desk, Minimal White)
/// - Multiple aspect ratios: 4:5 Feed Portrait, 1:1 Square, 9:16 Story/Reels, or Clock Only for video overlays
/// - Uncompressed 1080p+ canvas capture & MediaStore saving to Pictures/Quick Post Flip Clocks
class FlipClockMakerScreen extends StatefulWidget {
  const FlipClockMakerScreen({super.key});

  @override
  State<FlipClockMakerScreen> createState() => _FlipClockMakerScreenState();
}

class _FlipClockMakerScreenState extends State<FlipClockMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  FlipClockPost _post = FlipClockPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _amPmController;
  late TextEditingController _u1ValController;
  late TextEditingController _u1LblController;
  late TextEditingController _u2ValController;
  late TextEditingController _u2LblController;
  late TextEditingController _u3ValController;
  late TextEditingController _u3LblController;
  late TextEditingController _u4ValController;
  late TextEditingController _u4LblController;
  late TextEditingController _progressLblController;
  late TextEditingController _handleController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Flip Clock Studio');
    _titleController = TextEditingController(text: _post.eventTitle);
    _subtitleController = TextEditingController(text: _post.eventSubtitle);
    _amPmController = TextEditingController(text: _post.amPmBadge);
    _u1ValController = TextEditingController(text: _post.unit1Value);
    _u1LblController = TextEditingController(text: _post.unit1Label);
    _u2ValController = TextEditingController(text: _post.unit2Value);
    _u2LblController = TextEditingController(text: _post.unit2Label);
    _u3ValController = TextEditingController(text: _post.unit3Value);
    _u3LblController = TextEditingController(text: _post.unit3Label);
    _u4ValController = TextEditingController(text: _post.unit4Value);
    _u4LblController = TextEditingController(text: _post.unit4Label);
    _progressLblController = TextEditingController(text: _post.progressLabel);
    _handleController = TextEditingController(text: _post.creatorHandle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _amPmController.dispose();
    _u1ValController.dispose();
    _u1LblController.dispose();
    _u2ValController.dispose();
    _u2LblController.dispose();
    _u3ValController.dispose();
    _u3LblController.dispose();
    _u4ValController.dispose();
    _u4LblController.dispose();
    _progressLblController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  void _syncControllersFromPost(FlipClockPost post) {
    _titleController.text = post.eventTitle;
    _subtitleController.text = post.eventSubtitle;
    _amPmController.text = post.amPmBadge;
    _u1ValController.text = post.unit1Value;
    _u1LblController.text = post.unit1Label;
    _u2ValController.text = post.unit2Value;
    _u2LblController.text = post.unit2Label;
    _u3ValController.text = post.unit3Value;
    _u3LblController.text = post.unit3Label;
    _u4ValController.text = post.unit4Value;
    _u4LblController.text = post.unit4Label;
    _progressLblController.text = post.progressLabel;
    _handleController.text = post.creatorHandle;
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() {
        _post = _post.withTargetDate(picked);
        _syncControllersFromPost(_post);
      });
    }
  }

  Future<void> _pickWallpaper() async {
    final file = await FlipClockService().pickImage();
    if (file != null && mounted) {
      setState(() => _post = _post.copyWith(customWallpaperPath: file.path));
    }
  }

  Future<void> _exportFlipClock() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await FlipClockService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await FlipClockService().saveFlipClockToGallery(
        pngBytes,
        _post.eventTitle.isNotEmpty ? _post.eventTitle : 'FlipClock',
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
                    'Flip Clock graphic saved to Gallery! (Pictures/Quick Post Flip Clocks)',
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
      debugPrint('Error exporting flip clock: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareFlipClock() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await FlipClockService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await FlipClockService().saveFlipClockToGallery(
          pngBytes,
          _post.eventTitle.isNotEmpty ? _post.eventTitle : 'FlipClock',
        );
      }
    }

    if (_lastSavedPath != null) {
      await FlipClockService().shareFlipClock(_lastSavedPath!);
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
          'Retro Flip Clock Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<FlipClockPost>(
            tooltip: 'Load Viral Clock Preset',
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
                child: Text('VIRAL CLOCK PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...FlipClockPost.viralPresets.map((preset) {
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
                        child: Text(
                          preset.eventTitle,
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
                    child: FlipClockCanvasView(
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
          _buildTabItem(0, Icons.event_note_rounded, 'Event', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.dialpad_rounded, 'Digits', const Color(0xFF0284C7)),
          _buildTabItem(2, Icons.linear_scale_rounded, 'Progress', const Color(0xFFF59E0B)),
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
        return _buildEventTab();
      case 1:
        return _buildDigitsTab();
      case 2:
        return _buildProgressTab();
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

  // ─── Tab 0: Event Details & Target Date Calculator ───
  Widget _buildEventTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: FlipClockMode.values.map((m) {
            final isSelected = _post.mode == m;
            return ChoiceChip(
              avatar: Icon(m.icon, size: 14, color: isSelected ? AppColors.primary : Colors.grey.shade700),
              label: Text(m.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) => setState(() => _post = _post.copyWith(mode: m)),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title / Headline',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(eventTitle: val)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _amPmController,
                decoration: InputDecoration(
                  labelText: 'Top Pill Badge',
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                onChanged: (val) => setState(() => _post = _post.copyWith(amPmBadge: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _subtitleController,
          decoration: InputDecoration(
            labelText: 'Subtitle / Date Info',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(eventSubtitle: val)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Pick Target Date & Auto-Calculate Countdown', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _pickTargetDate,
          ),
        ),
      ],
    );
  }

  // ─── Tab 1: Split-Flap Digits Editor ───
  Widget _buildDigitsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show 4th Flip Tile (Seconds)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            Switch(
              value: _post.showUnit4,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showUnit4: val)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildUnitPairEditor('Tile 1', _u1ValController, _u1LblController, (v) => _post = _post.copyWith(unit1Value: v), (l) => _post = _post.copyWith(unit1Label: l))),
            const SizedBox(width: 6),
            Expanded(child: _buildUnitPairEditor('Tile 2', _u2ValController, _u2LblController, (v) => _post = _post.copyWith(unit2Value: v), (l) => _post = _post.copyWith(unit2Label: l))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildUnitPairEditor('Tile 3', _u3ValController, _u3LblController, (v) => _post = _post.copyWith(unit3Value: v), (l) => _post = _post.copyWith(unit3Label: l))),
            const SizedBox(width: 6),
            if (_post.showUnit4)
              Expanded(child: _buildUnitPairEditor('Tile 4', _u4ValController, _u4LblController, (v) => _post = _post.copyWith(unit4Value: v), (l) => _post = _post.copyWith(unit4Label: l)))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildUnitPairEditor(
    String name,
    TextEditingController valCtrl,
    TextEditingController lblCtrl,
    Function(String) onValChanged,
    Function(String) onLblChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: TextField(
              controller: valCtrl,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Num',
                labelStyle: const TextStyle(fontSize: 9),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              onChanged: (v) => setState(() => onValChanged(v)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: lblCtrl,
              decoration: InputDecoration(
                labelText: '$name Lbl',
                labelStyle: const TextStyle(fontSize: 9),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
              onChanged: (l) => setState(() => onLblChanged(l)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Milestone Progress & Watermark ───
  Widget _buildProgressTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Milestone Progress Bar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            Switch(
              value: _post.showProgressBar,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showProgressBar: val)),
            ),
          ],
        ),
        if (_post.showProgressBar) ...[
          Row(
            children: [
              Text('Progress: ${(_post.progressPercent * 100).round()}%', style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins')),
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
          TextField(
            controller: _progressLblController,
            decoration: InputDecoration(
              labelText: 'Progress Description',
              labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            onChanged: (val) => setState(() => _post = _post.copyWith(progressLabel: val)),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _handleController,
          decoration: InputDecoration(
            labelText: 'Creator Handle / Watermark',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(creatorHandle: val)),
        ),
      ],
    );
  }

  // ─── Tab 3: Mechanical Clock Themes ───
  Widget _buildThemeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FLIP CLOCK FINISHES',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: FlipClockTheme.values.length,
            itemBuilder: (ctx, index) {
              final theme = FlipClockTheme.values[index];
              final isSelected = _post.theme == theme;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(theme: theme));
                },
                child: Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.canvasBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: theme.tileBgTop, borderRadius: BorderRadius.circular(4)),
                        child: Text('52', style: TextStyle(color: theme.digitColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme == FlipClockTheme.minimalWhite || theme == FlipClockTheme.aestheticCream ? Colors.black : Colors.white,
                          fontSize: 9.5,
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
          children: FlipClockRatio.values.map((ratio) {
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Transparent PNG (Video Overlay)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.transparentBg,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(transparentBg: val)),
            ),
          ],
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
            itemCount: FlipClockBackdropPreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = FlipClockBackdropPreset.presets[index];
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
                  _post.customWallpaperPath != null ? 'Change Custom Wallpaper' : 'Custom Photo Backdrop',
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
                  _post = FlipClockPost.initialDefault;
                  _syncControllersFromPost(_post);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share clock graphic',
              onPressed: _isSaving ? null : _shareFlipClock,
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
                onPressed: _isSaving ? null : _exportFlipClock,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

