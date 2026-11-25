import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';

import '../../config/app_theme.dart';
import '../../services/ad_service.dart';
import '../../services/carousel_post_preset_service.dart';
import '../../services/app_review_service.dart';
import 'models/carousel_project.dart';
import 'models/carousel_slide.dart';
import 'models/carousel_custom_layout.dart';
import 'models/carousel_template_theme.dart';
import 'services/carousel_export_service.dart';
import 'widgets/assets/carousel_asset_library_sheet.dart';
import 'widgets/assets/carousel_asset_storage_panel.dart';
import 'widgets/assets/carousel_asset_upload_dialog.dart';
import 'widgets/carousel_json_import_sheet.dart';
import 'widgets/carousel_layouts_panel.dart';
import 'widgets/carousel_slide_preview.dart';
import 'widgets/image_reorder_sheet.dart';
import 'widgets/slide_data_editor.dart';
import 'widgets/slide_position_panel.dart';
import 'widgets/slide_selector_strip.dart';
import 'widgets/theme_styling_panel.dart';

/// Modular coordinator screen for Instagram Carousel Posts (Quotes, Guides, Tips).
/// Built with the authentic Quick Post UI and theme:
/// Light background (Colors.grey[100]), bottom control tabs dock,
/// expandable drawer, and high-resolution sequential export.
class CarouselPostMakerScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final bool isActive;

  const CarouselPostMakerScreen({
    super.key,
    this.sharedImagePaths,
    this.isActive = true,
  });

  @override
  State<CarouselPostMakerScreen> createState() => _CarouselPostMakerScreenState();
}

class _CarouselPostMakerScreenState extends State<CarouselPostMakerScreen> {
  late CarouselProject _project;
  int _activeSlideIndex = 0;
  final GlobalKey _slideRepaintKey = GlobalKey();

  // Control tabs state matching ImagePostMakerScreen
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;
  String? _activeComponentKey = SlideComponentId.title;
  bool _isExporting = false;
  bool _isDraggingCanvas = false;

  @override
  void initState() {
    super.initState();
    _project = CarouselProject.createDefault();
    _applySharedImagesIfAny();
  }

