import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:open_file/open_file.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../utils/image_generator.dart';
import '../../utils/font_selector.dart';
import '../../services/app_review_service.dart';

class CarouselSlide {
  File? image;
  String text = '';
  Color bgColor = Colors.black87;
  Color textColor = Colors.white;
  GlobalKey previewKey = GlobalKey();
  TransformationController transformationController = TransformationController();
  
  // Text Effects
  bool enableShadow = true;
  double shadowBlur = 4.0;
  Offset shadowOffset = const Offset(2, 2);
  Color shadowColor = Colors.black54;

  bool enableGlow = false;
  double glowRadius = 10.0;
  Color glowColor = Colors.white70;

  Alignment textAlignment = Alignment.center;
  FontInfo? font;
}

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

  int _selectedTabIndex = 0; // 0: Image, 1: Text, 2: Font, 3: Effects, 4: Color, 5: Config
  bool _isTabContentExpanded = true;

  double get _currentAspectRatio {
    switch (_selectedAspectIndex) {
      case 1: return 1 / 1;
      case 2: return 9 / 16;
      case 3: return 16 / 9;
      case 0:
      default: return 4 / 5;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      _slides.clear();
      for (final path in widget.sharedImagePaths!) {
        _slides.add(CarouselSlide()..image = File(path));
      }
    }
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

  void _removeSlide(int index) {
    if (_slides.length <= 1) return;
    setState(() {
      _slides.removeAt(index);
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
          if (_slides.length == 1 && _slides[0].image == null && _slides[0].text.isEmpty) {
            _slides.clear();
          }

          for (var img in images) {
            if (_slides.length < 10) {
              _slides.add(CarouselSlide()..image = File(img.path));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Maximum 10 slides allowed. Some dropped.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
              );
              break;
            }
          }
          
          if (_slides.isEmpty) { _slides.add(CarouselSlide()); } // safety
        });
        
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
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

  Future<void> _exportAllSlides() async {
    if (_slides.every((s) => s.image == null && s.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add content to export')),
      );
      return;
    }

    _processImageExport();
  }

  Future<void> _processImageExport() async {
    const platform = MethodChannel('com.quickpost.app/processor');
    
    // 1. Prepare Slide Data
    final List<Map<String, dynamic>> slideData = _slides.map((s) => {
      'text': s.text,
      'imagePath': s.image?.path,
      'bgColor': '#${s.bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'textColor': '#${s.textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'fontSize': 60.0,
      'fontPath': s.font?.family,
      'fontWeight': s.font?.weight?.value ?? 400,
      'fontItalic': s.font?.style == FontStyle.italic,
      // Text Effects
      'enableShadow': s.enableShadow,
      'shadowColor': '#${s.shadowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'shadowBlur': s.shadowBlur,
      'shadowOffsetX': s.shadowOffset.dx,
      'shadowOffsetY': s.shadowOffset.dy,
      'enableGlow': s.enableGlow,
      'glowColor': '#${s.glowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'glowRadius': s.glowRadius,
      'textAlignX': s.textAlignment.x,
      'textAlignY': s.textAlignment.y,
      'imageZoom': s.transformationController.value.getMaxScaleOnAxis(),
      'imageOffsetX': s.transformationController.value.storage[12] / 1080.0,
      'imageOffsetY': s.transformationController.value.storage[13] / (1080.0 / _currentAspectRatio),
    }).toList();

    // 2. Setup Dimensions
    const int baseWidth = 1080;
    final double aspect = _currentAspectRatio;
    int exportWidth = baseWidth;
    int exportHeight = (baseWidth / aspect).round();

    // 3. UI State for Dialog
    double currentProgress = 0.0;
    String currentStep = 'Warming up GPU engine...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          platform.setMethodCallHandler((call) async {
            if (call.method == 'onProgress') {
              setDialogState(() => currentProgress = (call.arguments as num).toDouble());
            } else if (call.method == 'onStep') {
              setDialogState(() => currentStep = call.arguments as String);
            }
          });

          return AlertDialog(
            title: const Text('Exporting Images'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: currentProgress, color: const Color(0xFF6C63FF)),
                const SizedBox(height: 16),
                Text(currentStep, style: const TextStyle(fontSize: 12)),
                Text('${(currentProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }
      ),
    );

    try {
      final List<dynamic>? results = await platform.invokeMethod('createCarouselImages', {
        'slides': slideData,
        'width': exportWidth,
        'height': exportHeight,
      });

      if (mounted) Navigator.pop(context);

      if (results != null && results.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported ${results.length} images to gallery!')),
        );
        AppReviewService().incrementExportCount();
        AppReviewService().checkAndRequestReview();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image export failed: $e')),
      );
    } finally {
      platform.setMethodCallHandler(null);
    }
  }

  Future<void> _exportAsVideo() async {
    const platform = MethodChannel('com.quickpost.app/processor');
    
    // 1. Prepare Slide Data for Native
    final List<Map<String, dynamic>> slideData = _slides.map((s) => {
      'text': s.text,
      'imagePath': s.image?.path,
      'bgColor': '#${s.bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'textColor': '#${s.textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'fontSize': 60.0,
      'fontPath': s.font?.family,
      'fontWeight': s.font?.weight?.value ?? 400,
      'fontItalic': s.font?.style == FontStyle.italic,
      // Text Effects
      'enableShadow': s.enableShadow,
      'shadowColor': '#${s.shadowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'shadowBlur': s.shadowBlur,
      'shadowOffsetX': s.shadowOffset.dx,
      'shadowOffsetY': s.shadowOffset.dy,
      'enableGlow': s.enableGlow,
      'glowColor': '#${s.glowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'glowRadius': s.glowRadius,
      'textAlignX': s.textAlignment.x,
      'textAlignY': s.textAlignment.y,
      'imageZoom': s.transformationController.value.getMaxScaleOnAxis(),
      'imageOffsetX': s.transformationController.value.storage[12] / 1080.0,
      'imageOffsetY': s.transformationController.value.storage[13] / (1080.0 / _currentAspectRatio),
    }).toList();

    // 2. Setup Dimensions
    const int baseWidth = 1080;
    final double aspect = _currentAspectRatio;
    int exportWidth = baseWidth;
    int exportHeight = (baseWidth / aspect).round();
    if (exportHeight % 2 != 0) exportHeight--; // Even height for codec

    // 3. Define Handlers
    double currentProgress = 0.0;
    String currentStep = 'Preparing GPU engine...';
    
    // 4. Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Listen to progress from channel
          platform.setMethodCallHandler((call) async {
            if (call.method == 'onProgress') {
              setDialogState(() => currentProgress = (call.arguments as num).toDouble());
            } else if (call.method == 'onStep') {
              setDialogState(() => currentStep = call.arguments as String);
            }
          });

          return AlertDialog(
            title: const Text('Exporting Video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: currentProgress, color: const Color(0xFF6C63FF)),
                const SizedBox(height: 16),
                Text(currentStep, style: const TextStyle(fontSize: 12)),
                Text('${(currentProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }
      ),
    );

    try {
      final String? result = await platform.invokeMethod('createCarouselVideo', {
        'slides': slideData,
        'width': exportWidth,
        'height': exportHeight,
        'durationPerSlide': 3.0,
      });

      if (mounted) Navigator.pop(context);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved to gallery!')),
        );
        AppReviewService().incrementExportCount();
        AppReviewService().checkAndRequestReview();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video export failed: $e')),
      );
    } finally {
      platform.setMethodCallHandler(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Carousel Post Maker', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export All Slides',
            onPressed: _exportAllSlides,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Invisible layer to render all slides for export
          Positioned(
            left: -9999,
            top: -9999,
            child: Row(
              children: _slides.map((s) => _buildSlideWidget(s, true)).toList(),
            ),
          ),
          
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _slides.length,
                          onPageChanged: (idx) => setState(() => _currentIndex = idx),
                          itemBuilder: (context, index) {
                            return Center(
                              child: AspectRatio(
                                aspectRatio: _currentAspectRatio,
                                child: _buildSlideWidget(_slides[index], false),
                              ),
                            );
                          },
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
    );
  }

  Widget _buildSlideWidget(CarouselSlide slide, bool isExport) {
    Widget imageWidget = slide.image != null
        ? Image.file(
            slide.image!,
            fit: BoxFit.cover,
          )
        : const SizedBox.shrink();

    Widget content = Container(
      color: slide.bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (slide.image != null)
            isExport
                ? Center(
                    child: Transform(
                      transform: slide.transformationController.value,
                      alignment: Alignment.center,
                      child: imageWidget,
                    ),
                  )
                : InteractiveViewer(
                    transformationController: slide.transformationController,
                    clipBehavior: Clip.none,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: imageWidget,
                  ),
          if (slide.text.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Align(
                      alignment: slide.textAlignment,
                      child: GestureDetector(
                        onPanUpdate: isExport ? null : (details) {
                          setState(() {
                            double dx = slide.textAlignment.x + (details.delta.dx / (constraints.maxWidth / 2));
                            double dy = slide.textAlignment.y + (details.delta.dy / (constraints.maxHeight / 2));
                            slide.textAlignment = Alignment(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            slide.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: slide.textColor,
                              fontSize: 24,
                              fontFamily: slide.font?.family,
                              fontWeight: slide.font?.weight ?? FontWeight.bold,
                              shadows: [
                                if (slide.enableShadow)
                                  Shadow(
                                    color: slide.shadowColor,
                                    offset: slide.shadowOffset,
                                    blurRadius: slide.shadowBlur,
                                  ),
                                if (slide.enableGlow)
                                  Shadow(
                                    color: slide.glowColor,
                                    offset: Offset.zero,
                                    blurRadius: slide.glowRadius,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
        ],
      ),
    );

    if (isExport) {
      return RepaintBoundary(
        key: slide.previewKey,
        child: SizedBox(
          width: 1080,
          height: 1080 / _currentAspectRatio,
          child: content,
        ),
      );
    }
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _buildAspectRatioSelector() {
    const options = [
      {'label': '4:5', 'index': 0},
      {'label': '1:1', 'index': 1},
      {'label': '9:16', 'index': 2},
      {'label': '16:9', 'index': 3},
    ];

    return Row(
      children: options.map((opt) {
        bool isSel = _selectedAspectIndex == opt['index'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(opt['label'] as String, style: const TextStyle(fontSize: 11)),
            selected: isSel,
            onSelected: (val) {
              if (val) setState(() => _selectedAspectIndex = opt['index'] as int);
            },
          ),
        );
      }).toList(),
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
    switch (_selectedTabIndex) {
      case 0: return _buildImageTab();
      case 1: return _buildTextTab();
      case 2: return _buildFontTab();
      case 3: return _buildEffectsTab();
      case 4: return _buildStyleTab();
      case 5: return _buildSettingsTab();
      default: return _buildImageTab();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildImageTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Slide Management'),
            Text('Slide ${_currentIndex + 1} of ${_slides.length}', 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSmallImageAction(
                onPressed: _addSlide,
                icon: Icons.add,
                label: 'Add',
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildSmallImageAction(
                onPressed: _pickMultipleImages,
                icon: Icons.photo_library,
                label: 'Import',
                color: Colors.teal,
              ),
              const SizedBox(width: 8),
              _buildSmallImageAction(
                onPressed: _pickImageForCurrentSlide,
                icon: Icons.refresh,
                label: 'Replace',
                color: Colors.orange,
              ),
              if (_slides.length > 1) ...[
                const SizedBox(width: 8),
                _buildSmallImageAction(
                  onPressed: () => _removeSlide(_currentIndex),
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
        if (_slides[_currentIndex].image != null) ...[
          const SizedBox(height: 12),
          _buildSectionHeader('Image Adjustments'),
          Row(
            children: [
              _buildSmallImageAction(
                onPressed: () {
                  setState(() {
                    _slides[_currentIndex].transformationController.value = Matrix4.identity();
                  });
                },
                icon: Icons.center_focus_strong,
                label: 'Reset Transform',
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              _buildSmallImageAction(
                onPressed: () => setState(() => _slides[_currentIndex].image = null),
                icon: Icons.close,
                label: 'Clear Image',
                color: Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: Drag on the image above to adjust its position.',
            style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Text Content'),
        TextField(
          controller: TextEditingController(text: _slides[_currentIndex].text)
            ..selection = TextSelection.collapsed(offset: _slides[_currentIndex].text.length),
          onChanged: (val) {
            setState(() => _slides[_currentIndex].text = val);
          },
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Type something for this slide...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tip: Drag text on the image to position it.', 
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
            TextButton.icon(
              onPressed: () => setState(() => _slides[_currentIndex].textAlignment = Alignment.center),
              icon: const Icon(Icons.center_focus_weak, size: 14),
              label: const Text('Reset Postion', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            ),
          ],
        ),
        const Divider(height: 24),
        _buildSectionHeader('Bulk Actions'),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showBulkPasteDialog,
            icon: const Icon(Icons.paste_rounded, size: 18),
            label: const Text('Bulk Paste / Auto-Split Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
              foregroundColor: const Color(0xFF6C63FF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _showBulkPasteDialog() {
    final TextEditingController bulkController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Paste Text', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Each new line will be assigned to a separate slide.', 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: bulkController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Line 1 for Slide 1\nLine 2 for Slide 2\n...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final lines = bulkController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
              if (lines.isNotEmpty) {
                setState(() {
                  // If we have more lines than slides, add more blank slides
                  while (_slides.length < lines.length) {
                    _slides.add(CarouselSlide());
                  }
                  // Assign lines to slides
                  for (int i = 0; i < lines.length; i++) {
                    _slides[i].text = lines[i].trim();
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated ${lines.length} slides with bulk text!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply to Slides'),
          ),
        ],
      ),
    );
  }

  Widget _buildFontTab() {
    CarouselSlide current = _slides[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Typography'),
        HorizontalFontSelector(
          selectedFont: current.font,
          onFontSelected: (font) => setState(() => current.font = font),
        ),
      ],
    );
  }

  Widget _buildEffectsTab() {
    CarouselSlide current = _slides[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Text Styling'),
        SwitchListTile(
          title: const Text('Drop Shadow', style: TextStyle(fontSize: 12)),
          value: current.enableShadow,
          onChanged: (v) => setState(() => current.enableShadow = v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (current.enableShadow) ...[
          _buildEffectSlider('Blur', current.shadowBlur, 0, 20, (v) => setState(() => current.shadowBlur = v)),
          _buildEffectSlider('Offset X', current.shadowOffset.dx, -10, 10, (v) => setState(() => current.shadowOffset = Offset(v, current.shadowOffset.dy))),
          _buildEffectSlider('Offset Y', current.shadowOffset.dy, -10, 10, (v) => setState(() => current.shadowOffset = Offset(current.shadowOffset.dx, v))),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Glow Effect', style: TextStyle(fontSize: 12)),
          value: current.enableGlow,
          onChanged: (v) => setState(() => current.enableGlow = v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (current.enableGlow) ...[
          _buildEffectSlider('Radius', current.glowRadius, 0, 30, (v) => setState(() => current.glowRadius = v)),
        ],
      ],
    );
  }

  Widget _buildEffectSlider(String label, double val, double min, double max, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(value: val, min: min, max: max, onChanged: onChanged),
          ),
        ),
        Text(val.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildStyleTab() {
    CarouselSlide current = _slides[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Slide Background'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildColorOption(const Color(0xFF121212), Colors.white, 'Ink', true),
              _buildColorOption(Colors.white, const Color(0xFF121212), 'Snow', true),
              _buildColorOption(const Color(0xFFFF4E50), Colors.white, 'Sunset', true),
              _buildColorOption(const Color(0xFF6C63FF), Colors.white, 'Royal', true),
              _buildColorOption(const Color(0xFF00D2FF), Colors.white, 'Ocean', true),
              _buildColorOption(const Color(0xFFFC67FA), Colors.white, 'Electric', true),
              _buildColorOption(const Color(0xFF00F260), const Color(0xFF121212), 'Cyber', true),
              _buildColorOption(const Color(0xFFFDC830), const Color(0xFF121212), 'Gold', true),
              _buildCustomColorButton(true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Text Color'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTextVariant(Colors.white, 'Bright'),
              _buildTextVariant(const Color(0xFF121212), 'Dark'),
              _buildTextVariant(const Color(0xFFFF4E50), 'Sunset'),
              _buildTextVariant(const Color(0xFF6C63FF), 'Royal'),
              _buildTextVariant(const Color(0xFF00D2FF), 'Ocean'),
              _buildTextVariant(const Color(0xFFFC67FA), 'Neon'),
              _buildTextVariant(const Color(0xFF00F260), 'Cyber'),
              _buildTextVariant(const Color(0xFFFDC830), 'Gold'),
              _buildCustomColorButton(false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextVariant(Color color, String label) {
    bool isSel = _slides[_currentIndex].textColor == color;
    return GestureDetector(
      onTap: () => setState(() => _slides[_currentIndex].textColor = color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Text(label, style: TextStyle(color: isSel ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildColorOption(Color bg, Color text, String label, bool isBg) {
    CarouselSlide current = _slides[_currentIndex];
    bool isSel = current.bgColor == bg;
    return GestureDetector(
      onTap: () {
        setState(() {
          current.bgColor = bg;
          // Optionally auto-set text color for contrast if it's the default
          if (current.textColor == Colors.white || current.textColor == const Color(0xFF121212)) {
            current.textColor = text;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? const Color(0xFF6C63FF) : Colors.transparent, width: 3),
        ),
        child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Canvas Size'),
        _buildAspectRatioSelector(),
      ],
    );
  }

  Widget _buildCustomColorButton(bool isBg) {
    return GestureDetector(
      onTap: () => _showColorPicker(isBg),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.colorize_rounded, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text('Custom', style: TextStyle(color: Colors.grey[800], fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(bool isBg) async {
    final List<Color> palette = [
      Colors.white, Colors.black, const Color(0xFF121212),
      Colors.grey, Colors.red, Colors.pink, Colors.purple,
      Colors.deepPurple, Colors.indigo, Colors.blue,
      Colors.lightBlue, Colors.cyan, Colors.teal,
      Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange,
      Colors.deepOrange, Colors.brown, Colors.blueGrey,
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBg ? 'Select Background Color' : 'Select Text Color', 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: palette.map((color) => GestureDetector(
              onTap: () {
                setState(() {
                  if (isBg) {
                    _slides[_currentIndex].bgColor = color;
                  } else {
                    _slides[_currentIndex].textColor = color;
                  }
                });
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildControlTabs() {
    final tabs = [
      {'icon': Icons.photo_library_outlined, 'label': 'Image', 'color': Colors.blue},
      {'icon': Icons.title, 'label': 'Text', 'color': Colors.teal},
      {'icon': Icons.font_download_outlined, 'label': 'Font', 'color': Colors.purple},
      {'icon': Icons.auto_fix_high_outlined, 'label': 'Effects', 'color': Colors.pink},
      {'icon': Icons.palette_outlined, 'label': 'Color', 'color': Colors.deepOrange},
      {'icon': Icons.settings_outlined, 'label': 'Config', 'color': Colors.grey},
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          ? baseColor.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 22,
                          color: isSelected && _isTabContentExpanded ? baseColor : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected && _isTabContentExpanded
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected && _isTabContentExpanded ? baseColor : Colors.grey[700],
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

  Widget _buildSmallImageAction({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
