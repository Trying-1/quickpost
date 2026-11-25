import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/ascii_art_model.dart';
import 'services/ascii_art_service.dart';
import 'widgets/ascii_art_canvas_view.dart';

/// ASCII Art Studio:
/// - Converts any photo into razor-sharp typographic ASCII art rendered as vector text
/// - 7 character density ramps (Classic, Ultra 70-char, ANSI Blocks, Binary 01, Custom)
/// - 7 terminal & poster palettes (Matrix Green, True Photo RGB, Amber CRT, Synth Neon, Zine Paper, etc.)
/// - Copyable plain-text ASCII export to clipboard + 1080p+ PNG saving to Android MediaStore
/// - Spacious single consolidated bottom control panel with collapsible drawers
class AsciiArtMakerScreen extends StatefulWidget {
  const AsciiArtMakerScreen({super.key});

  @override
  State<AsciiArtMakerScreen> createState() => _AsciiArtMakerScreenState();
}

class _AsciiArtMakerScreenState extends State<AsciiArtMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  img.Image? _workingImage;
  ui.Image? _originalUiImage;
  AsciiRenderData? _renderData;

  AsciiArtConfig _config = AsciiArtConfig.initialDefault;
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isPeekingOriginal = false;
  String? _lastSavedPath;

  late TextEditingController _customRampController;
  late TextEditingController _headerTitleController;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'ASCII Art Studio');
    _customRampController = TextEditingController(text: _config.customRampText);
    _headerTitleController = TextEditingController(text: _config.headerTitle);
  }

  @override
  void dispose() {
    _customRampController.dispose();
    _headerTitleController.dispose();
    _originalUiImage?.dispose();
    _renderData?.dispose();
    super.dispose();
  }

  void _syncControllersFromConfig(AsciiArtConfig cfg) {
    _customRampController.text = cfg.customRampText;
    _headerTitleController.text = cfg.headerTitle;
  }

  Future<void> _loadImageFile(File file) async {
    setState(() => _isProcessing = true);
    final decoded = await AsciiArtService().decodeImage(file);
    if (decoded == null) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    if (mounted) {
      setState(() {
        _workingImage = decoded.samplingImg;
        _originalUiImage?.dispose();
        _originalUiImage = decoded.previewUiImg;
      });
      await _regenerateAscii();
    }
  }

  Future<void> _loadSampleScene() async {
    setState(() => _isProcessing = true);
    final sample = await AsciiArtService().generateSampleScene();
    if (mounted) {
      setState(() {
        _workingImage = sample.samplingImg;
        _originalUiImage?.dispose();
        _originalUiImage = sample.previewUiImg;
      });
      await _regenerateAscii();
    }
  }

  Future<void> _regenerateAscii() async {
    if (_workingImage == null) return;
    setState(() => _isProcessing = true);

    try {
      final rendered = await AsciiArtService().generateAsciiArt(
        source: _workingImage!,
        config: _config,
      );

      if (mounted) {
        setState(() {
          _renderData?.dispose();
          _renderData = rendered;
          _isProcessing = false;
        });
      } else {
        rendered.dispose();
      }
    } catch (e) {
      debugPrint('Error generating ASCII: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await AsciiArtService().pickImage();
    if (file != null) {
      await _loadImageFile(file);
    }
  }

  Future<void> _copyAsciiText() async {
    if (_renderData == null || _renderData!.plainText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _renderData!.plainText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${_renderData!.cols}x${_renderData!.rows} ASCII art text to clipboard!',
            style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportAsciiPng() async {
    if (_renderData == null) return;
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await AsciiArtService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final String? path = await AsciiArtService().saveAsciiToGallery(
        pngBytes,
        _config.colorMode.label,
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
                    'ASCII Art saved to Gallery! (Pictures/Quick Post ASCII)',
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
      debugPrint('Error exporting ASCII PNG: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareAscii() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await AsciiArtService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await AsciiArtService().saveAsciiToGallery(
          pngBytes,
          _config.colorMode.label,
        );
      }
    }

    if (_lastSavedPath != null) {
      await AsciiArtService().shareAscii(_lastSavedPath!);
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
          'ASCII Art Studio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          if (_workingImage != null)
            PopupMenuButton<AsciiArtConfig>(
              tooltip: '1-Tap ASCII Presets',
              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (preset) {
                setState(() {
                  _config = preset.copyWith(aspectRatio: _config.aspectRatio);
                  _syncControllersFromConfig(_config);
                });
                _regenerateAscii();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '1-TAP ASCII PRESETS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...AsciiArtConfig.studioPresets.map((preset) {
                  return PopupMenuItem(
                    value: preset.config,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: preset.config.colorMode.fgColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black26),
                              ),
                            ),
                            const SizedBox(width: 8),
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
        ],
      ),
      body: _workingImage == null ? _buildEmptyState() : _buildEditorBody(),
    );
  }

  /// Initial welcome screen prompting gallery pick or built-in sample scene.
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
              alignment: Alignment.center,
              child: const Text(
                '@#%\n*+=\n-:.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFA7F3D0),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ASCII Art Studio',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transform photos into Matrix phosphor terminals, ANSI shade blocks, True-Color typographic prints, and copyable ASCII art.',
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
                  'Try Cosmic ASCII Demo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Spacious Editor Workspace + Single Consolidated Bottom Control Panel.
  Widget _buildEditorBody() {
    return Column(
      children: [
        // ─── Proportional ASCII Canvas + Floating Hold Peek Button ───
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: AsciiArtCanvasView(
                      boundaryKey: _boundaryKey,
                      renderData: _renderData,
                      originalImage: _originalUiImage,
                      config: _config,
                      isPeekingOriginal: _isPeekingOriginal,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTapDown: (_) {
                      setState(() => _isPeekingOriginal = true);
                    },
                    onTapUp: (_) => setState(() => _isPeekingOriginal = false),
                    onTapCancel: () => setState(() => _isPeekingOriginal = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isPeekingOriginal
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPeekingOriginal ? Icons.visibility_rounded : Icons.visibility_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isPeekingOriginal ? 'Original' : 'Hold Peek',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
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
                          'Rendering ASCII...',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ─── Collapsible Tab Drawer ───
        if (_isTabContentExpanded) _buildActiveTabContent(),

        // ─── Single Consolidated Control & Action Panel ───
        _buildConsolidatedControlPanel(),
      ],
    );
  }

  /// Unified 62px bottom control bar with Save leftmost followed by Control Tabs & actions.
  Widget _buildConsolidatedControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              // Leftmost integrated Save tab tile
              GestureDetector(
                onTap: _isSaving ? null : _exportAsciiPng,
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else
                        const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(height: 3),
                      Text(
                        _isSaving ? 'Saving' : 'Save',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                color: Colors.grey.shade200,
              ),
              _buildTabItem(0, Icons.text_fields_rounded, 'Charset', const Color(0xFF00796B)),
              _buildTabItem(1, Icons.palette_rounded, 'Colors', const Color(0xFF8B5CF6)),
              _buildTabItem(2, Icons.tune_rounded, 'FX & Tune', const Color(0xFF0284C7)),
              _buildTabItem(3, Icons.terminal_rounded, 'Frame', const Color(0xFFF59E0B)),
              _buildTabItem(4, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                color: Colors.grey.shade200,
              ),
              _buildQuickActionTile(
                icon: Icons.photo_library_rounded,
                label: 'Photo',
                color: AppColors.textPrimary,
                onTap: _pickImage,
              ),
              _buildQuickActionTile(
                icon: Icons.copy_all_rounded,
                label: 'Copy Txt',
                color: AppColors.textPrimary,
                onTap: _copyAsciiText,
              ),
              _buildQuickActionTile(
                icon: Icons.share_rounded,
                label: 'Share',
                color: AppColors.textPrimary,
                onTap: _shareAscii,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
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
        width: 68,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
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

  Widget _buildActiveTabContent() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isTabContentExpanded = false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _buildCurrentTabWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabWidget() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCharsetTab();
      case 1:
        return _buildColorsTab();
      case 2:
        return _buildFxTuneTab();
      case 3:
        return _buildFrameTab();
      case 4:
        return _buildFormatTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── TAB 0: Character Ramp & Column Density ───
  Widget _buildCharsetTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ASCII Column Density',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _renderData != null
                    ? '${_renderData!.cols}x${_renderData!.rows} chars'
                    : '${_config.columns} cols',
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
          value: _config.columns.toDouble().clamp(24, 100),
          min: 24,
          max: 100,
          divisions: 19,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _config = _config.copyWith(columns: v.round())),
          onChangeEnd: (_) => _regenerateAscii(),
        ),
        const Text(
          'Character Ramp',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: AsciiCharset.values.map((cs) {
            final bool isSelected = _config.charset == cs;
            return ChoiceChip(
              label: Text(cs.label, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              onSelected: (_) {
                setState(() => _config = _config.copyWith(charset: cs));
                _regenerateAscii();
              },
            );
          }).toList(),
        ),
        if (_config.charset == AsciiCharset.custom) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _customRampController,
            decoration: InputDecoration(
              labelText: 'Custom Characters (Dark → Bright)',
              labelStyle: const TextStyle(fontSize: 11.5),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) {
              setState(() => _config = _config.copyWith(customRampText: v));
              _regenerateAscii();
            },
          ),
        ],
      ],
    );
  }

  // ─── TAB 1: Terminal & Poster Color Themes ───
  Widget _buildColorsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Color Theme',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            FilterChip(
              label: const Text('Invert Polarity', style: TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: _config.invertLuminance,
              selectedColor: AppColors.primarySurface,
              checkmarkColor: AppColors.primary,
              onSelected: (v) {
                setState(() => _config = _config.copyWith(invertLuminance: v));
                _regenerateAscii();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...AsciiColorMode.values.map((mode) {
          final bool isSelected = _config.colorMode == mode;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface.withValues(alpha: 0.45) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode.bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black26),
                ),
                child: Text(
                  '@#',
                  style: TextStyle(
                    color: mode.fgColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              title: Text(
                mode.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18)
                  : null,
              onTap: () {
                setState(() => _config = _config.copyWith(colorMode: mode));
                _regenerateAscii();
              },
            ),
          );
        }),
      ],
    );
  }

  // ─── TAB 2: Shaders, Contrast & Photo Ghost ───
  Widget _buildFxTuneTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactSlider(
          label: 'Contrast',
          valueText: '${(_config.contrast * 100).round()}%',
          value: _config.contrast.clamp(0.6, 2.2),
          min: 0.6,
          max: 2.2,
          onChanged: (v) => setState(() => _config = _config.copyWith(contrast: v)),
          onChangeEnd: (_) => _regenerateAscii(),
        ),
        _buildCompactSlider(
          label: 'Bright',
          valueText: '${(_config.brightness * 100).round()}%',
          value: _config.brightness.clamp(-0.35, 0.35),
          min: -0.35,
          max: 0.35,
          onChanged: (v) => setState(() => _config = _config.copyWith(brightness: v)),
          onChangeEnd: (_) => _regenerateAscii(),
        ),
        _buildCompactSlider(
          label: 'Bg Bleed',
          valueText: _config.photoBgOpacity < 0.02 ? 'Off' : '${(_config.photoBgOpacity * 100).round()}%',
          value: _config.photoBgOpacity.clamp(0.0, 0.40),
          min: 0.0,
          max: 0.40,
          onChanged: (v) => setState(() => _config = _config.copyWith(photoBgOpacity: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Phosphor Text Glow',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          value: _config.enableGlow,
          onChanged: (v) {
            setState(() => _config = _config.copyWith(enableGlow: v));
            _regenerateAscii();
          },
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'CRT Terminal Scanlines',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
          value: _config.crtScanlines,
          onChanged: (v) => setState(() => _config = _config.copyWith(crtScanlines: v)),
        ),
      ],
    );
  }

  Widget _buildCompactSlider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ─── TAB 3: Terminal / Zine Frame & Caption ───
  Widget _buildFrameTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terminal & Poster Frame',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AsciiFrameStyle.values.map((frame) {
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
                setState(() => _config = _config.copyWith(frameStyle: frame));
              },
            );
          }).toList(),
        ),
        if (_config.frameStyle != AsciiFrameStyle.frameless) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _headerTitleController,
            decoration: InputDecoration(
              labelText: 'Terminal / Poster Caption',
              labelStyle: const TextStyle(fontSize: 11.5),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _config = _config.copyWith(headerTitle: v)),
          ),
        ],
      ],
    );
  }

  // ─── TAB 4: Aspect Ratio Format ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Canvas Aspect Ratio',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 8),
        ...AsciiAspectRatio.values.map((ratio) {
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
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18)
                  : null,
              onTap: () {
                setState(() => _config = _config.copyWith(aspectRatio: ratio));
                _regenerateAscii();
              },
            ),
          );
        }),
      ],
    );
  }
}

