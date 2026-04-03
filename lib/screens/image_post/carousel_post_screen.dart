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
import '../../widgets/advanced_color_picker.dart';
import '../../utils/custom_font_manager.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/app_review_service.dart';

import 'dart:math' as math;

class WordToken {
  String text;
  Alignment position;
  Alignment? originalPosition; // Stores the position right after splitting
  double fontSize;
  Color color;
  FontInfo? font;
  double rotation; // degrees

  // Text effects (inherited from slide defaults)
  bool enableShadow;
  double shadowBlur;
  Offset shadowOffset;
  Color shadowColor;
  bool enableGlow;
  double glowRadius;
  Color glowColor;

  WordToken({
    required this.text,
    this.position = Alignment.center,
    this.originalPosition,
    this.fontSize = 28.0,
    this.color = Colors.white,
    this.font,
    this.rotation = 0.0,
    this.enableShadow = true,
    this.shadowBlur = 4.0,
    this.shadowOffset = const Offset(2, 2),
    this.shadowColor = Colors.black54,
    this.enableGlow = false,
    this.glowRadius = 10.0,
    this.glowColor = Colors.white70,
  });
}

class CarouselSlide {
  File? image;
  String text = '';
  Color bgColor = Colors.black87;
  Color textColor = Colors.white;
  GlobalKey previewKey = GlobalKey();
  TransformationController transformationController = TransformationController();
  
  // Text Effects (defaults for new words)
  bool enableShadow = true;
  double shadowBlur = 4.0;
  Offset shadowOffset = const Offset(2, 2);
  Color shadowColor = Colors.black54;

  bool enableGlow = false;
  double glowRadius = 10.0;
  Color glowColor = Colors.white70;

  Alignment textAlignment = Alignment.center;
  FontInfo? font;

  // Per-word tokens
  List<WordToken> wordTokens = [];
  bool useWordMode = false;

  /// Split current text into WordTokens preserving their exact visual positions.
  void splitTextIntoTokens({
    required double containerWidth,
    required double containerHeight,
    FontInfo? defaultFont,
  }) {
    if (text.trim().isEmpty) return;

    wordTokens = [];
    final double baseX = textAlignment.x;
    final double baseY = textAlignment.y;

    final TextStyle style = TextStyle(
      fontSize: 28.0,
      fontFamily: font?.family ?? defaultFont?.family,
      fontWeight: font?.weight ?? defaultFont?.weight ?? FontWeight.bold,
    );

    // 1. Measure the full text exactly as it appears in classic mode
    // Classic mode has Padding(16) each side, so maxWidth is containerWidth - 32
    final fullPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: (containerWidth - 32).clamp(0, double.infinity));

    final double fullTextWidth = fullPainter.width;
    final double fullTextHeight = fullPainter.height;

    // 2. Calculate the pixel origin of the text content within the container
    // Classic widget tree: Align(alignment) -> Padding(16) -> Text
    // Child size of Align = (fullTextWidth + 32, fullTextHeight + 32)
    const double pad = 16.0;
    final double classicChildW = fullTextWidth + pad * 2;
    final double classicChildH = fullTextHeight + pad * 2;

    // Align formula: childLeft = (containerW - childW) * (x + 1) / 2
    final double blockLeft = (containerWidth - classicChildW) * (baseX + 1) / 2;
    final double blockTop = (containerHeight - classicChildH) * (baseY + 1) / 2;

    // The actual text characters start at blockLeft + pad, blockTop + pad
    final double textContentLeft = blockLeft + pad;
    final double textContentTop = blockTop + pad;

    // 3. Extract each word and its rendered bounding box
    final wordRegex = RegExp(r'\S+');
    final matches = wordRegex.allMatches(text);
    
    // Word widget padding (horizontal 6, vertical 2)
    const double wordPadH = 6.0;
    const double wordPadV = 2.0;

