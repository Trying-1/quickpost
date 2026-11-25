import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/grid_layout_type.dart';
import 'models/grid_tile.dart';
import 'services/grid_splitter_service.dart';
import 'widgets/grid_layout_selector.dart';
import 'widgets/grid_preview_overlay.dart';
import 'widgets/grid_export_dialog.dart';

/// Full interactive editor screen for splitting images into Instagram profile grids.
class GridPostMakerScreen extends StatefulWidget {
  final String? initialImagePath;

  const GridPostMakerScreen({
    super.key,
    this.initialImagePath,
  });

  @override
  State<GridPostMakerScreen> createState() => _GridPostMakerScreenState();
}

class _GridPostMakerScreenState extends State<GridPostMakerScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imagePath;

  GridLayoutType _selectedLayout = GridLayoutType.banner3x1;
  bool _showGridBadges = true;
  bool _isProcessing = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Grid Post Maker');
    if (widget.initialImagePath != null) {
      _loadInitialImage(widget.initialImagePath!);
    }
  }

  Future<void> _loadInitialImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = path;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = picked.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _handleSplitAndExport() async {
    if (_imageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.1;
      _processingStatus = 'Preparing grid split...';
    });

    try {
      final tiles = await GridSplitterService.splitImage(
        sourceBytes: _imageBytes!,
        layout: _selectedLayout,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _processingProgress = progress;
              _processingStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved ${tiles.length} slices to Gallery (Pictures/Quick Post Grids)'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        GridExportDialog.show(context, tiles);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3-Post Profile Grid Maker',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              'Seamless social profile banner creator',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        actions: [
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _handleSplitAndExport,
                icon: const Icon(Icons.splitscreen_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Split & Save',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ─── Preview Canvas ───
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _imageBytes == null
                        ? _buildEmptyState()
                        : _buildActiveCanvasPreview(),
                  ),
                ),
              ),

              // ─── Bottom Control Dock ───
              _buildBottomControlDock(),
            ],
          ),

          // Processing Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFD81B60)),
                      const SizedBox(height: 16),
                      Text(
                        _processingStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(_processingProgress * 100).toInt()}%',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFD81B60), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select an Image from Gallery',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Landscape, panoramic or wide photos look best for 3-post banners',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCanvasPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _selectedLayout.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // User image
              Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
              ),

              // Grid lines and upload sequence overlay
              GridPreviewOverlay(
                layout: _selectedLayout,
                showBadges: _showGridBadges,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlDock() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar Quick Action Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GRID LAYOUT',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Row(
                  children: [
                    // Change Image pill
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                      label: const Text('Change Photo', style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Toggle Badges pill
                    TextButton.icon(
                      onPressed: () => setState(() => _showGridBadges = !_showGridBadges),
                      icon: Icon(
                        _showGridBadges ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        _showGridBadges ? 'Numbers: ON' : 'Numbers: OFF',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Layout Presets Ribbon
          GridLayoutSelector(
            selectedLayout: _selectedLayout,
            onLayoutSelected: (layout) => setState(() => _selectedLayout = layout),
          ),
        ],
      ),
    );
  }
}

