import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/color_palette_item.dart';
import 'models/curated_palettes_data.dart';
import 'models/palette_color.dart';
import 'services/color_extractor_service.dart';
import 'widgets/color_picker_dialog.dart';
import 'widgets/image_extractor_view.dart';
import 'widgets/palette_contrast_view.dart';
import 'widgets/palette_export_sheet.dart';
import 'widgets/palette_swatch_card.dart';

/// Full-featured Color Palette Studio:
/// - Image Palette Extraction with real-time magnifying loupe eyedropper
/// - Custom Palette Creator with HEX / HSV / RGB tuning and locking
/// - Color Theory Harmony Generator (Complementary, Analogous, Triadic, Monochromatic)
/// - WCAG 2.1 Contrast Testing with live social post preview card
/// - 35+ Curated Creator Palettes
/// - High-resolution 4K swatch card rendering & MediaStore gallery export
class ColorPaletteScreen extends StatefulWidget {
  final ColorPaletteItem? initialPalette;

  const ColorPaletteScreen({super.key, this.initialPalette});

  @override
  State<ColorPaletteScreen> createState() => _ColorPaletteScreenState();
}

class _ColorPaletteScreenState extends State<ColorPaletteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ColorPaletteItem _currentPalette;
  File? _sourceImageFile;
  HarmonyType _selectedHarmony = HarmonyType.analogous;

  final List<String> _tabs = [
    'Extract from Image',
    'Palette Studio',
    'Harmonies',
    'Contrast & Test',
    'Curated 35+',
  ];

  final List<IconData> _tabIcons = [
    Icons.add_photo_alternate_rounded,
    Icons.palette_rounded,
    Icons.auto_awesome_rounded,
    Icons.remove_red_eye_rounded,
    Icons.grid_view_rounded,
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Color Palette Studio');
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: 1);

    _currentPalette = widget.initialPalette ?? CuratedPalettesData.getAll().first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Image Extraction Handlers ───

  Future<void> _pickImage() async {
    final file = await ColorExtractorService().pickImage();
    if (file != null && mounted) {
      setState(() {
        _sourceImageFile = file;
      });
      // Switch to Image Extraction Tab to see the interactive loupe
      _tabController.animateTo(0);
    }
  }

  void _onPaletteExtractedFromImage(ColorPaletteItem item) {
    setState(() {
      _currentPalette = item;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${item.colors.length} extracted colors from photo!'),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onSampledFromLoupe(PaletteColor color) {
    setState(() {
      _currentPalette = _currentPalette.copyWith(
        colors: [..._currentPalette.colors, color],
      );
    });
  }

  // ─── Palette Manipulation ───

  void _shuffleUnlockedColors() {
    final random = math.Random();
    final updatedColors = _currentPalette.colors.map((c) {
      if (c.isLocked) return c;
      final hue = random.nextDouble() * 360;
      final sat = 0.45 + (random.nextDouble() * 0.5);
      final val = 0.35 + (random.nextDouble() * 0.6);
      final newColor = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
      return PaletteColor(
        color: newColor,
        name: PaletteColor.findNearestName(newColor),
        role: c.role,
        isLocked: false,
      );
    }).toList();

    setState(() {
      _currentPalette = _currentPalette.copyWith(
        title: 'Dynamic Harmony',
        category: 'Generated',
        colors: updatedColors,
      );
    });
  }

  void _addNewColor() {
    ColorPickerDialog.show(
      context,
      initial: const PaletteColor(
        color: Color(0xFF00E5FF),
        name: 'Electric Cyan',
        role: 'Accent',
      ),
      onSaved: (newColor) {
        setState(() {
          _currentPalette = _currentPalette.copyWith(
            colors: [..._currentPalette.colors, newColor],
          );
        });
      },
    );
  }

  void _editColor(int index) {
    ColorPickerDialog.show(
      context,
      initial: _currentPalette.colors[index],
      onSaved: (updated) {
        final newColors = List<PaletteColor>.from(_currentPalette.colors);
        newColors[index] = updated;
        setState(() {
          _currentPalette = _currentPalette.copyWith(colors: newColors);
        });
      },
    );
  }

  void _toggleLock(int index) {
    final newColors = List<PaletteColor>.from(_currentPalette.colors);
    newColors[index] = newColors[index].copyWith(isLocked: !newColors[index].isLocked);
    setState(() {
      _currentPalette = _currentPalette.copyWith(colors: newColors);
    });
  }

  void _deleteColor(int index) {
    if (_currentPalette.colors.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A palette must have at least 2 colors.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final newColors = List<PaletteColor>.from(_currentPalette.colors)..removeAt(index);
    setState(() {
      _currentPalette = _currentPalette.copyWith(colors: newColors);
    });
  }

  void _applyHarmony(HarmonyType type) {
    final base = _currentPalette.colors.isNotEmpty ? _currentPalette.colors.first.color : const Color(0xFF2563EB);
    final generated = ColorExtractorService().generateHarmonies(base, type);

    setState(() {
      _selectedHarmony = type;
      _currentPalette = _currentPalette.copyWith(
        title: '${type.label} Palette',
        category: 'Color Theory',
        colors: generated,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${type.label} harmonic color scheme!'),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openExportSheet() {
    PaletteExportSheet.show(
      context,
      palette: _currentPalette,
      sourceImageFile: _sourceImageFile,
    );
  }

  void _promptRenamePalette() {
    final controller = TextEditingController(text: _currentPalette.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Palette', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins'),
          decoration: InputDecoration(
            hintText: 'Enter palette title',
            hintStyle: const TextStyle(color: AppColors.textHint, fontFamily: 'Poppins'),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _currentPalette = _currentPalette.copyWith(title: newTitle);
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Color Palette Studio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Pick image to extract palette',
            icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
            onPressed: _pickImage,
          ),
          IconButton(
            tooltip: 'Export palette card',
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            onPressed: _openExportSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Palette Ribbon & Metadata Header
          _buildPaletteSummaryHeader(),

          // Horizontal Scrollable Tab Bar
          _buildControlTabBar(),

          // Main Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: Extract from Image
                ImageExtractorView(
                  imageFile: _sourceImageFile,
                  onPaletteExtracted: _onPaletteExtractedFromImage,
                  onColorSampled: _onSampledFromLoupe,
                  onPickNewImage: _pickImage,
                ),

                // Tab 1: Palette Studio / Swatches
                _buildStudioSwatchesTab(),

                // Tab 2: Harmonies
                _buildHarmoniesTab(),

                // Tab 3: Contrast & Test
                PaletteContrastView(palette: _currentPalette),

                // Tab 4: Curated 35+
                _buildCuratedTab(),
              ],
            ),
          ),

          // Bottom Sticky Action Dock
          _buildBottomActionDock(),
        ],
      ),
    );
  }

  // ─── Header: Active Palette Swatch Strip ───

  Widget _buildPaletteSummaryHeader() {
    final colors = _currentPalette.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _promptRenamePalette,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _currentPalette.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded, color: AppColors.textHint, size: 14),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${colors.length} SHADES',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Seamless Swatch Color Strip
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 24,
              child: Row(
                children: colors.map((c) {
                  return Expanded(
                    child: Container(
                      color: c.color,
                      alignment: Alignment.center,
                      child: c.isLocked
                          ? Icon(Icons.lock_rounded, size: 10, color: c.onColor.withOpacity(0.8))
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Control Tab Bar ───

  Widget _buildControlTabBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, fontFamily: 'Poppins'),
        tabs: List.generate(_tabs.length, (i) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_tabIcons[i], size: 16),
                const SizedBox(width: 6),
                Text(_tabs[i]),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Studio Swatches Tab ───

  Widget _buildStudioSwatchesTab() {
    final colors = _currentPalette.colors;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        return PaletteSwatchCard(
          item: colors[index],
          index: index,
          onEdit: () => _editColor(index),
          onToggleLock: () => _toggleLock(index),
          onDelete: colors.length > 2 ? () => _deleteColor(index) : null,
        );
      },
    );
  }

  // ─── Harmonies Tab ───

  Widget _buildHarmoniesTab() {
    final baseColor = _currentPalette.colors.isNotEmpty
        ? _currentPalette.colors.first.color
        : const Color(0xFF2563EB);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Base Color Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(color: baseColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BASE ANCHOR COLOR',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        PaletteColor.findNearestName(baseColor),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Poppins'),
                      ),
                      Text(
                        '#${baseColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: const TextStyle(color: AppColors.primary, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _editColor(0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primaryLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'COLOR THEORY HARMONIES',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 10),

          // List of Harmony Types
          ...HarmonyType.values.map((type) {
            final isSelected = type == _selectedHarmony;
            final previewColors = ColorExtractorService().generateHarmonies(baseColor, type);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            type.description,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => _applyHarmony(type),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primary : AppColors.primarySurface,
                          foregroundColor: isSelected ? Colors.white : AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          isSelected ? 'Active' : 'Apply',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Uniform 5-swatch palette row
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: previewColors.map((c) {
                          return Expanded(
                            child: Tooltip(
                              message: '${c.name} (${c.hexCode})',
                              child: Container(
                                color: c.color,
                                alignment: Alignment.center,
                                child: Text(
                                  c.hexCode.substring(1),
                                  style: TextStyle(
                                    color: c.onColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Curated 35+ Palettes Tab ───

  Widget _buildCuratedTab() {
    final curatedList = CuratedPalettesData.getAll();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      itemCount: curatedList.length,
      itemBuilder: (context, index) {
        final item = curatedList[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                      ),
                      Text(
                        item.category.toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentPalette = item;
                      });
                      _tabController.animateTo(1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Loaded "${item.title}" into studio!'),
                          backgroundColor: AppColors.primaryDark,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySurface,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Load into Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Poppins')),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Swatch bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 38,
                  child: Row(
                    children: item.colors.map((c) {
                      return Expanded(
                        child: Container(
                          color: c.color,
                          alignment: Alignment.center,
                          child: Text(
                            c.hexCode.substring(1),
                            style: TextStyle(
                              color: c.onColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Bottom Sticky Action Dock ───

  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Shuffle Unlocked Colors
            IconButton(
              tooltip: 'Shuffle unlocked colors',
              onPressed: _shuffleUnlockedColors,
              icon: const Icon(Icons.casino_rounded, color: AppColors.primary, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),

            // Add Color Button
            IconButton(
              tooltip: 'Add new color shade',
              onPressed: _addNewColor,
              icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 10),

            // Primary 1-Tap Export Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openExportSheet,
                icon: const Icon(Icons.palette_rounded, size: 18),
                label: const Text(
                  'Export Palette as Image',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
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