    for (final match in matches) {
      final String wordStr = match.group(0)!;
      final range = TextSelection(baseOffset: match.start, extentOffset: match.end);
      final boxes = fullPainter.getBoxesForSelection(range);
      
      if (boxes.isEmpty) continue;

      // Use the first box (usually words don't wrap, but if they do, we pick the start)
      final box = boxes.first;

      // wordWidgetLeft = textContentLeft + wordOffsetWithinPainter - wordWidgetPadding
      final double wordWidgetLeft = textContentLeft + box.left - wordPadH;
      final double wordWidgetTop = textContentTop + box.top - wordPadV;

      // wordWidgetSize = textSegmentSize + wordWidgetPadding*2
      final double wordChildW = (box.right - box.left) + wordPadH * 2;
      final double wordChildH = (box.bottom - box.top) + wordPadV * 2;

      // 4. Map pixel coordinates back to Alignment space
      // x = 2 * leftPx / (containerW - childW) - 1
      double alignX = 0.0;
      final double denomX = containerWidth - wordChildW;
      if (denomX.abs() > 0.1) {
        alignX = (2.0 * wordWidgetLeft / denomX) - 1.0;
      }

      double alignY = 0.0;
      final double denomY = containerHeight - wordChildH;
      if (denomY.abs() > 0.1) {
        alignY = (2.0 * wordWidgetTop / denomY) - 1.0;
      }

      final Alignment pos = Alignment(alignX.clamp(-1.0, 1.0), alignY.clamp(-1.0, 1.0));
      wordTokens.add(WordToken(
        text: wordStr,
        position: pos,
        originalPosition: pos,
        fontSize: 28.0,
        color: textColor,
        font: font,
        enableShadow: enableShadow,
        shadowBlur: shadowBlur,
        shadowOffset: shadowOffset,
        shadowColor: shadowColor,
        enableGlow: enableGlow,
        glowRadius: glowRadius,
        glowColor: glowColor,
      ));
    }

