import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/color_fx_preset.dart';
import 'services/photo_color_fx_service.dart';
import 'widgets/before_after_slider.dart';
import 'widgets/fx_adjustments_panel.dart';
import 'widgets/fx_preset_picker.dart';

/// Photo Color Inverter & Black/White FX Studio:
/// - Real-time GPU color matrix negative inversion & monochrome noir processing
/// - Interactive split-screen Before/After wipe comparison slider
/// - Fine-tuning brightness and contrast controls
/// - Full-resolution hardware-accelerated Skia PNG render
/// - Direct Android MediaStore saving to Pictures/Quick Post FX with media scanner
class PhotoColorFxScreen extends StatefulWidget {
  final File? initialImageFile;

  const PhotoColorFxScreen({super.key, this.initialImageFile});

  @override
  State<PhotoColorFxScreen> createState() => _PhotoColorFxScreenState();
}

class _PhotoColorFxScreenState extends State<PhotoColorFxScreen> with SingleTickerProviderStateMixin {
  File? _imageFile;
  ColorFxType _selectedPreset = ColorFxType.invert;
  double _brightness = 0.0;
  double _contrast = 0.0;
  bool _isSaving = false;
  bool _showOriginalOnly = false;
  String? _lastSavedPath;

  late TabController _tabController;
  final List<String> _tabs = ['FX Presets', 'Fine-Tune', 'Compare'];
  final List<IconData> _tabIcons = [
    Icons.auto_awesome_rounded,
    Icons.tune_rounded,
    Icons.compare_rounded,
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Photo Color FX Studio');
    _imageFile = widget.initialImageFile;
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await PhotoColorFxService().pickImage();
    if (picked != null && mounted) {
      setState(() {
        _imageFile = picked;
        _lastSavedPath = null;
      });
    }
  }

  List<double> get _currentMatrix => _selectedPreset.computeMatrix(
        brightness: _brightness,
        contrast: _contrast,
      );

  Future<void> _exportAndSave() async {
    if (_imageFile == null) return;
    setState(() => _isSaving = true);

    try {
      final bytes = await PhotoColorFxService().renderFilteredImage(
        imageFile: _imageFile!,
        matrix: _currentMatrix,
      );

      final path = await PhotoColorFxService().saveFilteredImageToGallery(
        bytes,
        _selectedPreset.id,
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
                Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Photo saved to Gallery! (Pictures/Quick Post FX)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting photo: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePhoto() async {
    if (_imageFile == null) return;

    if (_lastSavedPath == null) {
      setState(() => _isSaving = true);
      final bytes = await PhotoColorFxService().renderFilteredImage(
        imageFile: _imageFile!,
        matrix: _currentMatrix,
      );
      final path = await PhotoColorFxService().saveFilteredImageToGallery(
        bytes,
        _selectedPreset.id,
      );
      setState(() {
        _isSaving = false;
        _lastSavedPath = path;
      });
    }

    if (_lastSavedPath != null) {
      await PhotoColorFxService().shareFilteredImage(_lastSavedPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Photo Inverter & B&W FX',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          if (_imageFile != null)
            IconButton(
              tooltip: 'Change Photo',
              icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8)),
              onPressed: _pickImage,
            ),
        ],
      ),
      body: _imageFile == null ? _buildEmptyState() : _buildEditor(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.invert_colors_rounded, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Photo Color Inverter & B&W FX',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Transform photos into color negatives, dramatic noir black & white, archival sepia, and cyanotype blueprint prints.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.45, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Pick Photo from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // Top Active Preset Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0B0F19),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedPreset.category.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedPreset.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
              ),
              const Spacer(),
              // "Hold to View Original" Button
              GestureDetector(
                onTapDown: (_) => setState(() => _showOriginalOnly = true),
                onTapUp: (_) => setState(() => _showOriginalOnly = false),
                onTapCancel: () => setState(() => _showOriginalOnly = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showOriginalOnly ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_red_eye_rounded,
                        size: 13,
                        color: _showOriginalOnly ? const Color(0xFF0F172A) : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hold Original',
                        style: TextStyle(
                          color: _showOriginalOnly ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Interactive Split-Screen Wipe Canvas
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BeforeAfterSlider(
              imageFile: _imageFile!,
              matrix: _currentMatrix,
              showOriginalOnly: _showOriginalOnly,
            ),
          ),
        ),

        // Horizontal Control Tab Dock
        Container(
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(top: BorderSide(color: Colors.white10), bottom: BorderSide(color: Colors.white10)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00E5FF),
            indicatorWeight: 3,
            labelColor: const Color(0xFF00E5FF),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13, fontFamily: 'Poppins'),
            tabs: List.generate(_tabs.length, (i) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tabIcons[i], size: 15),
                    const SizedBox(width: 6),
                    Text(_tabs[i]),
                  ],
                ),
              );
            }),
          ),
        ),

        // Tab Views (Presets / Fine-Tune / Compare Info)
        SizedBox(
          height: 140,
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Presets Horizontal Carousel
              Center(
                child: FxPresetPicker(
                  imageFile: _imageFile!,
                  selectedPreset: _selectedPreset,
                  onSelectPreset: (preset) {
                    setState(() {
                      _selectedPreset = preset;
                    });
                  },
                ),
              ),

              // 2. Adjustments Panel
              Center(
                child: FxAdjustmentsPanel(
                  brightness: _brightness,
                  contrast: _contrast,
                  onBrightnessChanged: (v) => setState(() => _brightness = v),
                  onContrastChanged: (v) => setState(() => _contrast = v),
                  onReset: () => setState(() {
                    _brightness = 0.0;
                    _contrast = 0.0;
                  }),
                ),
              ),

              // 3. Compare Wipe Guide
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.compare_rounded, color: Color(0xFF00E5FF), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Drag Center Handle to Compare',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Slide left or right on the canvas to inspect the original versus filtered photo. You can also press and hold "Hold Original" in the top bar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Action Bar (Save to Gallery & Share)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Change Photo Button
                IconButton(
                  tooltip: 'Choose different photo',
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8), size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 8),

                // Share Button
                IconButton(
                  tooltip: 'Share photo',
                  onPressed: _isSaving ? null : _sharePhoto,
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 10),

                // Primary Save to Gallery Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _exportAndSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _lastSavedPath != null ? 'Saved to Gallery' : 'Save to Gallery',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

