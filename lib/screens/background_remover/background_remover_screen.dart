import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../config/app_theme.dart';
import '../../utils/background_remover.dart';
import '../../widgets/advanced_color_picker.dart';
import '../../utils/font_selector.dart';
import '../../utils/custom_font_manager.dart';
import '../../models/word_token.dart';
enum BrushMode { erase, restore }

class BrushStroke {
  final Path path;
  final double size;
  final BrushMode mode;
  BrushStroke({required this.path, required this.size, required this.mode});
}

class DrawStroke {
  final List<Offset> points;
  final double size;
  final Color color;
  final bool isEraser;
  
  DrawStroke({required this.points, required this.size, required this.color, this.isEraser = false});
}

class BackgroundRemoverScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final File? imageFile;
  final bool isEditorMode;
  final double initialSmoothing;

  const BackgroundRemoverScreen({
    Key? key,
    this.sharedImagePaths,
    this.imageFile,
    this.isEditorMode = false,
    this.initialSmoothing = 0.0,
  }) : super(key: key);

  @override
  State<BackgroundRemoverScreen> createState() => _BackgroundRemoverScreenState();
}

class _BackgroundRemoverScreenState extends State<BackgroundRemoverScreen> {
  File? _inputImage;
  String? _outputImagePath;
  bool _isProcessing = false;
  bool _showOriginal = false;

  // Refining state
  bool _isRefining = false;
  BrushMode _brushMode = BrushMode.erase;
  double _brushSize = 20.0;
  double _brushOffset = 50.0; // Offset brush above finger

  // Freehand Drawing State
  List<DrawStroke> _freehandStrokes = [];
  DrawStroke? _currentFreehandStroke;
  bool _isDrawingMode = false;
  bool _drawIsEraser = false;
  double _drawBrushSize = 10.0;
  Color _drawColor = Colors.red;

  // Background Text State
  String _bgText = '';
  Color _bgTextColor = Colors.white;
  FontInfo? _bgTextFont;
  double _bgTextFontSize = 28.0;
  Alignment _bgTextAlignment = Alignment.center;
  bool _bgTextEnableShadow = true;
  
  List<WordToken> _bgWordTokens = [];
  bool _bgUseWordMode = false;
  WordToken? _selectedBgWordToken;

  // Cropping State
  bool _isCropping = false;
  double _cropX = 0.0;
  double _cropY = 0.0;
  double _cropWidth = 200.0;
  double _cropHeight = 200.0;
  bool _isDraggingCropBox = false;
  bool _isResizingCropBox = false;
  Offset? _lastPanPosition;

  int _selectedTabIndex = -1;
  bool _isTabContentExpanded = false;
  
  double _smoothing = 0.0;
  double _strokeWidth = 0.0;
  Color _strokeColor = Colors.white;
  Color _bgColor = Colors.transparent;
  
  int _edgePadding = 0;
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  int _outputWidth = 0;
  int _outputHeight = 0;
  double _baseScale = 1.0;
  
  double _shadowRadius = 0.0;
  Color _shadowColor = Colors.transparent;
  double _shadowDx = 0.0;
  double _shadowDy = 0.0;

  String? _bgImagePath;
  File? _bgImage;

  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  
  bool _autoTrim = false;
  
  final List<Color> _colorOptions = [
    Colors.transparent, Colors.white, Colors.black, Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.purple, Colors.orange, Colors.cyan, Colors.pink
  ];

  List<BrushStroke> _strokes = [];
  BrushStroke? _currentStroke;
  Offset? _currentTouch;
  
