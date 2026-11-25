import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/pixel_art_model.dart';
import 'services/pixel_art_service.dart';
import 'widgets/pixel_art_canvas_view.dart';

/// 8-Bit Pixel Art & Retro Gaming Photo Studio:
/// - Transforms any photo into retro pixel art with 12 console palettes
/// - 4 Dithering engines (Flat, Bayer 4x4, Bayer 2x2, Floyd-Steinberg Error Diffusion)
/// - 4 Block geometries (Classic Squares, LCD Matrix, LED Board, Circular Pegboard Beads)
/// - Sprite outline contour sharpening, RGB chromatic shift, CRT scanlines, & vignette
/// - 7 retro frames + Corner HUD badges + Interactive Before/After Split Wipe compare
/// - Watermark-style horizontal control tabs & 1080p+ MediaStore PNG export
class PixelArtMakerScreen extends StatefulWidget {
  const PixelArtMakerScreen({super.key});

  @override
  State<PixelArtMakerScreen> createState() => _PixelArtMakerScreenState();
}

class _PixelArtMakerScreenState extends State<PixelArtMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  // Processing state
  img.Image? _workingImage;
  ui.Image? _originalUiImage;
  ui.Image? _pixelUiImage;
  Uint8List? _pixelRgbaBytes;
  int _gridCols = 56;
  int _gridRows = 56;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isHoldingPeek = false;
  String? _lastSavedPath;

  // Active configuration
  PixelArtConfig _config = PixelArtConfig.initialDefault;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers for custom frames & HUD
  late TextEditingController _customTitleController;
  late TextEditingController _rpgTextController;
  late TextEditingController _rpgSpeakerController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Pixel Art Studio');
    _customTitleController = TextEditingController(text: _config.customTitleText);
    _rpgTextController = TextEditingController(text: _config.rpgDialogueText);
    _rpgSpeakerController = TextEditingController(text: _config.rpgSpeakerName);
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _rpgTextController.dispose();
    _rpgSpeakerController.dispose();
    _originalUiImage?.dispose();
    _pixelUiImage?.dispose();
    super.dispose();
  }

  void _syncControllersFromConfig(PixelArtConfig cfg) {
    _customTitleController.text = cfg.customTitleText;
    _rpgTextController.text = cfg.rpgDialogueText;
    _rpgSpeakerController.text = cfg.rpgSpeakerName;
  }

  /// Loads an image file, prepares original ui.Image for comparison, and renders pixel art.
  Future<void> _loadImageFile(File file) async {
    setState(() => _isProcessing = true);
    final decoded = await PixelArtService().decodeWorkingImage(file);
    if (decoded == null) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    final uiOriginal = await PixelArtService().imgImageToUiImage(decoded);

    if (mounted) {
      setState(() {
        _workingImage = decoded;
        _originalUiImage?.dispose();
        _originalUiImage = uiOriginal;
      });
      await _regeneratePixelArt();
    }
  }

  /// Loads the procedural retro synthwave demo scene.
  Future<void> _loadSampleScene() async {
    setState(() => _isProcessing = true);
    final sample = PixelArtService().generateSampleScene(width: 320, height: 320);
    final uiOriginal = await PixelArtService().imgImageToUiImage(sample);

    if (mounted) {
      final presetConfig = _config.copyWith(
        palette: PixelPaletteType.cyberArcade,
        pixelColumns: 64,
        ditherAlgorithm: DitherAlgorithm.bayer4x4,
        blockShape: PixelBlockShape.ledBoard,
        frameStyle: PixelFrameStyle.arcadeCrt,
        rgbSplitColumns: 1,
        crtVignette: true,
      );
      setState(() {
        _workingImage = sample;
        _originalUiImage?.dispose();
        _originalUiImage = uiOriginal;
        _config = presetConfig;
        _syncControllersFromConfig(presetConfig);
      });
      await _regeneratePixelArt();
    }
  }

  /// Re-quantizes and updates pixel art GPU texture whenever config changes.
  Future<void> _regeneratePixelArt() async {
    if (_workingImage == null) return;
    setState(() => _isProcessing = true);

    try {
      final result = await PixelArtService().processPixelArt(
        source: _workingImage!,
        config: _config,
      );

      if (mounted) {
        setState(() {
          _pixelUiImage?.dispose();
          _pixelUiImage = result.pixelImage;
          _pixelRgbaBytes = result.rgbaBytes;
          _gridCols = result.cols;
          _gridRows = result.rows;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error regenerating pixel art: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await PixelArtService().pickImage();
    if (file != null) {
      await _loadImageFile(file);
    }
  }

  Future<void> _exportPixelArt() async {
    if (_pixelUiImage == null) return;
    if (_config.compareMode == CompareViewMode.fullOriginal) {
      setState(() => _config = _config.copyWith(compareMode: CompareViewMode.off));
      await Future.delayed(const Duration(milliseconds: 50));
    }
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await PixelArtService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await PixelArtService().savePixelArtToGallery(
        pngBytes,
        _config.palette.label,
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
                    'Pixel art saved to Gallery! (Pictures/Quick Post Pixel Art)',
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
      debugPrint('Error saving pixel art: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePixelArt() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await PixelArtService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await PixelArtService().savePixelArtToGallery(
          pngBytes,
          _config.palette.label,
        );
      }
    }

    if (_lastSavedPath != null) {
      await PixelArtService().sharePixelArt(_lastSavedPath!);
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
          '8-Bit Pixel Art Studio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          if (_workingImage != null) ...[
            PopupMenuButton<PixelArtConfig>(
              tooltip: '1-Tap Studio Presets',
              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (preset) {
                HapticFeedback.selectionClick();
                setState(() {
                  _config = preset;
                  _syncControllersFromConfig(preset);
                });
                _regeneratePixelArt();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '1-TAP STUDIO PRESETS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...PixelArtConfig.studioPresets.map((preset) {
                  return PopupMenuItem(
                    value: preset.config,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            ...preset.config.palette.swatchColors.take(3).map(
                                  (c) => Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 3),
                                    decoration: BoxDecoration(
                                      color: c,
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: Colors.black26, width: 0.4),
                                    ),
                                  ),
                                ),
                            const SizedBox(width: 6),
                            Text(
                              preset.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            IconButton(
              tooltip: 'Change Photo',
              icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
              onPressed: _pickImage,
            ),
          ],
        ],
      ),
      body: _workingImage == null ? _buildEmptyState() : _buildEditorBody(),
    );
  }

  /// Initial welcome screen prompting gallery selection or one-tap demo scene.
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00796B).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.grid_4x4_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              '8-Bit Pixel Art Studio',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transform photos into authentic Game Boy, 1-Bit Playdate, NES, SNES & LED pixel art with Floyd-Steinberg dithering, CRT scanlines, and retro shells.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_rounded, size: 20),
                label: const Text(
                  'Select Photo from Gallery',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loadSampleScene,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'Try Retro Demo Scene',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full interactive studio editor layout.
  Widget _buildEditorBody() {
    final effectiveConfig = _isHoldingPeek
        ? _config.copyWith(compareMode: CompareViewMode.fullOriginal)
        : _config;

    return Column(
      children: [
        // ─── Proportional Center Canvas View ───
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: PixelArtCanvasView(
                      boundaryKey: _boundaryKey,
                      pixelImage: _pixelUiImage,
                      rgbaBytes: _pixelRgbaBytes,
                      originalImage: _originalUiImage,
                      gridCols: _gridCols,
                      gridRows: _gridRows,
                      config: effectiveConfig,
                      onHoldCompareStart: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isHoldingPeek = true);
                      },
                      onHoldCompareEnd: () {
                        setState(() => _isHoldingPeek = false);
                      },
                    ),
                  ),
                ),
                if (effectiveConfig.compareMode == CompareViewMode.fullOriginal)
                  Positioned(
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ORIGINAL PHOTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Rendering...',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ─── Watermark-style Active Tab Content Panel ───
        if (_isTabContentExpanded) _buildActiveTabContent(),

        // ─── Watermark-style Horizontal Control Tabs Bar ───
        _buildControlTabsBar(),

        // ─── Bottom Sticky Action Dock ───
        _buildBottomActionDock(),
      ],
    );
  }

  // ─── Horizontal Control Tabs Bar (64px) ───
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
          _buildTabItem(0, Icons.grid_4x4_rounded, 'Pixels', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.palette_rounded, 'Palette', const Color(0xFF8B5CF6)),
          _buildTabItem(2, Icons.tune_rounded, 'Adjust', const Color(0xFFEA580C)),
          _buildTabItem(3, Icons.blur_on_rounded, 'FX & CRT', const Color(0xFF0284C7)),
          _buildTabItem(4, Icons.videogame_asset_rounded, 'Frame', const Color(0xFFF59E0B)),
          _buildTabItem(5, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
          _buildTabItem(6, Icons.compare_rounded, 'Compare', const Color(0xFFEC4899)),
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
        width: 74,
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

  // ─── Active Tab Content Panel ───
  Widget _buildActiveTabContent() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 245),
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _buildCurrentTabWidget(),
      ),
    );
  }

  Widget _buildCurrentTabWidget() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPixelsTab();
      case 1:
        return _buildPaletteTab();
      case 2:
        return _buildAdjustTab();
      case 3:
        return _buildFxCrtTab();
      case 4:
        return _buildFrameTab();
      case 5:
        return _buildFormatTab();
      case 6:
        return _buildCompareTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── TAB 0: Pixels, Resolution & Block Shape ───
  Widget _buildPixelsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pixel Grid Density',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_config.pixelColumns} cols (${_gridCols}x$_gridRows)',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _config.pixelColumns.toDouble(),
          min: 16,
          max: 128,
          divisions: 28,
          activeColor: AppColors.primary,
          onChanged: (val) => setState(() => _config = _config.copyWith(pixelColumns: val.round())),
          onChangeEnd: (_) => _regeneratePixelArt(),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildResolutionChip('Chunky', 24),
            _buildResolutionChip('Game Boy', 40),
            _buildResolutionChip('NES 8-Bit', 56),
            _buildResolutionChip('SNES 16-Bit', 72),
            _buildResolutionChip('Arcade', 96),
            _buildResolutionChip('HD Pixel', 128),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Pixel Geometry Style',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: PixelBlockShape.values.map((shape) {
            final bool isSelected = _config.blockShape == shape;
            return ChoiceChip(
              avatar: Icon(shape.icon, size: 15, color: isSelected ? AppColors.primary : Colors.grey.shade600),
              label: Text(shape.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(blockShape: shape));
              },
            );
          }).toList(),
        ),
        if (_config.blockShape == PixelBlockShape.square) ...[
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text(
              'Show Pixel Matrix Grid Lines',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
            ),
            value: _config.showPixelGrid,
            onChanged: (val) => setState(() => _config = _config.copyWith(showPixelGrid: val)),
          ),
        ],
      ],
    );
  }

  Widget _buildResolutionChip(String label, int cols) {
    final bool isSelected = _config.pixelColumns == cols;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
      selected: isSelected,
      selectedColor: AppColors.primarySurface,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _config = _config.copyWith(pixelColumns: cols));
        _regeneratePixelArt();
      },
    );
  }

  // ─── TAB 1: 12 Retro Console Palettes ───
  Widget _buildPaletteTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Retro Console Palette',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            FilterChip(
              label: const Text('Invert Colors', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: _config.invertColors,
              selectedColor: AppColors.primarySurface,
              checkmarkColor: AppColors.primary,
              onSelected: (val) {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(invertColors: val));
                _regeneratePixelArt();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...PixelPaletteType.values.map((palette) {
          final bool isSelected = _config.palette == palette;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface.withValues(alpha: 0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(
                palette.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              subtitle: Text(
                palette.description,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontFamily: 'Poppins'),
              ),
              trailing: SizedBox(
                width: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: palette.swatchColors.take(4).map((c) {
                    return Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black26, width: 0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(palette: palette));
                _regeneratePixelArt();
              },
            ),
          );
        }),
      ],
    );
  }

  // ─── TAB 2: Color & Lighting Adjustments ───
  Widget _buildAdjustTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Image Pre-Quantize Tuning',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _config = _config.copyWith(
                      brightness: 0.0,
                      contrast: 1.15,
                      saturation: 1.05,
                      edgeOutline: false,
                    ));
                _regeneratePixelArt();
              },
              child: const Text('Reset', style: TextStyle(fontSize: 11.5, color: AppColors.primary)),
            ),
          ],
        ),
        _buildSliderRow(
          label: 'Brightness',
          displayValue: '${(_config.brightness * 100).round()}%',
          value: _config.brightness,
          min: -0.35,
          max: 0.35,
          onChanged: (v) => setState(() => _config = _config.copyWith(brightness: v)),
          onChangeEnd: (_) => _regeneratePixelArt(),
        ),
        _buildSliderRow(
          label: 'Contrast',
          displayValue: '${(_config.contrast * 100).round()}%',
          value: _config.contrast,
          min: 0.6,
          max: 1.9,
          onChanged: (v) => setState(() => _config = _config.copyWith(contrast: v)),
          onChangeEnd: (_) => _regeneratePixelArt(),
        ),
        _buildSliderRow(
          label: 'Saturation',
          displayValue: '${(_config.saturation * 100).round()}%',
          value: _config.saturation,
          min: 0.0,
          max: 1.8,
          onChanged: (v) => setState(() => _config = _config.copyWith(saturation: v)),
          onChangeEnd: (_) => _regeneratePixelArt(),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Sprite Ink Outlines',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          ),
          subtitle: const Text(
            'Darkens strong edges like 16-bit hand-drawn game sprites',
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontFamily: 'Poppins'),
          ),
          value: _config.edgeOutline,
          onChanged: (val) {
            setState(() => _config = _config.copyWith(edgeOutline: val));
            _regeneratePixelArt();
          },
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String displayValue,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.primary,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ─── TAB 3: Dithering, Chromatic Shift & CRT FX ───
  Widget _buildFxCrtTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dithering Engine',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: DitherAlgorithm.values.map((alg) {
            final bool isSelected = _config.ditherAlgorithm == alg;
            return ChoiceChip(
              label: Text(alg.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(ditherAlgorithm: alg));
                _regeneratePixelArt();
              },
            );
          }).toList(),
        ),
        if (_config.ditherAlgorithm != DitherAlgorithm.none)
          _buildSliderRow(
            label: 'Dither Mix',
            displayValue: '${(_config.ditherStrength * 100).round()}%',
            value: _config.ditherStrength,
            min: 0.2,
            max: 1.0,
            onChanged: (v) => setState(() => _config = _config.copyWith(ditherStrength: v)),
            onChangeEnd: (_) => _regeneratePixelArt(),
          ),
        const Divider(height: 14),
        // RGB Chromatic Split Glitch
        _buildSliderRow(
          label: 'RGB Split',
          displayValue: _config.rgbSplitColumns == 0 ? 'Off' : '${_config.rgbSplitColumns} px',
          value: _config.rgbSplitColumns.toDouble(),
          min: 0,
          max: 3,
          divisions: 3,
          onChanged: (v) => setState(() => _config = _config.copyWith(rgbSplitColumns: v.round())),
          onChangeEnd: (_) => _regeneratePixelArt(),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'CRT Monitor Scanlines',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          ),
          value: _config.crtScanlines,
          onChanged: (val) => setState(() => _config = _config.copyWith(crtScanlines: val)),
        ),
        if (_config.crtScanlines)
          _buildSliderRow(
            label: 'Scanlines',
            displayValue: '${(_config.scanlineOpacity * 100).round()}%',
            value: _config.scanlineOpacity,
            min: 0.05,
            max: 0.55,
            onChanged: (v) => setState(() => _config = _config.copyWith(scanlineOpacity: v)),
          ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'CRT Screen Corner Vignette',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          ),
          value: _config.crtVignette,
          onChanged: (val) => setState(() => _config = _config.copyWith(crtVignette: val)),
        ),
      ],
    );
  }

  // ─── TAB 4: Retro Frames, Corner HUD & Custom Captions ───
  Widget _buildFrameTab() {
    final bool needsCustomTitle = _config.frameStyle == PixelFrameStyle.retroWin95 ||
        _config.frameStyle == PixelFrameStyle.arcadeCrt ||
        _config.frameStyle == PixelFrameStyle.polaroid8Bit ||
        _config.frameStyle == PixelFrameStyle.cartridgeCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Retro Frame & Console Shell',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PixelFrameStyle.values.map((frame) {
            final bool isSelected = _config.frameStyle == frame;
            return ChoiceChip(
              avatar: Icon(frame.icon, size: 15, color: isSelected ? AppColors.primary : Colors.grey.shade600),
              label: Text(frame.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(frameStyle: frame));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Corner Game HUD Badge',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PixelHudBadge.values.map((badge) {
            final bool isSelected = _config.hudBadge == badge;
            return ChoiceChip(
              label: Text(badge.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(hudBadge: badge));
              },
            );
          }).toList(),
        ),
        if (needsCustomTitle) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customTitleController,
            decoration: InputDecoration(
              labelText: 'Frame Caption / Title',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) => setState(() => _config = _config.copyWith(customTitleText: val)),
          ),
        ],
        if (_config.frameStyle == PixelFrameStyle.rpgDialogBox) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _rpgSpeakerController,
            decoration: InputDecoration(
              labelText: 'RPG Speaker Name',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) => setState(() => _config = _config.copyWith(rpgSpeakerName: val)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rpgTextController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'RPG Dialogue Text',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) => setState(() => _config = _config.copyWith(rpgDialogueText: val)),
          ),
        ],
      ],
    );
  }

  // ─── TAB 5: Canvas Ratio & Format ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Canvas Aspect Ratio',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        ...PixelAspectRatio.values.map((ratio) {
          final bool isSelected = _config.aspectRatio == ratio;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface.withValues(alpha: 0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.aspect_ratio_rounded,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
              title: Text(
                ratio.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              subtitle: Text(
                ratio.subtitle,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontFamily: 'Poppins'),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                  : null,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(aspectRatio: ratio));
                _regeneratePixelArt();
              },
            ),
          );
        }),
      ],
    );
  }

  // ─── TAB 6: Before / After Compare & Split Wipe ───
  Widget _buildCompareTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Before / After Comparison',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tip: You can also long-press the canvas anytime to peek at your original photo.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CompareViewMode.values.map((mode) {
            final bool isSelected = _config.compareMode == mode;
            return ChoiceChip(
              label: Text(mode.label, style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _config = _config.copyWith(compareMode: mode));
              },
            );
          }).toList(),
        ),
        if (_config.compareMode == CompareViewMode.splitWipe) ...[
          const SizedBox(height: 10),
          _buildSliderRow(
            label: 'Split Line',
            displayValue: '${(_config.compareSplit * 100).round()}%',
            value: _config.compareSplit,
            min: 0.08,
            max: 0.92,
            onChanged: (v) => setState(() => _config = _config.copyWith(compareSplit: v)),
          ),
        ],
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
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Choose another photo',
              icon: const Icon(Icons.photo_library_rounded, color: AppColors.textPrimary),
              onPressed: _pickImage,
            ),
            IconButton(
              tooltip: 'Reset Settings',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: () {
                setState(() {
                  _config = PixelArtConfig.initialDefault;
                  _syncControllersFromConfig(_config);
                });
                _regeneratePixelArt();
              },
            ),
            IconButton(
              tooltip: 'Share Pixel Art',
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              onPressed: _sharePixelArt,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _exportPixelArt,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.file_download_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Exporting...' : 'Save to Gallery',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