  @override
  void didUpdateWidget(covariant CarouselPostMakerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedImagePaths != null &&
        widget.sharedImagePaths != oldWidget.sharedImagePaths) {
      _applySharedImagesIfAny();
    }
  }

  void _applySharedImagesIfAny() {
    if (widget.sharedImagePaths == null || widget.sharedImagePaths!.isEmpty) return;
    final paths = widget.sharedImagePaths!;
    final updatedSlides = <CarouselSlide>[];
    for (int i = 0; i < _project.slides.length; i++) {
      if (i < paths.length && File(paths[i]).existsSync()) {
        updatedSlides.add(_project.slides[i].copyWith(imagePath: paths[i]));
      } else {
        updatedSlides.add(_project.slides[i]);
      }
    }
    setState(() {
      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  CarouselSlide get _activeSlide => _project.slides[_activeSlideIndex];

  void _onSlideDataChanged(CarouselSlide updatedSlide) {
    setState(() {
      final updatedSlides = List<CarouselSlide>.from(_project.slides);
      updatedSlides[_activeSlideIndex] = updatedSlide;

      // When sync is active and editing a content slide, synchronize positioning offsets across all content slides
      if (_project.theme.syncSlideLayoutAndPosition && updatedSlide.type == SlideType.content) {
        for (int i = 0; i < updatedSlides.length; i++) {
          if (updatedSlides[i].type == SlideType.content && i != _activeSlideIndex) {
            updatedSlides[i] = updatedSlides[i].copyWith(
              contentOffsetX: updatedSlide.contentOffsetX,
              contentOffsetY: updatedSlide.contentOffsetY,
              headerOffsetY: updatedSlide.headerOffsetY,
              componentOffsets: Map<String, Offset>.from(updatedSlide.componentOffsets),
            );
          }
        }
      }

      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  void _onDragComponent(String componentKey, Offset delta) {
    setState(() {
      _activeComponentKey = componentKey;
      final currentOffset = _activeSlide.getComponentOffset(componentKey);
      final newX = (currentOffset.dx + delta.dx).clamp(-180.0, 180.0);
      final newY = (currentOffset.dy + delta.dy).clamp(-350.0, 350.0);

      final updatedSlide = _activeSlide.copyWithComponentOffset(
        componentKey,
        Offset(newX, newY),
      );

      final updatedSlides = List<CarouselSlide>.from(_project.slides);
      updatedSlides[_activeSlideIndex] = updatedSlide;

      // When sync is active and dragging on a content slide, synchronize position to all other content slides
      if (_project.theme.syncSlideLayoutAndPosition && _activeSlide.type == SlideType.content) {
        for (int i = 0; i < updatedSlides.length; i++) {
          if (updatedSlides[i].type == SlideType.content && i != _activeSlideIndex) {
            updatedSlides[i] = updatedSlides[i].copyWithComponentOffset(
              componentKey,
              Offset(newX, newY),
            );
          }
        }
      }

      _project = _project.copyWith(slides: updatedSlides);
    });
  }

  void _onDragContent(Offset delta) {
    _onDragComponent(SlideComponentId.allContent, delta);
  }

  void _onDragHeader(Offset delta) {
    _onDragComponent(SlideComponentId.pageHandle, delta);
  }

  void _onToggleSyncLayoutAndPosition(bool sync) {
    setState(() {
      var updatedProject = _project.copyWith(
        theme: _project.theme.copyWith(syncSlideLayoutAndPosition: sync),
      );
      if (sync && _activeSlide.type == SlideType.content) {
        final activeLayout = _activeSlide.getEffectiveLayout(_project.theme);
        final updatedSlides = updatedProject.slides.map((s) {
          if (s.type == SlideType.content) {
            return s.copyWith(
              contentOffsetX: _activeSlide.contentOffsetX,
              contentOffsetY: _activeSlide.contentOffsetY,
              headerOffsetY: _activeSlide.headerOffsetY,
              componentOffsets: Map<String, Offset>.from(_activeSlide.componentOffsets),
              customLayout: activeLayout,
            );
          }
          return s;
        }).toList();
        updatedProject = updatedProject.copyWith(
          slides: updatedSlides,
          theme: updatedProject.theme.copyWith(slideLayout: activeLayout),
        );
      }
      _project = updatedProject;
    });
    _showToast(
      sync
          ? 'Layout and component positions synced for all slides'
          : 'Independent layout & positioning enabled for each slide',
      isSuccess: true,
    );
  }

  void _applyCustomLayout(CarouselCustomLayout layout) {
    setState(() {
      final updatedSlides = List<CarouselSlide>.from(_project.slides);
      final shouldSync = _project.theme.syncSlideLayoutAndPosition;

      for (int i = 0; i < updatedSlides.length; i++) {
        if (i == _activeSlideIndex || (shouldSync && updatedSlides[i].type == SlideType.content)) {
          updatedSlides[i] = updatedSlides[i].copyWith(
            contentOffsetX: layout.contentOffsetX,
            contentOffsetY: layout.contentOffsetY,
            headerOffsetY: layout.headerOffsetY,
            componentOffsets: Map<String, Offset>.from(layout.componentOffsets),
            customLayout: SlideLayout.defaultLayout,
          );
        }
      }

      final updatedTheme = _project.theme.copyWith(
        slideLayout: SlideLayout.defaultLayout,
        showNumberBadge: layout.showNumberBadge,
        showBodyText: layout.showBodyText,
        showWatermark: layout.showWatermark,
        showSlideCounter: layout.showSlideCounter,
        cardStyle: layout.cardStyle,
        showCardBackdrop: layout.showCardBackdrop,
        rankBadgeStyle: layout.rankBadgeStyle,
        synopsisCardStyle: layout.synopsisCardStyle,
        titleCardStyle: layout.titleCardStyle,
        componentFonts: layout.componentFonts.isNotEmpty ? layout.componentFonts : null,
        componentColors: layout.componentColors.isNotEmpty ? layout.componentColors : null,
      );

      _project = _project.copyWith(slides: updatedSlides, theme: updatedTheme);
    });
    _showToast('Applied "${layout.name}" layout', isSuccess: true);
  }

  void _resetToDefaultLayout() {
    _resetSlidePosition();
    setState(() {
      _project = _project.copyWith(
        theme: _project.theme.copyWith(slideLayout: SlideLayout.defaultLayout),
      );
    });
    _showToast('Reset to Default Layout', isSuccess: true);
  }

  void _applyPositionToAllSlides() {
    setState(() {
      final updatedSlides = _project.slides.map((s) {
        return s.copyWith(
          contentOffsetX: _activeSlide.contentOffsetX,
          contentOffsetY: _activeSlide.contentOffsetY,
          headerOffsetY: _activeSlide.headerOffsetY,
          componentOffsets: Map<String, Offset>.from(_activeSlide.componentOffsets),
        );
      }).toList();
      _project = _project.copyWith(slides: updatedSlides);
    });
    _showToast('Applied component positions to all ${_project.slides.length} slides', isSuccess: true);
  }

  void _resetSlidePosition({String? componentKey}) {
    setState(() {
      final updatedSlide = _activeSlide.copyWithResetOffsets(specificKey: componentKey);
      final updatedSlides = List<CarouselSlide>.from(_project.slides);
      updatedSlides[_activeSlideIndex] = updatedSlide;

      if (_project.theme.syncSlideLayoutAndPosition && _activeSlide.type == SlideType.content) {
        for (int i = 0; i < updatedSlides.length; i++) {
          if (updatedSlides[i].type == SlideType.content && i != _activeSlideIndex) {
            updatedSlides[i] = updatedSlides[i].copyWithResetOffsets(specificKey: componentKey);
          }
        }
      }

      _project = _project.copyWith(slides: updatedSlides);
    });
    if (componentKey != null) {
      _showToast('${SlideComponentId.getLabel(componentKey)} position reset');
    } else {
      _showToast('All positions on this slide reset to default');
    }
  }

  void _onThemeChanged(CarouselTemplateTheme updatedTheme) {
    setState(() {
      _project = _project.copyWith(theme: updatedTheme);
    });
  }

  void _onSelectSlide(int index) {
    if (index >= 0 && index < _project.slides.length) {
      setState(() => _activeSlideIndex = index);
    }
  }

  void _onAddContentSlide() {
    setState(() {
      final contentCount = _project.slides.where((s) => s.type == SlideType.content).length;
      final newNumber = contentCount + 1;
      final newSlide = CarouselSlide(
        id: 'slide_content_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.content,
        slideNumber: newNumber,
        title: 'New Principle #$newNumber',
        bodyText: 'Enter your actionable insight, quotation, or guidance for this slide.',
      );

      final updated = List<CarouselSlide>.from(_project.slides);
      final ctaIndex = updated.indexWhere((s) => s.type == SlideType.cta);
      if (ctaIndex != -1) {
        updated.insert(ctaIndex, newSlide);
      } else {
        updated.add(newSlide);
      }
      _project = _project.copyWith(slides: updated);
      _activeSlideIndex = ctaIndex != -1 ? ctaIndex : updated.length - 1;
    });
    _showToast('Added Slide ${_activeSlideIndex + 1}', isSuccess: true);
  }

  void _onDeleteSlide(int index) {
    if (index < 0 || index >= _project.slides.length) return;
    final slide = _project.slides[index];
    if (slide.type == SlideType.cover) {
      _showToast('Cover slide cannot be deleted');
      return;
    }
    if (slide.type == SlideType.cta) {
      _showToast('CTA Outro slide cannot be deleted');
      return;
    }

    setState(() {
      final updated = List<CarouselSlide>.from(_project.slides);
      updated.removeAt(index);

      // Re-number remaining content slides
      int count = 1;
      for (int i = 0; i < updated.length; i++) {
        if (updated[i].type == SlideType.content) {
          updated[i] = updated[i].copyWith(
            slideNumber: count,
          );
          count++;
        }
      }

      _project = _project.copyWith(slides: updated);
      if (_activeSlideIndex >= updated.length) {
        _activeSlideIndex = updated.length - 1;
      }
    });
    _showToast('Deleted slide');
  }

  Future<void> _pickImageForActiveSlide() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (picked != null) {
        _onSlideDataChanged(_activeSlide.copyWith(imagePath: picked.path));
      }
    } catch (e) {
      _showToast('Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _pickBulkImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (pickedFiles.isEmpty) return;

      setState(() {
        final updatedSlides = List<CarouselSlide>.from(_project.slides);

        for (int i = 0; i < pickedFiles.length; i++) {
          final file = pickedFiles[i];
          if (i < updatedSlides.length) {
            updatedSlides[i] = updatedSlides[i].copyWith(imagePath: file.path);
          } else {
            final contentCount = updatedSlides.where((s) => s.type == SlideType.content).length;
            final newNumber = contentCount + 1;
            final newSlide = CarouselSlide(
              id: 'slide_${DateTime.now().millisecondsSinceEpoch}_$i',
              type: SlideType.content,
              slideNumber: newNumber,
              bgImagePath: file.path,
              title: 'New Principle #$newNumber',
              bodyText: 'Enter your actionable insight for this slide.',
            );
            final ctaIndex = updatedSlides.indexWhere((s) => s.type == SlideType.cta);
            if (ctaIndex != -1) {
              updatedSlides.insert(ctaIndex, newSlide);
            } else {
              updatedSlides.add(newSlide);
            }
          }
        }

        _project = _project.copyWith(slides: updatedSlides);
      });

      _showToast('Assigned ${pickedFiles.length} images to slides!', isSuccess: true);
    } catch (e) {
      _showToast('Bulk import failed: $e', isError: true);
    }
  }

  void _showImageReorderSheet() {
    ImageReorderSheet.show(
      context: context,
      slides: _project.slides,
      onApplyReorderedImages: (newPaths) {
        setState(() {
          final updated = List<CarouselSlide>.from(_project.slides);
          for (int i = 0; i < updated.length && i < newPaths.length; i++) {
            if (newPaths[i] == null) {
              updated[i] = updated[i].copyWith(clearImagePath: true);
            } else {
              updated[i] = updated[i].copyWith(imagePath: newPaths[i]);
            }
          }
          _project = _project.copyWith(slides: updated);
        });
        _showToast('Images rearranged successfully!', isSuccess: true);
      },
    );
  }

  void _swapSlideImages(int indexA, int indexB) {
    if (indexA < 0 || indexA >= _project.slides.length || indexB < 0 || indexB >= _project.slides.length) return;
    setState(() {
      final updated = List<CarouselSlide>.from(_project.slides);
      final pathA = updated[indexA].imagePath;
      final pathB = updated[indexB].imagePath;

      updated[indexA] = pathB != null
          ? updated[indexA].copyWith(imagePath: pathB)
          : updated[indexA].copyWith(clearImagePath: true);
      updated[indexB] = pathA != null
          ? updated[indexB].copyWith(imagePath: pathA)
          : updated[indexB].copyWith(clearImagePath: true);

      _project = _project.copyWith(slides: updated);
    });
    _showToast('Swapped images between Slide ${indexA + 1} and ${indexB + 1}!', isSuccess: true);
  }

  void _showJsonImportSheet() {
    CarouselJsonImportSheet.show(
      context: context,
      currentProject: _project,
      onProjectImported: (imported) {
        setState(() {
          _project = imported;
          _activeSlideIndex = 0;
        });
      },
      onShowToast: (msg) => _showToast(msg),
    );
  }

  Future<void> _openAssetLibrary() async {
    final selected = await CarouselAssetLibrarySheet.show(context);
    if (selected != null && selected.isNotEmpty) {
      _onSlideDataChanged(_activeSlide.copyWith(imagePath: selected));
      _showToast('Applied image to Slide ${_activeSlideIndex + 1}', isSuccess: true);
    }
  }

  Future<void> _exportCarousel() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _activeComponentKey = null;
    });

    String currentStatus = 'Preparing export...';
    int currentProgress = 0;
    int totalCount = _project.slides.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Exporting Carousel Post ($currentProgress / $totalCount)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                currentStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final exportedPaths = await CarouselExportService.exportAllSlides(
        project: _project,
        repaintKey: _slideRepaintKey,
        onSwitchSlide: (idx) async {
          setState(() => _activeSlideIndex = idx);
        },
        onProgress: (current, total, status) {
          currentProgress = current;
          totalCount = total;
          currentStatus = status;
        },
      );

      if (mounted) Navigator.pop(context); // Close progress dialog

      _showToast('Exported ${exportedPaths.length} slides to Quick Post Carousel!', isSuccess: true);
      AppReviewService().requestReview();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportSingleSlide() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _activeComponentKey = null;
    });

    try {
      final path = await CarouselExportService.exportSingleSlide(
        project: _project,
        slideIndex: _activeSlideIndex,
        repaintKey: _slideRepaintKey,
      );
      if (path != null) {
        _showToast('Slide ${_activeSlideIndex + 1} exported to gallery!', isSuccess: true);
      }
    } catch (e) {
      _showToast('Export single slide failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reset Carousel?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will reset all slides and template styles back to default "5 Mindset Shifts for Success".',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _project = CarouselProject.createDefault();
                _activeSlideIndex = 0;
              });
              _showToast('Project reset to default template');
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    toastification.show(
      context: context,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      type: isError
          ? ToastificationType.error
          : (isSuccess ? ToastificationType.success : ToastificationType.info),
      style: ToastificationStyle.fillColored,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _project.theme;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Live Interactive Preview Canvas
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: _isDraggingCanvas
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: CarouselSlidePreview(
                    repaintKey: _slideRepaintKey,
                    slide: _activeSlide,
                    theme: theme,
                    slideIndex: _activeSlideIndex,
                    totalSlides: _project.slides.length,
                    isInteractive: !_isExporting,
                    activeComponentKey: _isExporting ? null : _activeComponentKey,
                    onSelectComponent: (key) => setState(() => _activeComponentKey = key),
                    onDragComponent: _onDragComponent,
                    onDragContent: _onDragContent,
                    onDragHeader: _onDragHeader,
                    onDragStart: () => setState(() => _isDraggingCanvas = true),
                    onDragEnd: () => setState(() => _isDraggingCanvas = false),
                    onTapCanvas: () {
                      if (_activeComponentKey != null) {
                        setState(() => _activeComponentKey = null);
                      }
                    },
                  ),
                ),
              ),
            ),

            // 2. Slide Selector Strip (Ribbon of slides + Add Slide button)
            SlideSelectorStrip(
              slides: _project.slides,
              activeIndex: _activeSlideIndex,
              theme: theme,
              onSelectSlide: _onSelectSlide,
              onAddContentSlide: _onAddContentSlide,
              onDeleteSlide: _onDeleteSlide,
            ),

            // 3. Bottom Controls Section
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isTabContentExpanded)
            Container(
              height: 230,
              color: Colors.white,
              child: _buildActiveTabContent(),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildControlTabs() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton.icon(
              onPressed: _exportCarousel,
              icon: const Icon(Icons.file_download_rounded, size: 16),
              label: const Text('Export All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(11, Icons.auto_awesome, 'AI JSON', Colors.purple, customOnTap: _showJsonImportSheet),
                _buildTabItem(0, Icons.edit_note, 'Content', Colors.indigo),
                _buildTabItem(1, Icons.photo_library, 'Image', AppColors.primary),
                _buildTabItem(14, Icons.collections_bookmark_rounded, 'Assets', Colors.teal),
                _buildTabItem(2, Icons.dashboard_customize_rounded, 'Layouts', Colors.purple),
                _buildTabItem(3, Icons.view_quilt_rounded, 'Elements', Colors.teal),
                _buildTabItem(4, Icons.open_with_rounded, 'Position', Colors.blue),
                _buildTabItem(12, Icons.font_download_rounded, 'Fonts', Colors.deepPurple),
                _buildTabItem(13, Icons.palette_rounded, 'Colors', Colors.pinkAccent),
                _buildTabItem(5, Icons.style_rounded, 'Styles', Colors.deepOrange),
                _buildTabItem(6, Icons.branding_watermark_rounded, 'Branding', Colors.amber),
                _buildTabItem(7, Icons.aspect_ratio_rounded, 'Canvas', AppColors.primary),
                _buildTabItem(9, Icons.image_outlined, 'Exp Slide', Colors.blueGrey, customOnTap: _exportSingleSlide),
                _buildTabItem(10, Icons.refresh_rounded, 'Reset', Colors.redAccent, customOnTap: _resetToDefault),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    IconData icon,
    String label,
    Color accent, {
    VoidCallback? customOnTap,
  }) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
        if (customOnTap != null) {
          customOnTap();
          return;
        }
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
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accent : Colors.grey.shade600,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? accent : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return SlideDataEditor(
          slide: _activeSlide,
          slideIndex: _activeSlideIndex,
          allSlides: _project.slides,
          theme: _project.theme,
          onSlideChanged: _onSlideDataChanged,
          onBulkImportImages: _pickBulkImages,
          onRearrangeImages: _showImageReorderSheet,
          onSwapWithSlide: (targetIdx) => _swapSlideImages(_activeSlideIndex, targetIdx),
          onOpenAiImportSheet: _showJsonImportSheet,
        );

      case 1:
        return _buildImageTabContent();

      case 14:
        return CarouselAssetStoragePanel(
          activeSlide: _activeSlide,
          onSelectImage: (path) {
            _onSlideDataChanged(_activeSlide.copyWith(imagePath: path));
            _showToast('Applied image to Slide ${_activeSlideIndex + 1}', isSuccess: true);
          },
          onOpenFullLibrary: _openAssetLibrary,
          onShowToast: (msg, {isError = false, isSuccess = false}) =>
              _showToast(msg, isError: isError, isSuccess: isSuccess),
        );

      case 2:
        return CarouselLayoutsPanel(
          activeSlide: _activeSlide,
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          onApplyLayout: _applyCustomLayout,
          onResetToDefault: _resetToDefaultLayout,
          onToggleSync: _onToggleSyncLayoutAndPosition,
          onShowToast: (msg) => _showToast(msg),
        );

      case 3:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.components,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 4:
        return SlidePositionPanel(
          slide: _activeSlide,
          theme: _project.theme,
          activeComponentKey: _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          onSlideChanged: _onSlideDataChanged,
          onApplyToAll: _applyPositionToAllSlides,
          onReset: () => _resetSlidePosition(),
          onResetComponent: (key) => _resetSlidePosition(componentKey: key),
          syncSlideLayoutAndPosition: _project.theme.syncSlideLayoutAndPosition,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 5:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.styles,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 12:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.fonts,
          activeSlide: _activeSlide,
          activeComponentKey: _isExporting ? null : _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 13:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.colors,
          activeSlide: _activeSlide,
          activeComponentKey: _isExporting ? null : _activeComponentKey,
          onSelectComponent: (key) => setState(() => _activeComponentKey = key),
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 6:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.branding,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      case 7:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.canvas,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );

      default:
        return ThemeStylingPanel(
          theme: _project.theme,
          onThemeChanged: _onThemeChanged,
          section: StylingSection.all,
          activeSlide: _activeSlide,
          onToggleSync: _onToggleSyncLayoutAndPosition,
        );
    }
  }

  Widget _buildImageTabContent() {
    final hasImage = _activeSlide.imagePath != null && File(_activeSlide.imagePath!).existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey.shade200,
                    child: hasImage
                        ? Image.file(File(_activeSlide.imagePath!), fit: BoxFit.cover)
                        : const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasImage ? 'Image Selected' : 'No Image Assigned',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Slide ${_activeSlideIndex + 1} (${_activeSlide.type.name})',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (hasImage)
                  TextButton(
                    onPressed: () {
                      _onSlideDataChanged(_activeSlide.copyWith(clearImagePath: true));
                      _showToast('Image removed from Slide ${_activeSlideIndex + 1}');
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ElevatedButton.icon(
                  onPressed: _pickImageForActiveSlide,
                  icon: const Icon(Icons.photo_library_rounded, size: 14),
                  label: const Text('Change', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Slide Image Blur: ${_activeSlide.bgBlur.toStringAsFixed(1)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Slider(
            value: _activeSlide.bgBlur.clamp(0.0, 10.0),
            min: 0.0,
            max: 10.0,
            activeColor: AppColors.primary,
            onChanged: (val) {
              _onSlideDataChanged(_activeSlide.copyWith(bgBlur: val));
            },
          ),
        ],
      ),
    );
  }
}