  ui.Image? _uiInputImage;
  ui.Image? _uiOutputImage;

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      _inputImage = widget.imageFile;
      _smoothing = widget.initialSmoothing;
      _loadUiImage(_inputImage!.path).then((uiImage) {
        if (mounted) {
          setState(() {
            _uiInputImage = uiImage;
          });
        }
      });
      // In editor mode, the image already has its background removed in Carousel, but if we want to refine it here, we should actually load it as _inputImage and let them see it. But wait, we want to refine the *original* image, so we pass the original image!
      if (widget.isEditorMode) {
        // Auto process the background removal first, then user can refine.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _removeBackground();
          if (mounted) {
            setState(() {
              _isRefining = true;
            });
          }
        });
      }
    } else if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      _inputImage = File(widget.sharedImagePaths!.first);
      _loadUiImage(_inputImage!.path).then((uiImage) {
        if (mounted) {
          setState(() {
            _uiInputImage = uiImage;
          });
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isProcessing = true);
      final uiImage = await _loadUiImage(image.path);
      setState(() {
        _inputImage = File(image.path);
        _outputImagePath = null;
        _isRefining = false;
        _strokes.clear();
        _uiInputImage = uiImage;
        _uiOutputImage = null;
        _bgImagePath = null;
        _bgImage = null;
        _isProcessing = false;
      });
      _startCropping();
    }
  }

  void _startCropping() {
    if (_uiInputImage != null) {
      setState(() {
        _isCropping = true;
        _isRefining = false;
        _selectedTabIndex = -1;
        // Initialize crop box to 80% of image size, centered
        double displayWidth = MediaQuery.of(context).size.width - 32;
        double displayHeight = 400; // max height of canvas

        double imgAspect = _uiInputImage!.width / _uiInputImage!.height;
        double canvasAspect = displayWidth / displayHeight;

        double renderedWidth = displayWidth;
        double renderedHeight = displayHeight;

        if (imgAspect > canvasAspect) {
          renderedHeight = displayWidth / imgAspect;
        } else {
          renderedWidth = displayHeight * imgAspect;
        }

        _cropWidth = renderedWidth;
        _cropHeight = renderedHeight;
        _cropX = 0;
        _cropY = 0;
      });
    } else {
      // If uiImage isn't loaded yet, just set flag, we'll initialize bounds when rendering
      setState(() {
        _isCropping = true;
        _isRefining = false;
        _selectedTabIndex = -1;
      });
    }
  }

  Future<void> _applyCrop() async {
    if (_inputImage == null || _uiInputImage == null) {
      setState(() => _isCropping = false);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      double displayWidth = MediaQuery.of(context).size.width - 32;
      double displayHeight = 400;

      double imgAspect = _uiInputImage!.width / _uiInputImage!.height;
      double canvasAspect = displayWidth / displayHeight;

      double renderedWidth = displayWidth;
      double renderedHeight = displayHeight;

      if (imgAspect > canvasAspect) {
        renderedHeight = displayWidth / imgAspect;
      } else {
        renderedWidth = displayHeight * imgAspect;
      }

      final double scaleX = _uiInputImage!.width / renderedWidth;
      final double scaleY = _uiInputImage!.height / renderedHeight;

      final int cropX = (_cropX * scaleX).round().clamp(0, _uiInputImage!.width);
      final int cropY = (_cropY * scaleY).round().clamp(0, _uiInputImage!.height);
      final int cropWidth = (_cropWidth * scaleX).round().clamp(1, _uiInputImage!.width - cropX);
      final int cropHeight = (_cropHeight * scaleY).round().clamp(1, _uiInputImage!.height - cropY);

      final List<dynamic>? results = await _channel.invokeMethod('cropImagesBatch', {
        'items': [{
          'inputPath': _inputImage!.path,
          'x': cropX,
          'y': cropY,
          'width': cropWidth,
          'height': cropHeight,
          'rotation': 0,
          'isFlipped': false,
        }]
      });

      if (results != null && results.isNotEmpty) {
        final path = results.first as String;
        final uiImage = await _loadUiImage(path);
        setState(() {
          _inputImage = File(path);
          _uiInputImage = uiImage;
          _isCropping = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crop failed: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickBackgroundImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _bgImagePath = image.path;
        _bgImage = File(image.path);
      });
    }
  }

  void _openColorPicker(Color initialColor, ValueChanged<Color> onColorChanged) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              const Text('Custom Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: AdvancedColorPicker(
                  initialColor: initialColor,
                  onColorChanged: onColorChanged,
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              )
            ],
          ),
        ),
      )
    );
  }

  Future<ui.Image> _loadUiImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _removeBackground() async {
    if (_inputImage == null) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      final outputPath = await BackgroundRemover.removeBackground(
        _inputImage!.path,
        smoothing: _smoothing,
        strokeWidth: _strokeWidth,
        strokeColor: _strokeColor.value,
        bgColor: _bgColor.value,
        edgePadding: _edgePadding,
        scale: _scale,
        offsetX: _offsetX,
        offsetY: _offsetY,
        outputWidth: _outputWidth,
        outputHeight: _outputHeight,
        shadowRadius: _shadowRadius,
        shadowColor: _shadowColor.value,
        shadowDx: _shadowDx,
        shadowDy: _shadowDy,
        bgImagePath: _bgImagePath,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        autoTrim: _autoTrim,
      );
      
      if (outputPath == null) throw Exception("Failed to process image");

      final inputUi = await _loadUiImage(_inputImage!.path);
      final outputUi = await _loadUiImage(outputPath);
      
      if (mounted) {
        setState(() {
          _outputImagePath = outputPath;
          _uiInputImage = inputUi;
          _uiOutputImage = outputUi;
          _strokes.clear();
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<String> _exportRefinedImage() async {
    if (_uiOutputImage == null || _uiInputImage == null) {
      return _outputImagePath!;
    }
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = _uiOutputImage!.width.toDouble();
    final height = _uiOutputImage!.height.toDouble();
    final rect = Rect.fromLTWH(0, 0, width, height);
    
    // Draw background color
    if (_bgColor != Colors.transparent) {
      canvas.drawRect(rect, Paint()..color = _bgColor);
    }
    
    // Draw background image
    if (_bgImage != null) {
      final bgUiImage = await _loadUiImage(_bgImage!.path);
      paintImage(
        canvas: canvas,
        rect: rect,
        image: bgUiImage,
        fit: BoxFit.cover,
      );
    }

    // Draw background text
    if (_bgUseWordMode) {
      for (var token in _bgWordTokens) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: token.text,
            style: TextStyle(
              fontSize: token.fontSize,
              color: token.color,
              fontFamily: token.font?.family,
              fontWeight: token.font?.weight ?? FontWeight.bold,
              shadows: token.enableShadow
                  ? [Shadow(blurRadius: token.shadowBlur, color: token.shadowColor, offset: token.shadowOffset)]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout();
        
        // Convert alignment back to pixels
        // childLeft = (containerW - childW) * (x + 1) / 2
        double x = (width - textPainter.width) * (token.position.x + 1) / 2;
        double y = (height - textPainter.height) * (token.position.y + 1) / 2;
        
        canvas.save();
        canvas.translate(x + textPainter.width / 2, y + textPainter.height / 2);
        canvas.rotate(token.rotation * pi / 180);
        canvas.translate(-(x + textPainter.width / 2), -(y + textPainter.height / 2));
        textPainter.paint(canvas, Offset(x, y));
        canvas.restore();
      }
    } else if (_bgText.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: _bgText,
          style: TextStyle(
            fontSize: _bgTextFontSize,
            color: _bgTextColor,
            fontFamily: _bgTextFont?.family,
            fontWeight: _bgTextFont?.weight ?? FontWeight.bold,
            shadows: _bgTextEnableShadow
                ? [const Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(2, 2))]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      // We assume a 32px total horizontal padding in UI (16 left + 16 right)
      textPainter.layout(maxWidth: width - 32);
      
      // Calculate position based on _bgTextAlignment
      double x = 16.0; // Base padding
      double y = 16.0;
      
      if (_bgTextAlignment.x == 0) {
        x = (width - textPainter.width) / 2;
      } else if (_bgTextAlignment.x > 0) {
        x = width - textPainter.width - 16;
      }
      
      if (_bgTextAlignment.y == 0) {
        y = (height - textPainter.height) / 2;
      } else if (_bgTextAlignment.y > 0) {
        y = height - textPainter.height - 16;
      }
      
      textPainter.paint(canvas, Offset(x, y));
    }

    // Draw everything else using RefinerPainter to match UI exactly
    final refiner = RefinerPainter(
      outputImage: _uiOutputImage,
      inputImage: _uiInputImage,
      strokes: _strokes,
      currentStroke: null,
      freehandStrokes: _freehandStrokes,
      currentFreehandStroke: null,
      currentTouch: null,
      brushSize: 0,
      brushOffset: 0,
      strokeColor: _strokeColor,
      strokeWidth: _strokeWidth,
      scale: _scale,
      offsetX: _offsetX,
      offsetY: _offsetY,
      shadowRadius: _shadowRadius,
      shadowColor: _shadowColor,
      shadowDx: _shadowDx,
      shadowDy: _shadowDy,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
    );

    refiner.paint(canvas, Size(width, height));
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/refined_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(buffer);
    return file.path;
  }

  void _shareOrSave() async {
    if (_outputImagePath != null) {
      setState(() => _isProcessing = true);
      final finalPath = await _exportRefinedImage();
      setState(() => _isProcessing = false);
      Share.shareXFiles([XFile(finalPath)], text: 'Background removed with QuickPost');
    }
  }

  Future<void> _saveToGallery() async {
    if (_outputImagePath == null) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final finalPath = await _exportRefinedImage();
      final result = await _channel.invokeMethod<String>('saveImageToGallery', {'imagePath': finalPath});
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Gallery: ${result?.split('/').last ?? "Image"}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Word mode text splitting logic
  void _splitTextIntoTokens() {
    if (_bgText.trim().isEmpty) return;
    
    // We assume layout width is exactly the image width minus padding
    double containerWidth = _outputWidth > 0 ? _outputWidth.toDouble() : MediaQuery.of(context).size.width;
    double containerHeight = _outputHeight > 0 ? _outputHeight.toDouble() : MediaQuery.of(context).size.width; // rough approx for height
    
    // Fallback if size isn't initialized properly
    if (containerWidth <= 0) containerWidth = 300;
    if (containerHeight <= 0) containerHeight = 300;

    _bgWordTokens.clear();
    final double baseX = _bgTextAlignment.x;
    final double baseY = _bgTextAlignment.y;

    final TextStyle style = TextStyle(
      fontSize: _bgTextFontSize,
      fontFamily: _bgTextFont?.family,
      fontWeight: _bgTextFont?.weight ?? FontWeight.bold,
    );

    final fullPainter = TextPainter(
      text: TextSpan(text: _bgText, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: (containerWidth - 32).clamp(0, double.infinity));

    final double fullTextWidth = fullPainter.width;
    final double fullTextHeight = fullPainter.height;

    const double pad = 16.0;
    final double classicChildW = fullTextWidth + pad * 2;
    final double classicChildH = fullTextHeight + pad * 2;

    final double blockLeft = (containerWidth - classicChildW) * (baseX + 1) / 2;
    final double blockTop = (containerHeight - classicChildH) * (baseY + 1) / 2;

    final double textContentLeft = blockLeft + pad;
    final double textContentTop = blockTop + pad;

    final wordRegex = RegExp(r'\S+');
    final matches = wordRegex.allMatches(_bgText);

    const double wordPadH = 6.0;
    const double wordPadV = 2.0;

    for (final match in matches) {
      final String wordStr = match.group(0)!;
      final range = TextSelection(baseOffset: match.start, extentOffset: match.end);
      final boxes = fullPainter.getBoxesForSelection(range);

      if (boxes.isEmpty) continue;

      final box = boxes.first;

      final double wordWidgetLeft = textContentLeft + box.left - wordPadH;
      final double wordWidgetTop = textContentTop + box.top - wordPadV;

      final double wordChildW = (box.right - box.left) + wordPadH * 2;
      final double wordChildH = (box.bottom - box.top) + wordPadV * 2;

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
      _bgWordTokens.add(WordToken(
        text: wordStr,
        position: pos,
        originalPosition: pos,
        fontSize: _bgTextFontSize,
        color: _bgTextColor,
        font: _bgTextFont,
        rotation: 0.0,
        enableShadow: _bgTextEnableShadow,
      ));
    }

    setState(() {
      _bgUseWordMode = true;
      _selectedBgWordToken = null;
    });
  }

  Widget _buildControlTabs() {
    if (_isCropping) {
      return Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _isCropping = false),
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: _applyCrop,
              icon: const Icon(Icons.check),
              label: const Text('Apply Crop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildTabItem(-1, Icons.add_photo_alternate, 'Pick Image', AppColors.primary, _isProcessing ? null : _pickImage),
          _buildTabItem(-7, Icons.crop, 'Crop', Colors.orange, _inputImage == null || _isProcessing ? null : _startCropping),
          _buildTabItem(-2, Icons.auto_fix_high, 'Remove BG', AppColors.primary, _inputImage == null || _isProcessing ? null : _removeBackground),
          GestureDetector(
            onLongPressStart: (_) => setState(() => _showOriginal = true),
            onLongPressEnd: (_) => setState(() => _showOriginal = false),
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: _buildTabItem(
              -3,
              Icons.compare, 
              _showOriginal ? 'Original' : 'Compare', 
              _showOriginal ? Colors.green : Colors.deepPurple, 
              null
            ),
          ),
          _buildTabItem(0, Icons.format_color_fill, 'Background', Colors.blue, null),
          _buildTabItem(1, Icons.border_outer, 'Stroke', Colors.orange, null),
          _buildTabItem(2, Icons.blur_on, 'Smooth', Colors.cyan, null),
          _buildTabItem(4, Icons.layers, 'Shadow', Colors.indigo, null),
          _buildTabItem(5, Icons.tune, 'Filters', Colors.teal, null),
          _buildTabItem(6, Icons.draw, 'Draw', Colors.red, null),
          _buildTabItem(7, Icons.text_fields, 'Text', Colors.pink, null),
          _buildTabItem(3, Icons.aspect_ratio, 'Layout', Colors.purple, null),
          _buildTabItem(-4, Icons.brush, 'Refine', AppColors.primary, () => setState(() => _isRefining = true)),
          _buildTabItem(-5, Icons.share, 'Share', Colors.blueAccent, _isProcessing ? null : _shareOrSave),
          _buildTabItem(-6, Icons.save_alt, 'Save', Colors.green, _isProcessing ? null : _saveToGallery),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return Container(
      height: 180,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0: // Background
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Background Color & Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _pickBackgroundImage,
                  icon: const Icon(Icons.image, size: 16),
                  label: const Text('Pick Image'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                ),
                if (_bgImage != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() {
                      _bgImage = null;
                      _bgImagePath = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openColorPicker(_bgColor, (color) => setState(() => _bgColor = color)),
                    child: Container(
                      width: 40, height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Icon(Icons.colorize, color: Colors.white, size: 20),
                    ),
                  ),
                  ..._colorOptions.map((color) => GestureDetector(
                    onTap: () => setState(() => _bgColor = color),
                    child: Container(
                      width: 40, height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _bgColor == color ? AppColors.primary : Colors.grey, width: _bgColor == color ? 3 : 1),
                      ),
                      child: color == Colors.transparent ? const Icon(Icons.format_color_reset, size: 20) : null,
                    ),
                  )),
                ],
              ),
            ),
          ],
        );
      case 1: // Stroke
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Stroke Width', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 0, max: 50,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openColorPicker(_strokeColor, (color) => setState(() => _strokeColor = color)),
                    child: Container(
                      width: 30, height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Icon(Icons.colorize, color: Colors.white, size: 16),
                    ),
                  ),
                  ..._colorOptions.where((c) => c != Colors.transparent).map((color) => GestureDetector(
                    onTap: () => setState(() => _strokeColor = color),
                    child: Container(
                      width: 30, height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _strokeColor == color ? AppColors.primary : Colors.grey, width: _strokeColor == color ? 3 : 1),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        );
      case 2: // Smooth
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Edge Smoothing', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _smoothing,
                    min: 0, max: 20,
                    onChangeEnd: (_) => _removeBackground(), // Re-run segmentation to apply native smoothing
                    onChanged: (v) => setState(() => _smoothing = v),
                  ),
                ),
              ],
            ),
            const Text('Note: Smoothing requires re-processing the image.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
      case 3: // Layout
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Edge Expand', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: _edgePadding.toDouble(),
                    min: 0, max: 200,
                    onChangeEnd: (_) => _removeBackground(),
                    onChanged: (v) => setState(() => _edgePadding = v.toInt()),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transform', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Auto-Trim', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _autoTrim,
                      onChanged: (v) => setState(() => _autoTrim = v),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _scale = 1.0;
                        _offsetX = 0.0;
                        _offsetY = 0.0;
                      }),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                )
              ],
            ),
            const Text('Drag and pinch the image preview to position the cutout.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
      case 4: // Shadow
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Blur', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Slider(value: _shadowRadius, min: 0, max: 50, onChanged: (v) => setState(() => _shadowRadius = v))),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Offset X', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Slider(value: _shadowDx, min: -50, max: 50, onChanged: (v) => setState(() => _shadowDx = v))),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Offset Y', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Slider(value: _shadowDy, min: -50, max: 50, onChanged: (v) => setState(() => _shadowDy = v))),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openColorPicker(_shadowColor, (color) => setState(() => _shadowColor = color)),
                    child: Container(
                      width: 30, height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Icon(Icons.colorize, color: Colors.white, size: 16),
                    ),
                  ),
                  ..._colorOptions.where((c) => c != Colors.transparent).map((color) => GestureDetector(
                    onTap: () => setState(() => _shadowColor = color),
                    child: Container(
                      width: 30, height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _shadowColor == color ? AppColors.primary : Colors.grey, width: _shadowColor == color ? 3 : 1),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        );
      case 5: // Filters
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Brightness', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Slider(value: _brightness, min: -1, max: 1, onChanged: (v) => setState(() => _brightness = v))),
              ],
            ),
            Row(
              children: [
                const Text('Contrast', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Slider(value: _contrast, min: 0, max: 2, onChanged: (v) => setState(() => _contrast = v))),
              ],
            ),
            Row(
              children: [
                const Text('Saturation', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Slider(value: _saturation, min: 0, max: 2, onChanged: (v) => setState(() => _saturation = v))),
              ],
            ),
          ],
        );
      case 6: // Draw
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Draw Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Switch(value: _isDrawingMode, onChanged: (v) => setState(() => _isDrawingMode = v)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.undo), onPressed: _freehandStrokes.isNotEmpty ? () => setState(() => _freehandStrokes.removeLast()) : null),
                IconButton(
                  icon: Icon(_drawIsEraser ? Icons.cleaning_services : Icons.edit, color: _drawIsEraser ? Colors.red : AppColors.primary),
                  onPressed: () => setState(() => _drawIsEraser = !_drawIsEraser),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 60, child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Slider(value: _drawBrushSize, min: 2, max: 50, onChanged: (v) => setState(() => _drawBrushSize = v))),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openColorPicker(_drawColor, (color) => setState(() => _drawColor = color)),
                    child: Container(
                      width: 30, height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Icon(Icons.colorize, color: Colors.white, size: 16),
                    ),
                  ),
                  ..._colorOptions.where((c) => c != Colors.transparent).map((color) => GestureDetector(
                    onTap: () => setState(() => _drawColor = color),
                    child: Container(
                      width: 30, height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _drawColor == color ? AppColors.primary : Colors.grey, width: _drawColor == color ? 3 : 1),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        );
      case 7: // Text
        final isWordMode = _bgUseWordMode;
        final selectedToken = _selectedBgWordToken;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Enter background text',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _bgText = val;
                        if (_bgUseWordMode) _bgUseWordMode = false; // Reset if they edit text
                      });
                    },
                    controller: TextEditingController(text: _bgText)..selection = TextSelection.fromPosition(TextPosition(offset: _bgText.length)),
                  ),
                ),
                if (!isWordMode && _bgText.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: _splitTextIntoTokens,
                      child: const Text('Split'),
                    ),
                  ),
                if (isWordMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () => setState(() => _bgUseWordMode = false),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Reset', style: TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Size', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Slider(
                  value: (selectedToken?.fontSize ?? _bgTextFontSize).clamp(10, 100), 
                  min: 10, 
                  max: 100, 
                  onChanged: (v) => setState(() {
                    if (selectedToken != null) {
                      selectedToken.fontSize = v;
                    } else {
                      _bgTextFontSize = v;
                    }
                  })
                )),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Shadow', style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: selectedToken?.enableShadow ?? _bgTextEnableShadow, 
                      onChanged: (v) => setState(() {
                        if (selectedToken != null) {
                          selectedToken.enableShadow = v;
                        } else {
                          _bgTextEnableShadow = v;
                        }
                      })
                    ),
                  ],
                ),
                DropdownButton<Alignment>(
                  value: _bgTextAlignment,
                  items: const [
                    DropdownMenuItem(value: Alignment.topLeft, child: Text('Top Left')),
                    DropdownMenuItem(value: Alignment.topCenter, child: Text('Top Center')),
                    DropdownMenuItem(value: Alignment.topRight, child: Text('Top Right')),
                    DropdownMenuItem(value: Alignment.centerLeft, child: Text('Center Left')),
                    DropdownMenuItem(value: Alignment.center, child: Text('Center')),
                    DropdownMenuItem(value: Alignment.centerRight, child: Text('Center Right')),
                    DropdownMenuItem(value: Alignment.bottomLeft, child: Text('Bottom Left')),
                    DropdownMenuItem(value: Alignment.bottomCenter, child: Text('Bottom Center')),
                    DropdownMenuItem(value: Alignment.bottomRight, child: Text('Bottom Right')),
                  ],
                  onChanged: isWordMode ? null : (v) {
                    if (v != null) setState(() => _bgTextAlignment = v);
                  },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openColorPicker(selectedToken?.color ?? _bgTextColor, (color) => setState(() {
                            if (selectedToken != null) {
                              selectedToken.color = color;
                            } else {
                              _bgTextColor = color;
                            }
                          })),
                          child: Container(
                            width: 30, height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 1),
                            ),
                            child: const Icon(Icons.colorize, color: Colors.white, size: 16),
                          ),
                        ),
                        ..._colorOptions.map((color) => GestureDetector(
                          onTap: () => setState(() {
                            if (selectedToken != null) {
                              selectedToken.color = color;
                            } else {
                              _bgTextColor = color;
                            }
                          }),
                          child: Container(
                            width: 30, height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: (selectedToken?.color ?? _bgTextColor) == color ? AppColors.primary : Colors.grey, width: (selectedToken?.color ?? _bgTextColor) == color ? 3 : 1),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final font = await showDialog<FontInfo>(
                      context: context,
                      builder: (_) => Dialog(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: FontSelector(
                            selectedFont: selectedToken?.font ?? _bgTextFont,
                            onFontSelected: (f) => Navigator.pop(context, f),
                          ),
                        ),
                      ),
                    );
                    if (font != null) {
                      setState(() {
                        if (selectedToken != null) {
                          selectedToken.font = font;
                        } else {
                          _bgTextFont = font;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.font_download, size: 16),
                  label: const Text('Font'),
                ),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color, VoidCallback? onTap) {
    final isSelected = _selectedTabIndex == index;
    Widget child = Container(
      width: 75,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? color : Colors.grey[600], size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? color : Colors.grey[600],
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap ?? () {
        setState(() {
          if (_selectedTabIndex == index) {
            _isTabContentExpanded = !_isTabContentExpanded;
          } else {
            _selectedTabIndex = index;
            _isTabContentExpanded = true;
          }
        });
      },
      child: child,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_isRefining) return;
    _baseScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isRefining) return;
    setState(() {
      _scale = (_baseScale * details.scale).clamp(0.1, 5.0);
      _offsetX += details.focalPointDelta.dx;
      _offsetY += details.focalPointDelta.dy;
    });
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_uiOutputImage == null) return;
    if (_isRefining) {
      _startStroke(details.localPosition, constraints);
    } else if (_isDrawingMode) {
      _startFreehandStroke(details.localPosition, constraints);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_uiOutputImage == null) return;
    if (_isRefining) {
      _updateStroke(details.localPosition, constraints);
    } else if (_isDrawingMode) {
      _updateFreehandStroke(details.localPosition, constraints);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isRefining) {
      _endStroke();
    } else if (_isDrawingMode) {
      _endFreehandStroke();
    }
  }

  Offset _screenToImage(Offset screenPos, BoxConstraints constraints) {
    final Size size = Size(constraints.maxWidth, constraints.maxHeight);
    double defaultScale = min(size.width / _uiOutputImage!.width, size.height / _uiOutputImage!.height);
    
    Offset cursorScreen = screenPos - Offset(0, _brushOffset);
    
    double ix = (cursorScreen.dx - size.width / 2) / (defaultScale * _scale) + _uiOutputImage!.width / 2 - _offsetX;
    double iy = (cursorScreen.dy - size.height / 2) / (defaultScale * _scale) + _uiOutputImage!.height / 2 - _offsetY;
    
    return Offset(ix, iy);
  }

  void _startStroke(Offset pos, BoxConstraints constraints) {
    Offset imgPos = _screenToImage(pos, constraints);
    
    double scale = min(constraints.maxWidth / _uiOutputImage!.width, constraints.maxHeight / _uiOutputImage!.height);
    double brushSizeImg = _brushSize / scale;
    
    Path path = Path()..moveTo(imgPos.dx, imgPos.dy);
    setState(() {
      _currentTouch = pos;
      _currentStroke = BrushStroke(path: path, size: brushSizeImg, mode: _brushMode);
    });
  }

  void _updateStroke(Offset pos, BoxConstraints constraints) {
    if (_currentStroke == null) return;
    Offset imgPos = _screenToImage(pos, constraints);
    
    setState(() {
      _currentTouch = pos;
      _currentStroke!.path.lineTo(imgPos.dx, imgPos.dy);
    });
  }

  void _endStroke() {
    if (_currentStroke != null) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
        _currentTouch = null;
      });
    }
  }

  Offset _screenToImageForDraw(Offset screenPos, BoxConstraints constraints) {
    final Size size = Size(constraints.maxWidth, constraints.maxHeight);
    double defaultScale = min(size.width / _uiOutputImage!.width, size.height / _uiOutputImage!.height);
    
    double ix = (screenPos.dx - size.width / 2) / (defaultScale * _scale) + _uiOutputImage!.width / 2 - _offsetX;
    double iy = (screenPos.dy - size.height / 2) / (defaultScale * _scale) + _uiOutputImage!.height / 2 - _offsetY;
    
    return Offset(ix, iy);
  }

  void _startFreehandStroke(Offset pos, BoxConstraints constraints) {
    Offset imgPos = _screenToImageForDraw(pos, constraints);
    double scale = min(constraints.maxWidth / _uiOutputImage!.width, constraints.maxHeight / _uiOutputImage!.height);
    double brushSizeImg = _drawBrushSize / scale;
    
    setState(() {
      _currentFreehandStroke = DrawStroke(
        points: [imgPos], 
        size: brushSizeImg, 
        color: _drawColor, 
        isEraser: _drawIsEraser
      );
    });
  }

  void _updateFreehandStroke(Offset pos, BoxConstraints constraints) {
    if (_currentFreehandStroke == null) return;
    Offset imgPos = _screenToImageForDraw(pos, constraints);
    setState(() {
      _currentFreehandStroke!.points.add(imgPos);
    });
  }

  void _endFreehandStroke() {
    if (_currentFreehandStroke != null) {
      setState(() {
        _freehandStrokes.add(_currentFreehandStroke!);
        _currentFreehandStroke = null;
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _onCropPanStart(DragStartDetails details, BoxConstraints constraints) {
    final Offset localPosition = details.localPosition;
    
    const double cornerHandleSize = 30.0;
    const double edgeHandleSize = 20.0;
    
    final bool isTopLeft = (localPosition.dx - _cropX).abs() < cornerHandleSize && 
                          (localPosition.dy - _cropY).abs() < cornerHandleSize;
    final bool isTopRight = (localPosition.dx - (_cropX + _cropWidth)).abs() < cornerHandleSize && 
                           (localPosition.dy - _cropY).abs() < cornerHandleSize;
    final bool isBottomLeft = (localPosition.dx - _cropX).abs() < cornerHandleSize && 
                             (localPosition.dy - (_cropY + _cropHeight)).abs() < cornerHandleSize;
    final bool isBottomRight = (localPosition.dx - (_cropX + _cropWidth)).abs() < cornerHandleSize && 
                              (localPosition.dy - (_cropY + _cropHeight)).abs() < cornerHandleSize;
    
    if (isTopLeft || isTopRight || isBottomLeft || isBottomRight) {
      setState(() => _isResizingCropBox = true);
      _lastPanPosition = localPosition;
      return;
    }
    
    final bool isTopEdge = localPosition.dy >= _cropY - edgeHandleSize && 
                          localPosition.dy <= _cropY + edgeHandleSize &&
                          localPosition.dx >= _cropX + cornerHandleSize && 
                          localPosition.dx <= _cropX + _cropWidth - cornerHandleSize;
    final bool isBottomEdge = localPosition.dy >= _cropY + _cropHeight - edgeHandleSize && 
                             localPosition.dy <= _cropY + _cropHeight + edgeHandleSize &&
                             localPosition.dx >= _cropX + cornerHandleSize && 
                             localPosition.dx <= _cropX + _cropWidth - cornerHandleSize;
    final bool isLeftEdge = localPosition.dx >= _cropX - edgeHandleSize && 
                           localPosition.dx <= _cropX + edgeHandleSize &&
                           localPosition.dy >= _cropY + cornerHandleSize && 
                           localPosition.dy <= _cropY + _cropHeight - cornerHandleSize;
    final bool isRightEdge = localPosition.dx >= _cropX + _cropWidth - edgeHandleSize && 
                            localPosition.dx <= _cropX + _cropWidth + edgeHandleSize &&
                            localPosition.dy >= _cropY + cornerHandleSize && 
                            localPosition.dy <= _cropY + _cropHeight - cornerHandleSize;
    
    if (isTopEdge || isBottomEdge || isLeftEdge || isRightEdge) {
      setState(() => _isResizingCropBox = true);
      _lastPanPosition = localPosition;
      return;
    }
    
    if (localPosition.dx >= _cropX && localPosition.dx <= _cropX + _cropWidth &&
        localPosition.dy >= _cropY && localPosition.dy <= _cropY + _cropHeight) {
      setState(() => _isDraggingCropBox = true);
    }
    
    _lastPanPosition = localPosition;
  }

  void _onCropPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isDraggingCropBox && !_isResizingCropBox) return;
    
    final Offset delta = details.localPosition - _lastPanPosition!;
    double displayWidth = constraints.maxWidth;
    double displayHeight = constraints.maxHeight;
    
    if (_isDraggingCropBox) {
      setState(() {
        _cropX = (_cropX + delta.dx).clamp(0.0, displayWidth - _cropWidth);
        _cropY = (_cropY + delta.dy).clamp(0.0, displayHeight - _cropHeight);
      });
    } else if (_isResizingCropBox) {
      final Offset startPos = _lastPanPosition!;
      const double cornerHandleSize = 30.0;
      
      final bool isTopLeft = (startPos.dx - _cropX).abs() < cornerHandleSize && 
                            (startPos.dy - _cropY).abs() < cornerHandleSize;
      final bool isTopRight = (startPos.dx - (_cropX + _cropWidth)).abs() < cornerHandleSize && 
                             (startPos.dy - _cropY).abs() < cornerHandleSize;
      final bool isBottomLeft = (startPos.dx - _cropX).abs() < cornerHandleSize && 
                               (startPos.dy - (_cropY + _cropHeight)).abs() < cornerHandleSize;
      final bool isBottomRight = (startPos.dx - (_cropX + _cropWidth)).abs() < cornerHandleSize && 
                                (startPos.dy - (_cropY + _cropHeight)).abs() < cornerHandleSize;
      
      const double edgeHandleSize = 20.0;
      final bool isTopEdge = !isTopLeft && !isTopRight && 
                            startPos.dy >= _cropY - edgeHandleSize && 
                            startPos.dy <= _cropY + edgeHandleSize;
      final bool isBottomEdge = !isBottomLeft && !isBottomRight &&
                               startPos.dy >= _cropY + _cropHeight - edgeHandleSize && 
                               startPos.dy <= _cropY + _cropHeight + edgeHandleSize;
      final bool isLeftEdge = !isTopLeft && !isBottomLeft &&
                             startPos.dx >= _cropX - edgeHandleSize && 
                             startPos.dx <= _cropX + edgeHandleSize;
      final bool isRightEdge = !isTopRight && !isBottomRight &&
                              startPos.dx >= _cropX + _cropWidth - edgeHandleSize && 
                              startPos.dx <= _cropX + _cropWidth + edgeHandleSize;
      
      setState(() {
        if (isTopLeft) {
          _cropX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50);
          _cropY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50);
          _cropWidth = (_cropWidth - delta.dx).clamp(50.0, displayWidth - _cropX);
          _cropHeight = (_cropHeight - delta.dy).clamp(50.0, displayHeight - _cropY);
        } else if (isTopRight) {
          _cropY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50);
          _cropWidth = (_cropWidth + delta.dx).clamp(50.0, displayWidth - _cropX);
          _cropHeight = (_cropHeight - delta.dy).clamp(50.0, displayHeight - _cropY);
        } else if (isBottomLeft) {
          _cropX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50);
          _cropWidth = (_cropWidth - delta.dx).clamp(50.0, displayWidth - _cropX);
          _cropHeight = (_cropHeight + delta.dy).clamp(50.0, displayHeight - _cropY);
        } else if (isBottomRight) {
          _cropWidth = (_cropWidth + delta.dx).clamp(50.0, displayWidth - _cropX);
          _cropHeight = (_cropHeight + delta.dy).clamp(50.0, displayHeight - _cropY);
        } else if (isTopEdge) {
          _cropY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50);
          _cropHeight = (_cropHeight - delta.dy).clamp(50.0, displayHeight - _cropY);
        } else if (isBottomEdge) {
          _cropHeight = (_cropHeight + delta.dy).clamp(50.0, displayHeight - _cropY);
        } else if (isLeftEdge) {
          _cropX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50);
          _cropWidth = (_cropWidth - delta.dx).clamp(50.0, displayWidth - _cropX);
        } else if (isRightEdge) {
          _cropWidth = (_cropWidth + delta.dx).clamp(50.0, displayWidth - _cropX);
        }
      });
    }
    
    _lastPanPosition = details.localPosition;
  }

  void _onCropPanEnd(DragEndDetails details) {
    setState(() {
      _isDraggingCropBox = false;
      _isResizingCropBox = false;
    });
    _lastPanPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditorMode ? 'Edit Cutout' : 'Background Remover'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isEditorMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_outputImagePath != null && !_isRefining && !widget.isEditorMode) ...[
            TextButton.icon(
              onPressed: () => setState(() => _isRefining = true),
              icon: const Icon(Icons.brush, color: AppColors.primary),
              label: const Text('Refine', style: TextStyle(color: AppColors.primary)),
            ),
          ] else if (_isRefining) ...[
            if (widget.isEditorMode)
              TextButton.icon(
                onPressed: () async {
                  setState(() => _isProcessing = true);
                  try {
                    final path = await _exportRefinedImage();
                    if (mounted) Navigator.pop(context, File(path));
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving: $e')));
                    }
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text('Save', style: TextStyle(color: Colors.green)),
              )
            else
              TextButton.icon(
                onPressed: () => setState(() => _isRefining = false),
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text('Done', style: TextStyle(color: Colors.green)),
              ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isRefining) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ToggleButtons(
                          isSelected: [_brushMode == BrushMode.erase, _brushMode == BrushMode.restore],
                          onPressed: (index) {
                            setState(() {
                              _brushMode = index == 0 ? BrushMode.erase : BrushMode.restore;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          children: const [
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Erase')),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Restore')),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.undo),
                          onPressed: _strokes.isNotEmpty ? _undo : null,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Size', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: _brushSize,
                            min: 5,
                            max: 100,
                            onChanged: (val) => setState(() => _brushSize = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanStart: (_isRefining || _isDrawingMode) ? (d) => _onPanStart(d, constraints) : (_isCropping ? (d) => _onCropPanStart(d, constraints) : null),
                      onPanUpdate: (_isRefining || _isDrawingMode) ? (d) => _onPanUpdate(d, constraints) : (_isCropping ? (d) => _onCropPanUpdate(d, constraints) : null),
                      onPanEnd: (_isRefining || _isDrawingMode) ? (d) => _onPanEnd(d) : (_isCropping ? (d) => _onCropPanEnd(d) : null),
                      onScaleStart: (!_isRefining && !_isDrawingMode && !_isCropping) ? _onScaleStart : null,
                      onScaleUpdate: (!_isRefining && !_isDrawingMode && !_isCropping) ? _onScaleUpdate : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent, // transparent to show checkerboard
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              // Checkerboard pattern for transparency visualization
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: CheckerboardPainter(),
                                ),
                              ),
                              
                              if (_showOriginal && _inputImage != null)
                                Positioned.fill(
                                  child: Image.file(_inputImage!, fit: BoxFit.contain),
                                )
                              else if (_uiOutputImage != null && _uiInputImage != null)
                                Positioned.fill(
                                  child: Container(
                                    color: _bgColor,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (_bgImage != null)
                                          Image.file(_bgImage!, fit: BoxFit.cover),
                                        if (_bgUseWordMode)
                                          ..._bgWordTokens.map((token) => Align(
                                            alignment: token.position,
                                            child: GestureDetector(
                                              onTap: () => setState(() => _selectedBgWordToken = token),
                                              onPanUpdate: _selectedTabIndex == 7 ? (details) {
                                                setState(() {
                                                  _selectedBgWordToken = token;
                                                  double dx = details.delta.dx / constraints.maxWidth * 2;
                                                  double dy = details.delta.dy / constraints.maxHeight * 2;
                                                  token.position = Alignment(
                                                    (token.position.x + dx).clamp(-1.0, 1.0),
                                                    (token.position.y + dy).clamp(-1.0, 1.0)
                                                  );
                                                });
                                              } : null,
                                              child: Transform.rotate(
                                                angle: token.rotation * pi / 180,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: _selectedBgWordToken == token && _selectedTabIndex == 7 
                                                    ? BoxDecoration(border: Border.all(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(4)) 
                                                    : null,
                                                  child: Text(
                                                    token.text,
                                                    style: TextStyle(
                                                      fontSize: token.fontSize,
                                                      color: token.color,
                                                      fontFamily: token.font?.family,
                                                      fontWeight: token.font?.weight ?? FontWeight.bold,
                                                      shadows: token.enableShadow ? [Shadow(blurRadius: token.shadowBlur, color: token.shadowColor, offset: token.shadowOffset)] : null,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ))
                                        else if (_bgText.isNotEmpty)
                                          Align(
                                            alignment: _bgTextAlignment,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Text(
                                                _bgText,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: _bgTextFontSize,
                                                  color: _bgTextColor,
                                                  fontFamily: _bgTextFont?.family,
                                                  fontWeight: _bgTextFont?.weight ?? FontWeight.bold,
                                                  shadows: _bgTextEnableShadow
                                                      ? [const Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(2, 2))]
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        CustomPaint(
                                          painter: RefinerPainter(
                                            outputImage: _uiOutputImage,
                                            inputImage: _uiInputImage,
                                            strokes: _strokes,
                                            currentStroke: _currentStroke,
                                            freehandStrokes: _freehandStrokes,
                                            currentFreehandStroke: _currentFreehandStroke,
                                            currentTouch: _currentTouch,
                                            brushSize: _brushSize,
                                            brushOffset: _brushOffset,
                                            strokeColor: _strokeColor,
                                            strokeWidth: _strokeWidth,
                                            scale: _scale,
                                            offsetX: _offsetX,
                                            offsetY: _offsetY,
                                            shadowRadius: _shadowRadius,
                                            shadowColor: _shadowColor,
                                            shadowDx: _shadowDx,
                                            shadowDy: _shadowDy,
                                            brightness: _brightness,
                                            contrast: _contrast,
                                            saturation: _saturation,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (_inputImage != null)
                                Positioned.fill(
                                  child: Image.file(_inputImage!, fit: BoxFit.contain),
                                )
                              else
                                const Center(child: Text('Pick an image to start', style: TextStyle(color: Colors.grey))),

                              if (_isCropping && _inputImage != null)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: CropOverlayPainter(
                                      cropX: _cropX,
                                      cropY: _cropY,
                                      cropWidth: _cropWidth,
                                      cropHeight: _cropHeight,
                                      imageWidth: constraints.maxWidth,
                                      imageHeight: constraints.maxHeight,
                                      isDragging: _isDraggingCropBox,
                                      isResizing: _isResizingCropBox,
                                    ),
                                  ),
                                ),
                              
                              if (_isProcessing)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                                ),
                                
                              if (_outputImagePath != null && !_isRefining)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _showOriginal ? 'Original' : 'Result',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ),
            ),
            
            if (!_isRefining && !widget.isEditorMode)
              Column(
                children: [
                  if (_isTabContentExpanded) _buildActiveTabContent(),
                  _buildControlTabs(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintWhite = Paint()..color = Colors.white;
    final paintGrey = Paint()..color = Colors.grey.shade300;
    
    const double squareSize = 20.0;
    
    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isWhite = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isWhite ? paintWhite : paintGrey,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RefinerPainter extends CustomPainter {
  final ui.Image? outputImage;
  final ui.Image? inputImage;
  final List<BrushStroke> strokes;
  final BrushStroke? currentStroke;
  final List<DrawStroke> freehandStrokes;
  final DrawStroke? currentFreehandStroke;
  final Offset? currentTouch;
  final double brushSize;
  final double brushOffset;
  final Color strokeColor;
  final double strokeWidth;
  final double scale;
  final double offsetX;
  final double offsetY;
  
  final double shadowRadius;
  final Color shadowColor;
  final double shadowDx;
  final double shadowDy;
  
  final double brightness;
  final double contrast;
  final double saturation;

  RefinerPainter({
    required this.outputImage,
    required this.inputImage,
    required this.strokes,
    required this.currentStroke,
    required this.freehandStrokes,
    required this.currentFreehandStroke,
    required this.currentTouch,
    required this.brushSize,
    required this.brushOffset,
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 0.0,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.shadowRadius = 0.0,
    this.shadowColor = Colors.transparent,
    this.shadowDx = 0.0,
    this.shadowDy = 0.0,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (outputImage == null || inputImage == null) return;
    
    double defaultScale = min(size.width / outputImage!.width, size.height / outputImage!.height);
    double dx = (size.width - outputImage!.width * defaultScale) / 2;
    double dy = (size.height - outputImage!.height * defaultScale) / 2;
    
    canvas.save();
    canvas.translate(dx + offsetX, dy + offsetY);
    canvas.translate(outputImage!.width * defaultScale / 2, outputImage!.height * defaultScale / 2);
    canvas.scale(defaultScale * scale);
    canvas.translate(-outputImage!.width / 2, -outputImage!.height / 2);
    
    Rect imgRect = Rect.fromLTWH(0, 0, outputImage!.width.toDouble(), outputImage!.height.toDouble());
    
    // Draw shadow
    // Draw Shadow
    if ((shadowRadius > 0 || shadowDx != 0 || shadowDy != 0) && shadowColor != Colors.transparent) {
      final shadowPaint = Paint()
        ..colorFilter = ColorFilter.mode(shadowColor, BlendMode.srcIn);
        
      if (shadowRadius > 0) {
        shadowPaint.imageFilter = ui.ImageFilter.blur(sigmaX: shadowRadius, sigmaY: shadowRadius);
      }
      
      Rect expandedRect = imgRect.inflate(shadowRadius * 3).shift(Offset(shadowDx, shadowDy));
      canvas.saveLayer(expandedRect, Paint());
      canvas.translate(shadowDx, shadowDy);
      canvas.drawImage(outputImage!, Offset.zero, shadowPaint);
      canvas.restore();
    }
    
    // Draw Stroke if enabled (simulate by drawing multiple times with color filter)
    if (strokeWidth > 0 && strokeColor != Colors.transparent) {
      final strokePaint = Paint()
        ..colorFilter = ColorFilter.mode(strokeColor, BlendMode.srcIn);
      // Draw 8 shifted versions to create an outline
      final double s = strokeWidth / defaultScale;
      canvas.drawImage(outputImage!, Offset(s, 0), strokePaint);
      canvas.drawImage(outputImage!, Offset(-s, 0), strokePaint);
      canvas.drawImage(outputImage!, Offset(0, s), strokePaint);
      canvas.drawImage(outputImage!, Offset(0, -s), strokePaint);
      canvas.drawImage(outputImage!, Offset(s, s), strokePaint);
      canvas.drawImage(outputImage!, Offset(-s, -s), strokePaint);
      canvas.drawImage(outputImage!, Offset(s, -s), strokePaint);
      canvas.drawImage(outputImage!, Offset(-s, s), strokePaint);
    }
    
    canvas.saveLayer(imgRect, Paint());
    
    final fgPaint = Paint();
    if (brightness != 0.0 || contrast != 1.0 || saturation != 1.0) {
      double b = brightness * 255.0;
      double c = contrast;
      
      double rw = 0.3086;
      double gw = 0.6094;
      double bw = 0.0820;
      
      double invSat = 1.0 - saturation;
      double R = invSat * rw;
      double G = invSat * gw;
      double B = invSat * bw;
      
      // We combine contrast/brightness and saturation mathematically.
      // Or just apply them via standard matrix multiplication, but we'll do it manually.
      // To keep it simple, apply contrast/brightness to the saturation matrix.
      List<double> filterMatrix = [
        c * (R + saturation), c * G, c * B, 0, b,
        c * R, c * (G + saturation), c * B, 0, b,
        c * R, c * G, c * (B + saturation), 0, b,
        0, 0, 0, 1, 0,
      ];
      fgPaint.colorFilter = ColorFilter.matrix(filterMatrix);
    }
    
    canvas.drawImage(outputImage!, Offset.zero, fgPaint);
    
    Paint erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    final restoreShader = ImageShader(
      inputImage!,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );
    Paint restorePaint = Paint()
      ..shader = restoreShader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    for (var stroke in strokes) {
       Paint p = stroke.mode == BrushMode.erase ? erasePaint : restorePaint;
       p.strokeWidth = stroke.size;
       canvas.drawPath(stroke.path, p);
    }
    
    if (currentStroke != null) {
       Paint p = currentStroke!.mode == BrushMode.erase ? erasePaint : restorePaint;
       p.strokeWidth = currentStroke!.size;
       canvas.drawPath(currentStroke!.path, p);
    }
    
    // Draw freehand strokes (ink)
    for (var stroke in freehandStrokes) {
      if (stroke.points.length < 2) continue;
      Paint p = Paint()
        ..color = stroke.isEraser ? Colors.transparent : stroke.color
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.size;
      
      Path path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, p);
    }
    
    if (currentFreehandStroke != null && currentFreehandStroke!.points.length >= 2) {
      Paint p = Paint()
        ..color = currentFreehandStroke!.isEraser ? Colors.transparent : currentFreehandStroke!.color
        ..blendMode = currentFreehandStroke!.isEraser ? BlendMode.clear : BlendMode.srcOver
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = currentFreehandStroke!.size;
      
      Path path = Path();
      path.moveTo(currentFreehandStroke!.points.first.dx, currentFreehandStroke!.points.first.dy);
      for (int i = 1; i < currentFreehandStroke!.points.length; i++) {
        path.lineTo(currentFreehandStroke!.points[i].dx, currentFreehandStroke!.points[i].dy);
      }
      canvas.drawPath(path, p);
    }
    
    canvas.restore(); // pop saveLayer
    canvas.restore(); // pop transform
    
    // Draw brush indicator
    if (currentTouch != null) {
      Offset cursor = currentTouch! - Offset(0, brushOffset);
      canvas.drawCircle(cursor, brushSize / 2, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(currentTouch!, 3, Paint()..color = Colors.blue); // Actual touch point
      
      // Draw line connecting touch to cursor
      canvas.drawLine(currentTouch!, cursor + Offset(0, brushSize / 2), Paint()..color = Colors.blue.withValues(alpha: 0.5)..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant RefinerPainter oldDelegate) {
    return true; // Simple approach, always repaint when things change
  }
}

class CropOverlayPainter extends CustomPainter {
  final double cropX;
  final double cropY;
  final double cropWidth;
  final double cropHeight;
  final double imageWidth;
  final double imageHeight;
  final bool isDragging;
  final bool isResizing;

  CropOverlayPainter({
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
    required this.imageWidth,
    required this.imageHeight,
    this.isDragging = false,
    this.isResizing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw dark overlay outside crop area
    final cropRect = Rect.fromLTWH(cropX, cropY, cropWidth, cropHeight);
    
    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, imageWidth, cropY), paint);
    // Bottom
    canvas.drawRect(Rect.fromLTWH(0, cropY + cropHeight, imageWidth, imageHeight - cropY - cropHeight), paint);
    // Left
    canvas.drawRect(Rect.fromLTWH(0, cropY, cropX, cropHeight), paint);
    // Right
    canvas.drawRect(Rect.fromLTWH(cropX + cropWidth, cropY, imageWidth - cropX - cropWidth, cropHeight), paint);

    // Draw grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Vertical lines
    canvas.drawLine(
      Offset(cropX + cropWidth / 3, cropY),
      Offset(cropX + cropWidth / 3, cropY + cropHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropX + (cropWidth * 2) / 3, cropY),
      Offset(cropX + (cropWidth * 2) / 3, cropY + cropHeight),
      gridPaint,
    );
    
    // Horizontal lines
    canvas.drawLine(
      Offset(cropX, cropY + cropHeight / 3),
      Offset(cropX + cropWidth, cropY + cropHeight / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropX, cropY + (cropHeight * 2) / 3),
      Offset(cropX + cropWidth, cropY + (cropHeight * 2) / 3),
      gridPaint,
    );

    // Draw crop border with different colors based on state
    final borderPaint = Paint()
      ..color = isDragging ? Colors.green : (isResizing ? Colors.orange : Colors.white)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging || isResizing ? 3 : 2.5;

    canvas.drawRect(cropRect, borderPaint);

    // Draw corner handles with L-shapes for better visibility
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const double handleLength = 20; // Length of L-shape arms
    
    // Top-left handle
    canvas.drawLine(Offset(cropX, cropY), Offset(cropX + handleLength, cropY), handlePaint);
    canvas.drawLine(Offset(cropX, cropY), Offset(cropX, cropY + handleLength), handlePaint);
    
    // Top-right handle
    canvas.drawLine(Offset(cropX + cropWidth, cropY), Offset(cropX + cropWidth - handleLength, cropY), handlePaint);
    canvas.drawLine(Offset(cropX + cropWidth, cropY), Offset(cropX + cropWidth, cropY + handleLength), handlePaint);
    
    // Bottom-left handle
    canvas.drawLine(Offset(cropX, cropY + cropHeight), Offset(cropX + handleLength, cropY + cropHeight), handlePaint);
    canvas.drawLine(Offset(cropX, cropY + cropHeight), Offset(cropX, cropY + cropHeight - handleLength), handlePaint);
    
    // Bottom-right handle
    canvas.drawLine(Offset(cropX + cropWidth, cropY + cropHeight), Offset(cropX + cropWidth - handleLength, cropY + cropHeight), handlePaint);
    canvas.drawLine(Offset(cropX + cropWidth, cropY + cropHeight), Offset(cropX + cropWidth, cropY + cropHeight - handleLength), handlePaint);
    
    // Draw edge handles (center dots)
    final edgeHandlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const double edgeHandleSize = 6;
    
    // Top edge handle
    canvas.drawCircle(Offset(cropX + cropWidth / 2, cropY), edgeHandleSize / 2, edgeHandlePaint);
    
    // Bottom edge handle
    canvas.drawCircle(Offset(cropX + cropWidth / 2, cropY + cropHeight), edgeHandleSize / 2, edgeHandlePaint);
    
    // Left edge handle
    canvas.drawCircle(Offset(cropX, cropY + cropHeight / 2), edgeHandleSize / 2, edgeHandlePaint);
    
    // Right edge handle
    canvas.drawCircle(Offset(cropX + cropWidth, cropY + cropHeight / 2), edgeHandleSize / 2, edgeHandlePaint);
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropX != cropX ||
           oldDelegate.cropY != cropY ||
           oldDelegate.cropWidth != cropWidth ||
           oldDelegate.cropHeight != cropHeight ||
           oldDelegate.isDragging != isDragging ||
           oldDelegate.isResizing != isResizing;
  }
}