    useWordMode = true;
  }
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
  Set<int> _selectedWordIndices = {}; // Multiple words selection
  bool _multiSelectMode = false;
  Timer? _nudgeTimer;

  double? _snapLineX;
  double? _snapLineY;

  // Track preview dimensions for precise coordinate mapping
  double _lastPreviewWidth = 360;
  double _lastPreviewHeight = 450;

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
    _selectedFont = FontInfo.availableFonts.firstWhere(
      (f) => f.family == 'Poppins' && f.weight == FontWeight.bold,
      orElse: () => FontInfo.availableFonts.first,
    );
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      _slides.clear();
      for (final path in widget.sharedImagePaths!) {
        _slides.add(CarouselSlide()..image = File(path));
      }
    }
  }

  @override
  void dispose() {
    _nudgeTimer?.cancel();
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
    
    // 1. Prepare Slide Data (Asynchronously resolve fonts)
    final List<Map<String, dynamic>> slideData = [];
    for (final s in _slides) {
      final String fontPath = await _resolveFontPath(s.font);
      final Map<String, dynamic> data = {
        'text': s.text,
        'imagePath': s.image?.path,
        'bgColor': '#${s.bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        'textColor': '#${s.textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        'fontSize': 60.0,
        'fontPath': fontPath,
        'fontWeight': s.font?.weight?.value ?? _selectedFont?.weight?.value ?? 400,
        'fontItalic': s.font?.style == FontStyle.italic || _selectedFont?.style == FontStyle.italic,
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
        'useWordMode': s.useWordMode,
      };

      if (s.useWordMode && s.wordTokens.isNotEmpty) {
        final List<Map<String, dynamic>> words = [];
        for (final w in s.wordTokens) {
          final String wordFontPath = await _resolveFontPath(w.font ?? s.font);
          words.add({
            'text': w.text,
            'posX': w.position.x,
            'posY': w.position.y,
            'fontSize': w.fontSize,
            'color': '#${w.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            'fontPath': wordFontPath,
            'fontWeight': w.font?.weight?.value ?? s.font?.weight?.value ?? _selectedFont?.weight?.value ?? 400,
            'fontItalic': w.font?.style == FontStyle.italic || s.font?.style == FontStyle.italic || _selectedFont?.style == FontStyle.italic,
            'rotation': w.rotation,
            'enableShadow': w.enableShadow,
            'shadowColor': '#${w.shadowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            'shadowBlur': w.shadowBlur,
            'shadowOffsetX': w.shadowOffset.dx,
            'shadowOffsetY': w.shadowOffset.dy,
            'enableGlow': w.enableGlow,
            'glowColor': '#${w.glowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            'glowRadius': w.glowRadius,
          });
        }
        data['words'] = words;
      }
      slideData.add(data);
    }

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
    
    // 1. Prepare Slide Data for Native (Asynchronously resolve fonts)
    final List<Map<String, dynamic>> slideData = [];
    for (final s in _slides) {
      final String fontPath = await _resolveFontPath(s.font);
      final Map<String, dynamic> data = {
        'text': s.text,
        'imagePath': s.image?.path,
        'bgColor': '#${s.bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        'textColor': '#${s.textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        'fontSize': 60.0,
        'fontPath': fontPath,
        'fontWeight': s.font?.weight?.value ?? _selectedFont?.weight?.value ?? 400,
        'fontItalic': s.font?.style == FontStyle.italic || _selectedFont?.style == FontStyle.italic,
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
        'useWordMode': s.useWordMode,
      };

      if (s.useWordMode && s.wordTokens.isNotEmpty) {
        final List<Map<String, dynamic>> words = [];
        for (final w in s.wordTokens) {
          final String wordFontPath = await _resolveFontPath(w.font ?? s.font);
          words.add({
            'text': w.text,
            'posX': w.position.x,
            'posY': w.position.y,
            'fontSize': w.fontSize,
            'color': '#${w.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            'fontPath': wordFontPath,
            'fontWeight': w.font?.weight?.value ?? s.font?.weight?.value ?? _selectedFont?.weight?.value ?? 400,
            'fontItalic': w.font?.style == FontStyle.italic || s.font?.style == FontStyle.italic || _selectedFont?.style == FontStyle.italic,
            'rotation': w.rotation,
            'enableShadow': w.enableShadow,
            'shadowColor': '#${w.shadowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            'shadowBlur': w.shadowBlur,
            'shadowOffsetX': w.shadowOffset.dx,
            'shadowOffsetY': w.shadowOffset.dy,
            'enableGlow': w.enableGlow,
            'glowColor': '#${w.glowColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            'glowRadius': w.glowRadius,
          });
        }
        data['words'] = words;
      }
      slideData.add(data);
    }

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
          // --- Per-word mode ---
          if (slide.useWordMode && slide.wordTokens.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTap: isExport ? null : () {
                    setState(() => _selectedWordIndices.clear());
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: List.generate(slide.wordTokens.length, (i) {
                      final word = slide.wordTokens[i];
                      final bool isSelected = !isExport && _selectedWordIndices.contains(i);
                      return Align(
                        alignment: word.position,
                        child: GestureDetector(
                          onTap: isExport ? null : () {
                            setState(() {
                              if (_multiSelectMode) {
                                if (_selectedWordIndices.contains(i)) {
                                  _selectedWordIndices.remove(i);
                                } else {
                                  _selectedWordIndices.add(i);
                                }
                              } else {
                                if (_selectedWordIndices.contains(i) && _selectedWordIndices.length == 1) {
                                  _selectedWordIndices.clear();
                                } else {
                                  _selectedWordIndices.clear();
                                  _selectedWordIndices.add(i);
                                }
                              }
                            });
                          },
                          onPanUpdate: isExport ? null : (details) {
                            setState(() {
                              if (!_selectedWordIndices.contains(i)) {
                                _selectedWordIndices.clear();
                                _selectedWordIndices.add(i);
                              }

                              final double deltaX = details.delta.dx / (constraints.maxWidth / 2);
                              final double deltaY = details.delta.dy / (constraints.maxHeight / 2);

                              // Apply delta to ALL selected words
                              for (int index in _selectedWordIndices) {
                                final w = slide.wordTokens[index];
                                w.position = Alignment(
                                  (w.position.x + deltaX).clamp(-1.0, 1.0),
                                  (w.position.y + deltaY).clamp(-1.0, 1.0),
                                );
                              }
                            });
                          },
                          onPanEnd: (_) {},
                          onPanCancel: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: isSelected ? BoxDecoration(
                              border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
                              borderRadius: BorderRadius.circular(6),
                            ) : null,
                            child: Transform.rotate(
                              angle: word.rotation * math.pi / 180,
                              child: Text(
                                word.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: word.color,
                                  fontSize: isExport ? word.fontSize * (1080 / constraints.maxWidth) : word.fontSize,
                                  fontFamily: word.font?.family ?? _selectedFont?.family,
                                  fontWeight: word.font?.weight ?? _selectedFont?.weight ?? FontWeight.bold,
                                  shadows: [
                                    if (word.enableShadow)
                                      Shadow(
                                        color: word.shadowColor,
                                        offset: word.shadowOffset,
                                        blurRadius: word.shadowBlur,
                                      ),
                                    if (word.enableGlow)
                                      Shadow(
                                        color: word.glowColor,
                                        offset: Offset.zero,
                                        blurRadius: word.glowRadius,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            )
          // --- Classic single-text mode ---
          else if (slide.text.isNotEmpty && !slide.useWordMode)
            LayoutBuilder(
              builder: (context, constraints) {
                // Update tracked dimensions (avoid setState inside builder)
                _lastPreviewWidth = constraints.maxWidth;
                _lastPreviewHeight = constraints.maxHeight;

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
                        onPanEnd: (_) {},
                        onPanCancel: () {},
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            slide.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: slide.textColor,
                              fontSize: 28,
                              fontFamily: slide.font?.family ?? _selectedFont?.family,
                              fontWeight: slide.font?.weight ?? _selectedFont?.weight ?? FontWeight.bold,
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
          
          // --- Snapping Guides ---
          if (!isExport && _snapLineX != null)
            IgnorePointer(
              child: Align(
                alignment: Alignment(_snapLineX!, 0),
                child: Container(width: 1.0, color: const Color(0xFF00796B).withValues(alpha: 0.5)),
              ),
            ),
          if (!isExport && _snapLineY != null)
            IgnorePointer(
              child: Align(
                alignment: Alignment(0, _snapLineY!),
                child: Container(height: 1.0, color: const Color(0xFF00796B).withValues(alpha: 0.5)),
              ),
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
    final current = _slides[_currentIndex];
    switch (_selectedTabIndex) {
      case 0: return _buildImageTab();
      case 1: return _buildTextTab();
      case 2: return _buildPositionTab();
      case 3: return _buildFontTab();
      case 4: return _buildEffectsTab();
      case 5: return _buildStyleTab();
      case 6: return _buildSettingsTab();
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
    final slide = _slides[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Text Content'),
        TextField(
          controller: TextEditingController(text: slide.text)
            ..selection = TextSelection.collapsed(offset: slide.text.length),
          onChanged: (val) {
            setState(() => slide.text = val);
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
        // --- Word mode controls ---
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: slide.text.trim().isEmpty ? null : () {
                  setState(() {
                    slide.splitTextIntoTokens(
                      containerWidth: _lastPreviewWidth,
                      containerHeight: _lastPreviewHeight,
                      defaultFont: _selectedFont,
                    );
                    _selectedWordIndices.clear();
                  });
                },
                icon: const Icon(Icons.space_bar, size: 18),
                label: Text(slide.useWordMode ? 'Re-split Words' : 'Split to Words', style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                  foregroundColor: const Color(0xFF6C63FF),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (slide.useWordMode) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    slide.useWordMode = false;
                    slide.wordTokens.clear();
                    _selectedWordIndices.clear();
                  });
                },
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Classic', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  foregroundColor: Colors.orange,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
        // --- Word selector chips ---
        if (slide.useWordMode && slide.wordTokens.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildWordSelector(slide),
        ],
        if (!slide.useWordMode) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tip: Drag text on the image to position it.', 
                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
              TextButton.icon(
                onPressed: () => setState(() => slide.textAlignment = Alignment.center),
                icon: const Icon(Icons.center_focus_weak, size: 14),
                label: const Text('Reset Position', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
            ],
          ),
        ],
        // --- Bulk paste button ---
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showBulkPasteDialog,
            icon: const Icon(Icons.content_paste_go, size: 16),
            label: const Text('Bulk Paste (one line per slide)', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordSelector(CarouselSlide slide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Select Word'),
            Row(
              children: [
                Text('Multi', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Switch(
                  value: _multiSelectMode,
                  onChanged: (v) => setState(() => _multiSelectMode = v),
                  activeColor: const Color(0xFF6C63FF),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedWordIndices.addAll(List.generate(slide.wordTokens.length, (i) => i));
                  }),
                  child: const Text('All', style: TextStyle(fontSize: 10)),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedWordIndices.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 10, color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(slide.wordTokens.length, (i) {
                final bool isSel = _selectedWordIndices.contains(i);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (_multiSelectMode) {
                        if (_selectedWordIndices.contains(i)) {
                          _selectedWordIndices.remove(i);
                        } else {
                          _selectedWordIndices.add(i);
                        }
                      } else {
                        _selectedWordIndices.clear();
                        _selectedWordIndices.add(i);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF6C63FF) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? const Color(0xFF6C63FF) : Colors.grey[300]!),
                      ),
                      child: Text(
                        slide.wordTokens[i].text,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (_selectedWordIndices.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildWordPropertyControls(slide.wordTokens[_selectedWordIndices.first]),
        ],
      ],
    );
  }

  Widget _buildWordPropertyControls(WordToken firstWord) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Font Size
        Row(
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.text_fields, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            const Text('Size', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: firstWord.fontSize,
                  min: 10,
                  max: 80,
                  onChanged: (v) => setState(() {
                    for (int idx in _selectedWordIndices) {
                      _slides[_currentIndex].wordTokens[idx].fontSize = v;
                    }
                  }),
                ),
              ),
            ),
            Text('${firstWord.fontSize.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        // Rotation
        Row(
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.rotate_right, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            const Text('Rotate', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: firstWord.rotation,
                  min: -180,
                  max: 180,
                  onChanged: (v) => setState(() {
                    for (int idx in _selectedWordIndices) {
                      _slides[_currentIndex].wordTokens[idx].rotation = v;
                    }
                  }),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF6C63FF)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Reset Rotation',
              onPressed: () => setState(() {
                for (int idx in _selectedWordIndices) {
                  _slides[_currentIndex].wordTokens[idx].rotation = 0.0;
                }
              }),
            ),
            const SizedBox(width: 8),
            Text('${firstWord.rotation.toInt()}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        // Reset position
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                for (int idx in _selectedWordIndices) {
                  final word = _slides[_currentIndex].wordTokens[idx];
                  word.position = word.originalPosition ?? Alignment.center;
                  word.rotation = 0.0; // Reset rotation too for a clean reset
                }
              }),
              icon: const Icon(Icons.history, size: 14),
              label: const Text('Reset to Split', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionTab() {
    final slide = _slides[_currentIndex];

    if (!slide.useWordMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Text Alignment'),
          _buildPositionControls(
            label: 'Presets',
            current: slide.textAlignment,
            onChanged: (val) => setState(() => slide.textAlignment = val),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Drag text on the canvas for free positioning\nor use presets above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      );
    }

    final bool wordSelected = slide.useWordMode && _selectedWordIndices.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWordSelector(slide),
        if (wordSelected) ...[
          const Divider(height: 32),
          _buildPositionControls(
            label: 'Word Position',
            current: slide.wordTokens[_selectedWordIndices.first].position,
            onChanged: (val) => setState(() {
              for (int idx in _selectedWordIndices) {
                slide.wordTokens[idx].position = val;
              }
            }),
          ),
        ] else ...[
          const SizedBox(height: 48),
          const Center(
            child: Text(
              'Select a word above or on the canvas\nto adjust its position.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPositionControls({
    required String label,
    required Alignment current,
    required ValueChanged<Alignment> onChanged,
  }) {
    final presets = [
      {'label': 'Center', 'alignment': Alignment.center},
      {'label': 'Top', 'alignment': Alignment.topCenter},
      {'label': 'Bottom', 'alignment': Alignment.bottomCenter},
      {'label': 'Left', 'alignment': Alignment.centerLeft},
      {'label': 'Right', 'alignment': Alignment.centerRight},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((preset) {
              final Alignment target = preset['alignment'] as Alignment;
              final bool isSelected = current == target;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(target),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6C63FF).withValues(alpha: 0.12) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[300]!),
                    ),
                    child: Text(
                      preset['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fine Tune', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'X: ${current.x.toStringAsFixed(3)}\nY: ${current.y.toStringAsFixed(3)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontFamily: 'monospace', height: 1.5),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildCompactNudgeButton(Icons.keyboard_arrow_up, () => onChanged(Alignment(current.x, (current.y - 0.01).clamp(-1.0, 1.0)))),
                Row(
                  children: [
                    _buildCompactNudgeButton(Icons.keyboard_arrow_left, () => onChanged(Alignment((current.x - 0.01).clamp(-1.0, 1.0), current.y))),
                    _buildCompactNudgeButton(Icons.adjust, () => onChanged(Alignment.center), isCenter: true),
                    _buildCompactNudgeButton(Icons.keyboard_arrow_right, () => onChanged(Alignment((current.x + 0.01).clamp(-1.0, 1.0), current.y))),
                  ],
                ),
                _buildCompactNudgeButton(Icons.keyboard_arrow_down, () => onChanged(Alignment(current.x, (current.y + 0.01).clamp(-1.0, 1.0)))),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactNudgeButton(IconData icon, VoidCallback action, {bool isCenter = false}) {
    return GestureDetector(
      onTapDown: (_) {
        setState(action);
        if (!isCenter) {
          _nudgeTimer?.cancel();
          _nudgeTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
            if (t.tick > 4) setState(action);
          });
        }
      },
      onTapUp: (_) => _nudgeTimer?.cancel(),
      onTapCancel: () => _nudgeTimer?.cancel(),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isCenter ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(icon, size: isCenter ? 18 : 22, color: isCenter ? Colors.blue : Colors.grey[700]),
      ),
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
    final bool wordMode = current.useWordMode && _selectedWordIndices.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(wordMode ? 'Font for ${_selectedWordIndices.length} words' : 'Typography'),
        HorizontalFontSelector(
          selectedFont: (wordMode ? current.wordTokens[_selectedWordIndices.first].font : current.font) ?? _selectedFont,
          onFontSelected: (font) {
            setState(() {
              if (wordMode) {
                for (int idx in _selectedWordIndices) {
                  current.wordTokens[idx].font = font;
                }
              } else {
                current.font = font;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        // Upload Custom Font button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.any,
                allowMultiple: true,
              );
              if (result != null && result.files.isNotEmpty) {
                CustomFontEntry? lastEntry;
                for (final xFile in result.files) {
                  if (xFile.path == null) continue;
                  final path = xFile.path!;
                  if (!path.toLowerCase().endsWith('.ttf') && !path.toLowerCase().endsWith('.otf')) {
                    continue;
                  }
                  final file = File(path);
                  final entry = await CustomFontManager().addFont(file);
                  if (entry != null) lastEntry = entry;
                }

                if (lastEntry != null && mounted) {
                  final newFont = FontInfo(
                    family: lastEntry.familyName,
                    displayName: lastEntry.displayName,
                    isCustom: true,
                    filePath: lastEntry.filePath,
                  );
                  setState(() {
                    if (wordMode) {
                      for (int idx in _selectedWordIndices) {
                        current.wordTokens[idx].font = newFont;
                      }
                    } else {
                      current.font = newFont;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Imported ${result.files.length} font(s)')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Upload Custom Font', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              foregroundColor: Colors.blue,
              side: BorderSide(color: Colors.blue[200]!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEffectsTab() {
    CarouselSlide current = _slides[_currentIndex];
    final bool wordMode = current.useWordMode && _selectedWordIndices.isNotEmpty;
    
    // Target either the first selected word or the slide defaults for preview
    final bool enableShadow = wordMode ? current.wordTokens[_selectedWordIndices.first].enableShadow : current.enableShadow;
    final double shadowBlur = wordMode ? current.wordTokens[_selectedWordIndices.first].shadowBlur : current.shadowBlur;
    final Offset shadowOffset = wordMode ? current.wordTokens[_selectedWordIndices.first].shadowOffset : current.shadowOffset;
    final bool enableGlow = wordMode ? current.wordTokens[_selectedWordIndices.first].enableGlow : current.enableGlow;
    final double glowRadius = wordMode ? current.wordTokens[_selectedWordIndices.first].glowRadius : current.glowRadius;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(wordMode ? 'Effects for ${_selectedWordIndices.length} words' : 'Text Styling'),
        SwitchListTile(
          title: const Text('Drop Shadow', style: TextStyle(fontSize: 12)),
          value: enableShadow,
          onChanged: (v) => setState(() {
            if (wordMode) {
              for (int idx in _selectedWordIndices) {
                current.wordTokens[idx].enableShadow = v;
              }
            } else {
              current.enableShadow = v;
            }
          }),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (enableShadow) ...[
          _buildEffectSlider('Blur', shadowBlur, 0, 20, (v) => setState(() {
            if (wordMode) {
              for (int idx in _selectedWordIndices) {
                current.wordTokens[idx].shadowBlur = v;
              }
            } else {
              current.shadowBlur = v;
            }
          })),
          _buildEffectSlider('Offset X', shadowOffset.dx, -10, 10, (v) => setState(() {
            if (wordMode) {
              for (int idx in _selectedWordIndices) {
                current.wordTokens[idx].shadowOffset = Offset(v, current.wordTokens[idx].shadowOffset.dy);
              }
            } else {
              current.shadowOffset = Offset(v, current.shadowOffset.dy);
            }
          })),
          _buildEffectSlider('Offset Y', shadowOffset.dy, -10, 10, (v) => setState(() {
            if (wordMode) {
              for (int idx in _selectedWordIndices) {
                current.wordTokens[idx].shadowOffset = Offset(current.wordTokens[idx].shadowOffset.dx, v);
              }
            } else {
              current.shadowOffset = Offset(current.shadowOffset.dx, v);
            }
          })),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Glow Effect', style: TextStyle(fontSize: 12)),
          value: enableGlow,
          onChanged: (v) => setState(() {
            if (wordMode) {
              for (int idx in _selectedWordIndices) {
                current.wordTokens[idx].enableGlow = v;
              }
            } else {
              current.enableGlow = v;
            }
          }),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (enableGlow) ...[
          _buildEffectSlider('Radius', glowRadius, 0, 30, (v) => setState(() {
            if (wordMode) {
              for (int idx in _selectedWordIndices) {
                current.wordTokens[idx].glowRadius = v;
              }
            } else {
              current.glowRadius = v;
            }
          })),
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
    final bool wordMode = current.useWordMode && _selectedWordIndices.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Slide Background'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCustomColorButton(true),
              _buildColorOption(const Color(0xFF121212), Colors.white, 'Ink', true),
              _buildColorOption(Colors.white, const Color(0xFF121212), 'Snow', true),
              _buildColorOption(const Color(0xFFFF4E50), Colors.white, 'Sunset', true),
              _buildColorOption(const Color(0xFF6C63FF), Colors.white, 'Royal', true),
              _buildColorOption(const Color(0xFF00D2FF), Colors.white, 'Ocean', true),
              _buildColorOption(const Color(0xFFFC67FA), Colors.white, 'Electric', true),
              _buildColorOption(const Color(0xFF00F260), const Color(0xFF121212), 'Cyber', true),
              _buildColorOption(const Color(0xFFFDC830), const Color(0xFF121212), 'Gold', true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader(wordMode ? 'Color for ${_selectedWordIndices.length} words' : 'Text Color'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCustomColorButton(false),
              _buildTextVariant(Colors.white, 'Bright'),
              _buildTextVariant(const Color(0xFF121212), 'Dark'),
              _buildTextVariant(const Color(0xFFFF4E50), 'Sunset'),
              _buildTextVariant(const Color(0xFF6C63FF), 'Royal'),
              _buildTextVariant(const Color(0xFF00D2FF), 'Ocean'),
              _buildTextVariant(const Color(0xFFFC67FA), 'Neon'),
              _buildTextVariant(const Color(0xFF00F260), 'Cyber'),
              _buildTextVariant(const Color(0xFFFDC830), 'Gold'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextVariant(Color color, String label) {
    final current = _slides[_currentIndex];
    final bool wordMode = current.useWordMode && _selectedWordIndices.isNotEmpty;
    final Color activeColor = wordMode ? current.wordTokens[_selectedWordIndices.first].color : current.textColor;
    bool isSel = activeColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (wordMode) {
            for (int idx in _selectedWordIndices) {
              current.wordTokens[idx].color = color;
            }
          } else {
            current.textColor = color;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? const Color(0xFF6C63FF) : Colors.grey[200]!,
                  width: isSel ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSel
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSel ? const Color(0xFF6C63FF) : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
          if (current.textColor == Colors.white || current.textColor == const Color(0xFF121212)) {
            current.textColor = text;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? const Color(0xFF6C63FF) : Colors.grey[200]!,
                  width: isSel ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSel
                  ? Icon(Icons.check, size: 16, color: text)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSel ? const Color(0xFF6C63FF) : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.colorize_rounded, size: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 6),
            Text(
              'Custom',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(bool isBg) async {
    final slide = _slides[_currentIndex];
    final bool wordMode = slide.useWordMode && _selectedWordIndices.isNotEmpty;
    
    Color initialColor = isBg 
        ? slide.bgColor 
        : (wordMode ? slide.wordTokens[_selectedWordIndices.first].color : slide.textColor);
    
    Color selectedColor = initialColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isBg ? 'Background Color' : 'Text Color', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SELECT COLOR', style: TextStyle(fontWeight: FontWeight.bold)),
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
      {'icon': Icons.photo_library_outlined, 'label': 'Image', 'color': Colors.blue},
      {'icon': Icons.title_rounded, 'label': 'Text', 'color': Colors.amber},
      {'icon': Icons.open_with, 'label': 'Position', 'color': Colors.indigo},
      {'icon': Icons.font_download_outlined, 'label': 'Font', 'color': Colors.green},
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
        backgroundColor: color.withValues(alpha: 0.08),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
