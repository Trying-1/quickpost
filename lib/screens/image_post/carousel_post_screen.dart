import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/quote_item.dart';
import '../../services/analytics_service.dart';
import '../../utils/background_remover.dart';
import '../../utils/font_selector.dart';
import '../../widgets/advanced_color_picker.dart';
import '../background_remover/background_remover_screen.dart';
import '../quotes/my_quotes_screen.dart';
import 'carousel_post/models/carousel_slide.dart';
import 'carousel_post/services/carousel_export_service.dart';
import 'carousel_post/widgets/carousel_eyedropper_overlay.dart';
import 'carousel_post/widgets/carousel_shared_controls.dart';
import 'carousel_post/widgets/carousel_slide_canvas.dart';
import 'carousel_post/widgets/tabs/carousel_effects_tab.dart';
import 'carousel_post/widgets/tabs/carousel_font_tab.dart';
import 'carousel_post/widgets/tabs/carousel_image_tab.dart';
import 'carousel_post/widgets/tabs/carousel_mask_tab.dart';
import 'carousel_post/widgets/tabs/carousel_position_tab.dart';
import 'carousel_post/widgets/tabs/carousel_style_tab.dart';
import 'carousel_post/widgets/tabs/carousel_text_tab.dart';

class CarouselPostScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const CarouselPostScreen({
    super.key,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<CarouselPostScreen> createState() => _CarouselPostScreenState();
}

class _CarouselPostScreenState extends State<CarouselPostScreen> {
  final List<CarouselSlide> _slides = [CarouselSlide()];
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  FontInfo? _selectedFont;
  int _selectedAspectIndex = 0; // 0: 4:5

  int _selectedTabIndex =
      0; // 0: Image, 1: Text, 2: Position, 3: Font, 4: Effects, 5: Mask, 6: Style, 7: Config
  bool _isTabContentExpanded = true;
  bool _applyMaskToAll = false;
  Set<int> _selectedWordIndices = {}; // Multiple words selection
  bool _multiSelectMode = false;

  double? _snapLineX;
  double? _snapLineY;

  // Eye Dropper State
  bool _isEyeDropperMode = false;
  ByteData? _eyeDropperByteData;
  int? _eyeDropperImageWidth;
  int? _eyeDropperImageHeight;
  Offset? _eyeDropperPos;
  Color _eyeDropperColor = Colors.transparent;
  String _eyeDropperTarget = 'text'; // 'text', 'bg', 'shadow', 'mask'
  bool _isRemovingBg = false;
  bool _editFgAdjustments = false;

  // Track preview dimensions for precise coordinate mapping
  double _lastPreviewWidth = 360;
  double _lastPreviewHeight = 450;

  double get _currentAspectRatio {
    switch (_selectedAspectIndex) {
      case 1:
        return 1 / 1;
      case 2:
        return 9 / 16;
      case 3:
        return 16 / 9;
      case 0:
      default:
        return 4 / 5;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFont = FontInfo.availableFonts.firstWhere(
      (f) => f.family == 'Poppins' && f.weight == FontWeight.bold,
      orElse: () => FontInfo.availableFonts.first,
    );
    if (widget.sharedImagePaths != null &&
        widget.sharedImagePaths!.isNotEmpty) {
      for (final path in widget.sharedImagePaths!) {
        _slides.add(CarouselSlide()..image = File(path));
      }
    }
    AnalyticsService().setCurrentScreen(screenName: 'Carousel Post');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _addSlide() {
    if (_slides.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 slides allowed')),
      );
      return;
    }
    setState(() {
      _slides.add(CarouselSlide());
      _selectedWordIndices.clear();
    });
    // Scroll to new slide
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _slides.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _importFromMyQuotes() async {
    final dynamic selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyQuotesScreen(selectMode: true),
      ),
    );

    if (selected != null && selected is QuoteItem) {
      setState(() {
        _slides[_currentIndex].text = selected.text;
      });
    }
  }

  void _removeSlide(int index) {
    if (_slides.length <= 1) return;
    setState(() {
      _slides.removeAt(index);
      _selectedWordIndices.clear();
      if (_currentIndex >= _slides.length) {
        _currentIndex = _slides.length - 1;
      }
    });
  }

  Future<void> _pickImageForCurrentSlide() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _slides[_currentIndex].image = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          // If we currently only have 1 empty slide, replace it.
          if (_slides.length == 1 &&
              _slides[0].image == null &&
              _slides[0].text.isEmpty) {
            _slides.clear();
          }

          for (var img in images) {
            if (_slides.length < 10) {
              _slides.add(CarouselSlide()..image = File(img.path));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Maximum 10 slides allowed. Some dropped.',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.red),
              );
              break;
            }
          }

          if (_slides.isEmpty) {
            _slides.add(CarouselSlide());
          } // safety
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_pageController.hasClients) {
            if (mounted) {
              setState(() => _selectedWordIndices.clear());
            }
            _pageController.animateToPage(
              _slides.length - 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  Future<String> _resolveFontPath(FontInfo? font) async {
    final f = font ?? _selectedFont ?? FontInfo.availableFonts.first;
    return await FontInfo.getFontFilePath(f);
  }

  Alignment _resolveSnapping(Alignment current, List<Alignment> targets) {
    const double threshold = 0.05;
    double newX = current.x;
    double newY = current.y;
    _snapLineX = null;
    _snapLineY = null;

    // Center snapping (0,0)
    if (current.x.abs() < threshold) {
      newX = 0.0;
      _snapLineX = 0.0;
    }
    if (current.y.abs() < threshold) {
      newY = 0.0;
      _snapLineY = 0.0;
    }

    // Other elements snapping
    for (final target in targets) {
      if ((current.x - target.x).abs() < threshold) {
        newX = target.x;
        _snapLineX = target.x;
      }
      if ((current.y - target.y).abs() < threshold) {
        newY = target.y;
        _snapLineY = target.y;
      }
    }

    return Alignment(newX, newY);
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _exportAllSlides() => CarouselExportService.exportImages(
        context: context,
        slides: _slides,
        pageController: _pageController,
        originalIndex: _currentIndex,
        onClearSelection: () => setState(() => _selectedWordIndices.clear()),
        onJumpSlideIndex: (idx) => setState(() => _currentIndex = idx),
      );

  Future<void> _removeBackgroundForSlide(int index) async {
    final slide = _slides[index];
    if (slide.image == null) return;

    setState(() => _isRemovingBg = true);
    
    try {
      final resultPath = await BackgroundRemover.removeBackground(
        slide.image!.path,
        autoTrim: false, // keep original position
        smoothing: slide.feathering,
      );
      
      if (resultPath != null && mounted) {
        setState(() {
          slide.foregroundImage = File(resultPath);
          _loadUiImageForSlide(slide);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove background.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing background: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemovingBg = false);
      }
    }
  }

  Future<void> _editForegroundCutout(int index) async {
    final slide = _slides[index];
    if (slide.image == null) return;

    final File? editedFile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackgroundRemoverScreen(
          imageFile: slide.image!,
          isEditorMode: true,
          initialSmoothing: slide.feathering,
        ),
      ),
    );

    if (editedFile != null && mounted) {
      setState(() {
        slide.foregroundImage = editedFile;
        _loadUiImageForSlide(slide);
      });
    }
  }

  Future<void> _startEyeDropper(String target) async {
    final slide = _slides[_currentIndex];
    final boundary = slide.previewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    // Capture the current view
    final image = await boundary.toImage(
        pixelRatio: 2.0); // Higher ratio for better precision
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) return;

    if (!mounted) return;
    setState(() {
      _isEyeDropperMode = true;
      _eyeDropperTarget = target;
      _eyeDropperByteData = byteData;
      _eyeDropperImageWidth = image.width;
      _eyeDropperImageHeight = image.height;
      _eyeDropperPos = null;
    });
  }

  void _pickColorAt(Offset localPos, Size widgetSize) {
    if (_eyeDropperByteData == null ||
        _eyeDropperImageWidth == null ||
        _eyeDropperImageHeight == null) return;

    // Map localPos (0..widgetSize) to image pixels (0..imageWidth)
    final double xFactor = _eyeDropperImageWidth! / widgetSize.width;
    final double yFactor = _eyeDropperImageHeight! / widgetSize.height;

    final int px =
        (localPos.dx * xFactor).round().clamp(0, _eyeDropperImageWidth! - 1);
    final int py =
        (localPos.dy * yFactor).round().clamp(0, _eyeDropperImageHeight! - 1);

    final int offset = (py * _eyeDropperImageWidth! + px) * 4;
    if (offset + 3 >= _eyeDropperByteData!.lengthInBytes) return;

    final int r = _eyeDropperByteData!.getUint8(offset);
    final int g = _eyeDropperByteData!.getUint8(offset + 1);
    final int b = _eyeDropperByteData!.getUint8(offset + 2);
    final int a = _eyeDropperByteData!.getUint8(offset + 3);

    final Color picked = Color.fromARGB(a, r, g, b);

    setState(() {
      _eyeDropperPos = localPos;
      _eyeDropperColor = picked;

      // Reactive update
      final slide = _slides[_currentIndex];
      final bool wordMode =
          slide.useWordMode && _selectedWordIndices.isNotEmpty;

      if (_eyeDropperTarget == 'bg') {
        slide.bgColor = picked;
      } else if (_eyeDropperTarget == 'mask') {
        if (_applyMaskToAll) {
          for (var s in _slides) s.maskColor = picked;
        } else {
          slide.maskColor = picked;
        }
      } else if (_eyeDropperTarget == 'shadow') {
        if (wordMode) {
          for (int idx in _selectedWordIndices) {
            slide.wordTokens[idx].shadowColor = picked;
          }
        } else {
          slide.shadowColor = picked;
        }
      } else {
        if (wordMode) {
          for (int idx in _selectedWordIndices) {
            slide.wordTokens[idx].color = picked;
          }
        } else {
          slide.textColor = picked;
        }
      }
    });
  }

  Future<void> _exportAsVideo() => CarouselExportService.exportVideo(
        context: context,
        slides: _slides,
        pageController: _pageController,
        originalIndex: _currentIndex,
        onClearSelection: () => setState(() => _selectedWordIndices.clear()),
        onJumpSlideIndex: (idx) => setState(() => _currentIndex = idx),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _slides.length,
                                onPageChanged: (idx) {
                                  setState(() {
                                    _currentIndex = idx;
                                    _selectedWordIndices.clear();
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return Center(
                                    child: AspectRatio(
                                      aspectRatio: _currentAspectRatio,
                                      child: _buildSlideWidget(
                                          _slides[index], false),
                                    ),
                                  );
                                },
                              ),
                              CarouselEyeDropperOverlay(
                                visible: _isEyeDropperMode,
                                indicatorPosition: _eyeDropperPos,
                                pickedColor: _eyeDropperColor,
                                onPick: _pickColorAt,
                                onDone: () =>
                                    setState(() => _isEyeDropperMode = false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity != null) {
                              if (details.primaryVelocity! < -300) {
                                _goToNext();
                              } else if (details.primaryVelocity! > 300) {
                                _goToPrevious();
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: _buildDotsIndicator(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildControlsSection(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUiImageForSlide(CarouselSlide slide) async {
    if (slide.foregroundImage == null) return;
    try {
      final bytes = await slide.foregroundImage!.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          slide.uiForegroundImage = image;
        });
      }
    } catch (e) {
      debugPrint("Failed to load ui.Image: $e");
    }
  }

  Widget _buildSlideWidget(CarouselSlide slide, bool isExport) {
    return CarouselSlideCanvas(
      slide: slide,
      isExport: isExport,
      defaultFont: _selectedFont,
      selectedWordIndices: _selectedWordIndices,
      multiSelectMode: _multiSelectMode,
      snapLineX: _snapLineX,
      snapLineY: _snapLineY,
      onClearSelection: () => setState(() => _selectedWordIndices.clear()),
      onTapWord: (i) {
        setState(() {
          if (_multiSelectMode) {
            if (_selectedWordIndices.contains(i)) {
              _selectedWordIndices.remove(i);
            } else {
              _selectedWordIndices.add(i);
            }
          } else {
            if (_selectedWordIndices.contains(i) &&
                _selectedWordIndices.length == 1) {
              _selectedWordIndices.clear();
            } else {
              _selectedWordIndices.clear();
              _selectedWordIndices.add(i);
            }
          }
        });
      },
      onDragWord: (i, delta, bounds) {
        setState(() {
          if (!_selectedWordIndices.contains(i)) {
            _selectedWordIndices.clear();
            _selectedWordIndices.add(i);
          }
          final double deltaX = delta.dx / (bounds.width / 2);
          final double deltaY = delta.dy / (bounds.height / 2);
          for (final index in _selectedWordIndices) {
            final w = slide.wordTokens[index];
            w.position = Alignment(
              (w.position.x + deltaX).clamp(-1.0, 1.0),
              (w.position.y + deltaY).clamp(-1.0, 1.0),
            );
          }
        });
      },
      onDragClassicText: (delta, bounds) {
        setState(() {
          final double dx = slide.textAlignment.x + (delta.dx / (bounds.width / 2));
          final double dy = slide.textAlignment.y + (delta.dy / (bounds.height / 2));
          slide.textAlignment = Alignment(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
        });
      },
      onMeasureClassicSize: (size) {
        _lastPreviewWidth = size.width;
        _lastPreviewHeight = size.height;
      },
    );
  }

  Widget _buildDotsIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavButton(
            onPressed: _currentIndex > 0 ? _goToPrevious : null,
            icon: Icons.west,
            label: 'PREV',
            color: Colors.white,
            bgColor: Colors.grey[700]!,
          ),
          const SizedBox(width: 24),
          ...List.generate(_slides.length, (index) {
            bool isCurrent = _currentIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isCurrent ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isCurrent ? const Color(0xFF6C63FF) : Colors.grey[300],
              ),
            );
          }),
          const SizedBox(width: 24),
          _buildNavButton(
            onPressed: _currentIndex < _slides.length - 1 ? _goToNext : null,
            icon: Icons.east,
            label: 'NEXT',
            color: Colors.white,
            bgColor: Colors.indigo[400]!,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    bool isEnabled = onPressed != null;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? bgColor : Colors.grey[50],
        foregroundColor: isEnabled ? color : Colors.grey[400],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isEnabled ? color.withOpacity(0.1) : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == 'PREV') Icon(icon, size: 16),
          if (label == 'PREV') const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          if (label == 'NEXT') const SizedBox(width: 8),
          if (label == 'NEXT') Icon(icon, size: 16),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              height: 200,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SingleChildScrollView(
                child: _buildActiveTabContent(),
              ),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    final current = _slides[_currentIndex];
    switch (_selectedTabIndex) {
      case 0:
        return CarouselImageTab(
          slide: current,
          currentIndex: _currentIndex,
          totalSlides: _slides.length,
          isRemovingBg: _isRemovingBg,
          editFgAdjustments: _editFgAdjustments,
          onToggleEditFg: (val) => setState(() => _editFgAdjustments = val),
          onAddSlide: _addSlide,
          onImportMultiple: _pickMultipleImages,
          onReplaceImage: _pickImageForCurrentSlide,
          onRemoveBackground: () => _removeBackgroundForSlide(_currentIndex),
          onEditCutout: () => _editForegroundCutout(_currentIndex),
          onClearForeground: () => setState(() {
            current.foregroundImage = null;
            current.uiForegroundImage = null;
          }),
          onDeleteSlide: () => _removeSlide(_currentIndex),
          onStateChanged: () => setState(() {}),
        );
      case 1:
        return CarouselTextTab(
          slide: current,
          selectedWordIndices: _selectedWordIndices,
          multiSelectMode: _multiSelectMode,
          onSplitToWords: () {
            setState(() {
              current.splitTextIntoTokens(
                containerWidth: _lastPreviewWidth,
                containerHeight: _lastPreviewHeight,
                defaultFont: _selectedFont,
              );
              _selectedWordIndices.clear();
              current.isLocked = true;
            });
          },
          onLockAllSlides: () {
            setState(() {
              for (final s in _slides) {
                s.isLocked = true;
              }
            });
          },
          onImportFromMyQuotes: _importFromMyQuotes,
          onBulkPaste: () => showCarouselBulkPasteDialog(
            context: context,
            slides: _slides,
            onStateChanged: () => setState(() {}),
          ),
          onMultiSelectChanged: (val) =>
              setState(() => _multiSelectMode = val),
          onSelectedWordsChanged: (val) =>
              setState(() => _selectedWordIndices = val),
          onStateChanged: () => setState(() {}),
        );
      case 2:
        return CarouselPositionTab(
          slide: current,
          selectedWordIndices: _selectedWordIndices,
          multiSelectMode: _multiSelectMode,
          onMultiSelectChanged: (val) =>
              setState(() => _multiSelectMode = val),
          onSelectedWordsChanged: (val) =>
              setState(() => _selectedWordIndices = val),
          onStateChanged: () => setState(() {}),
        );
      case 3:
        return CarouselFontTab(
          slide: current,
          selectedFont: _selectedFont,
          selectedWordIndices: _selectedWordIndices,
          multiSelectMode: _multiSelectMode,
          onMultiSelectChanged: (val) =>
              setState(() => _multiSelectMode = val),
          onSelectedWordsChanged: (val) =>
              setState(() => _selectedWordIndices = val),
          onStateChanged: () => setState(() {}),
        );
      case 4:
        return CarouselEffectsTab(
          slide: current,
          selectedWordIndices: _selectedWordIndices,
          multiSelectMode: _multiSelectMode,
          onMultiSelectChanged: (val) =>
              setState(() => _multiSelectMode = val),
          onSelectedWordsChanged: (val) =>
              setState(() => _selectedWordIndices = val),
          onPickStrokeColor: () => _showColorPicker(isStroke: true),
          onPickShadowColor: () => _showColorPicker(isShadow: true),
          onStateChanged: () => setState(() {}),
        );
      case 5:
        return CarouselMaskTab(
          slides: _slides,
          currentSlide: current,
          applyMaskToAll: _applyMaskToAll,
          onApplyMaskToAllChanged: (val) =>
              setState(() => _applyMaskToAll = val),
          onPickMaskColor: () => _showColorPicker(isMask: true),
          onStateChanged: () => setState(() {}),
        );
      case 6:
        return CarouselStyleTab(
          slide: current,
          selectedWordIndices: _selectedWordIndices,
          multiSelectMode: _multiSelectMode,
          onMultiSelectChanged: (val) =>
              setState(() => _multiSelectMode = val),
          onSelectedWordsChanged: (val) =>
              setState(() => _selectedWordIndices = val),
          onPickCustomBgColor: () => _showColorPicker(isBg: true),
          onPickCustomTextColor: () => _showColorPicker(isBg: false),
          onStateChanged: () => setState(() {}),
        );
      case 7:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CarouselSectionHeader(title: 'Canvas Size'),
            CarouselAspectRatioSelector(
              selectedIndex: _selectedAspectIndex,
              onChanged: (idx) => setState(() => _selectedAspectIndex = idx),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showColorPicker(
      {bool isBg = false, bool isShadow = false, bool isMask = false, bool isStroke = false}) async {
    final slide = _slides[_currentIndex];
    final bool wordMode = slide.useWordMode && _selectedWordIndices.isNotEmpty;

    Color initialColor = isBg
        ? slide.bgColor
        : (isMask
            ? slide.maskColor
            : (isStroke
                ? (wordMode
                    ? slide.wordTokens[_selectedWordIndices.first].strokeColor
                    : slide.textStrokeColor)
                : (isShadow
                    ? (wordMode
                        ? slide.wordTokens[_selectedWordIndices.first].shadowColor
                        : slide.shadowColor)
                    : (wordMode
                        ? slide.wordTokens[_selectedWordIndices.first].color
                        : slide.textColor))));

    Color selectedColor = initialColor;

    String title = 'Text Color';
    if (isBg) {
      title = 'Background Color';
    } else if (isStroke) {
      title = 'Stroke Color';
    } else if (isShadow) {
      title = 'Shadow Color';
    } else if (isMask) {
      title = 'Mask Color';
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.colorize_rounded,
                      size: 20, color: Color(0xFF6C63FF)),
                  tooltip: 'Eye Dropper',
                  onPressed: () {
                    Navigator.pop(context);
                    String target = 'text';
                    if (isBg) {
                      target = 'bg';
                    } else if (isStroke) {
                      target = 'stroke';
                    } else if (isShadow) {
                      target = 'shadow';
                    } else if (isMask) {
                      target = 'mask';
                    }
                    _startEyeDropper(target);
                  },
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdvancedColorPicker(
                initialColor: initialColor,
                onColorChanged: (color) {
                  selectedColor = color;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (isBg) {
                        slide.bgColor = selectedColor;
                      } else if (isMask) {
                        if (_applyMaskToAll) {
                          for (var s in _slides) {
                            s.maskColor = selectedColor;
                          }
                        } else {
                          slide.maskColor = selectedColor;
                        }
                      } else if (isStroke) {
                        if (wordMode) {
                          for (int idx in _selectedWordIndices) {
                            slide.wordTokens[idx].strokeColor = selectedColor;
                          }
                        } else {
                          slide.textStrokeColor = selectedColor;
                        }
                      } else if (isShadow) {
                        if (wordMode) {
                          for (int idx in _selectedWordIndices) {
                            slide.wordTokens[idx].shadowColor = selectedColor;
                          }
                        } else {
                          slide.shadowColor = selectedColor;
                        }
                      } else {
                        if (wordMode) {
                          for (int idx in _selectedWordIndices) {
                            slide.wordTokens[idx].color = selectedColor;
                          }
                        } else {
                          slide.textColor = selectedColor;
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Select Color'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlTabs() {
    final tabs = [
      {
        'icon': Icons.photo_library_outlined,
        'label': 'Image',
        'color': Colors.blue
      },
      {'icon': Icons.title_rounded, 'label': 'Text', 'color': Colors.amber},
      {'icon': Icons.open_with, 'label': 'Position', 'color': Colors.indigo},
      {
        'icon': Icons.font_download_outlined,
        'label': 'Font',
        'color': Colors.green
      },
      {
        'icon': Icons.auto_fix_high_outlined,
        'label': 'Effects',
        'color': Colors.pink
      },
      {'icon': Icons.layers_outlined, 'label': 'Mask', 'color': Colors.purple},
      {
        'icon': Icons.palette_outlined,
        'label': 'Color',
        'color': Colors.deepOrange
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Config',
        'color': Colors.grey
      },
    ];

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: ElevatedButton(
              onPressed: _exportAllSlides,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Icon(Icons.download, size: 20),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final isSelected = _selectedTabIndex == index;
                final tab = tabs[index];
                final Color baseColor = tab['color'] as Color;
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
                    width: 75,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected && _isTabContentExpanded
                          ? baseColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 22,
                          color: isSelected && _isTabContentExpanded
                              ? baseColor
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected && _isTabContentExpanded
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected && _isTabContentExpanded
                                ? baseColor
                                : Colors.grey[700],
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
      ),
    );
  }
}
