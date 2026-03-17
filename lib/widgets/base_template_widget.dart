import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../utils/font_selector.dart';

class TemplateViewController {
  double scale = 1.0;
  double offsetX = 0.0;
  double offsetY = 0.0;
  double areaWidth = 0.0;
  double areaHeight = 0.0;
  int imagePixelWidth = 0;
  int imagePixelHeight = 0;
  
  // Store initial values for reset
  double? _initialScale;
  double? _initialOffsetX;
  double? _initialOffsetY;
  
  void saveInitialState() {
    _initialScale = scale;
    _initialOffsetX = offsetX;
    _initialOffsetY = offsetY;
  }
  
  void resetToInitial() {
    if (_initialScale != null) {
      scale = _initialScale!;
      offsetX = _initialOffsetX!;
      offsetY = _initialOffsetY!;
    }
  }
}

class InstagramPostTemplate extends StatefulWidget {
  final String text;
  final File? image;
  final List<File?>? gridImages; // For 2x2 grid layout
  final bool isGridMode;
  final double width;
  final double height;
  final bool isPreview;
  final TemplateViewController? controller;
  final FontInfo? selectedFont;
  final GlobalKey? repaintBoundaryKey;
  final Color textColor;
  final Color textBoxColor;
  final bool enableTextShadow;
  final bool enableTextGlow;
  final Color shadowColor;
  final Color glowColor;
  final double glowRadius;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double shadowBlurRadius;
  final double letterSpacing;
  final double fontSizeMultiplier;
  final TextEditingController? textController;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onImageLoaded;
  final bool showPlaceholder;

  const InstagramPostTemplate({
    super.key,
    required this.text,
    this.image,
    this.gridImages,
    this.isGridMode = false,
    required this.width,
    required this.height,
    this.isPreview = false,
    this.controller,
    this.selectedFont,
    this.repaintBoundaryKey,
    this.textColor = Colors.black87,
    this.textBoxColor = Colors.white,
    this.enableTextShadow = false,
    this.enableTextGlow = false,
    this.shadowColor = Colors.black,
    this.glowColor = Colors.white,
    this.glowRadius = 10.0,
    this.shadowOffsetX = 2.0,
    this.shadowOffsetY = 2.0,
    this.shadowBlurRadius = 4.0,
    this.letterSpacing = 0.0,
    this.fontSizeMultiplier = 1.0,
    this.textController,
    this.onTextChanged,
    this.onImageLoaded,
    this.showPlaceholder = true,
  });

  @override
  State<InstagramPostTemplate> createState() => _InstagramPostTemplateState();
}

class _InstagramPostTemplateState extends State<InstagramPostTemplate> {
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  Offset _focalPoint = Offset.zero;
  ui.Image? _uiImage;
  bool _isImageLoaded = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize from controller if available
    if (widget.controller != null) {
      _scale = widget.controller!.scale;
      _offset = Offset(widget.controller!.offsetX, widget.controller!.offsetY);
    }
    
    if (widget.image != null) {
      _loadImage();
    }
    _updateController();
  }

  @override
  void didUpdateWidget(InstagramPostTemplate oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync with controller if values changed
    if (widget.controller != null) {
      if (_scale != widget.controller!.scale || 
          _offset.dx != widget.controller!.offsetX || 
          _offset.dy != widget.controller!.offsetY) {
        setState(() {
          _scale = widget.controller!.scale;
          _offset = Offset(widget.controller!.offsetX, widget.controller!.offsetY);
        });
      }
    }
    
    // Handle grid mode image changes
    if (widget.isGridMode && widget.gridImages != oldWidget.gridImages) {
      // In grid mode, notify immediately as Image.file handles loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onImageLoaded?.call();
      });
    }
    
    if (widget.image != oldWidget.image) {
      if (widget.image != null) {
        _loadImage();
      } else {
        setState(() {
          _uiImage = null;
          _isImageLoaded = false;
          _scale = 1.0;
          _offset = Offset.zero;
        });
        _updateController();
      }
    } else {
      _updateController();
    }
  }

  Future<void> _loadImage() async {
    try {
      final Uint8List bytes = await widget.image!.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setState(() {
        _uiImage = frameInfo.image;
        _isImageLoaded = true;
        _initializeImagePosition();
      });
      _updateController();
      // Save initial state after first load
      widget.controller?.saveInitialState();
      
      // Notify that image is loaded (for export)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onImageLoaded?.call();
      });
    } catch (e) {
      // ignore
    }
  }

  void _initializeImagePosition() {
    if (_uiImage == null) return;
    final double imageAreaHeight = widget.height * 0.8;
    final double imageAreaWidth = widget.width;
    final double imageAspectRatio = _uiImage!.width / _uiImage!.height;
    final double areaAspectRatio = imageAreaWidth / imageAreaHeight;
    if (imageAspectRatio > areaAspectRatio) {
      _scale = (imageAreaHeight / _uiImage!.height).clamp(0.5, 1.5);
    } else {
      _scale = (imageAreaWidth / _uiImage!.width).clamp(0.5, 1.5);
    }
    _offset = Offset.zero;
  }

  void _updateController() {
    if (widget.controller == null) return;
    widget.controller!.scale = _scale;
    widget.controller!.offsetX = _offset.dx;
    widget.controller!.offsetY = _offset.dy;
    widget.controller!.areaWidth = widget.width;
    widget.controller!.areaHeight = widget.height * 0.8;
    widget.controller!.imagePixelWidth = _uiImage?.width ?? 0;
    widget.controller!.imagePixelHeight = _uiImage?.height ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final double templateWidth = widget.width;
    final double templateHeight = widget.height;
    final double textBoxHeight = templateHeight * 0.2;
    final double imageHeight = templateHeight * 0.8;

    return RepaintBoundary(
      key: widget.repaintBoundaryKey,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: templateWidth,
          height: templateHeight,
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: templateWidth,
                height: textBoxHeight,
                color: widget.textBoxColor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: templateWidth - 32,
                        ),
                        child: Text(
                          widget.text.isEmpty && widget.showPlaceholder
                              ? 'Your text here'
                              : widget.text,
                          style: TextStyle(
                            fontFamily: widget.selectedFont?.family,
                            fontWeight: widget.selectedFont?.weight ?? FontWeight.w600,
                            fontStyle: widget.selectedFont?.style ?? FontStyle.normal,
                            color: widget.text.isEmpty && widget.showPlaceholder
                                ? Colors.grey[400]
                                : widget.textColor,
                            fontSize: _calculateFontSize(
                                    widget.text.isEmpty && widget.showPlaceholder
                                        ? 'Your text here'
                                        : widget.text,
                                    templateWidth) *
                                widget.fontSizeMultiplier,
                            height: 1.2,
                            letterSpacing: widget.letterSpacing,
                            shadows: _buildTextShadows(),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: templateWidth,
                height: imageHeight,
                color: Colors.grey[300],
                child: widget.isGridMode
                    ? _buildGridLayout(templateWidth)
                    : widget.image != null && _isImageLoaded
                        ? ClipRect(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: _onScaleUpdate,
                              onScaleEnd: (_) { _updateController(); },
                              onTapDown: _onTapDown,
                              onTapUp: _onTapUp,
                              onTapCancel: _onTapCancel,
                              child: Stack(
                                children: [
                                  Transform(
                                    transform: Matrix4.identity()
                                      ..translate(
                                        templateWidth / 2 + _offset.dx,
                                        (templateHeight * 0.8) / 2 + _offset.dy,
                                      )
                                      ..scale(_scale)
                                      ..translate(
                                        -_uiImage!.width.toDouble() / 2,
                                        -_uiImage!.height.toDouble() / 2,
                                      ),
                                    child: SizedBox(
                                      width: _uiImage!.width.toDouble(),
                                      height: _uiImage!.height.toDouble(),
                                      child: CustomPaint(
                                        painter: ImagePainter(_uiImage!),
                                      ),
                                    ),
                                  ),
                                  if (_isDragging)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : widget.image != null
                            ? const Center(child: CircularProgressIndicator())
                            : _buildPlaceholder(),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildGridLayout(double templateWidth) {
    final gridImages = widget.gridImages ?? [null, null, null, null];
    final cellSize = templateWidth / 2;
    
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final image = gridImages[index];
        return Container(
          color: Colors.grey[400],
          child: image != null
              ? Image.file(
                  image,
                  fit: BoxFit.cover,
                  width: cellSize,
                  height: cellSize,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) {
                      return child;
                    }
                    // Notify when first frame is loaded
                    if (frame != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.onImageLoaded?.call();
                      });
                    }
                    return frame != null
                        ? child
                        : Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                  },
                )
              : Center(
                  child: Icon(
                    Icons.add_photo_alternate,
                    size: cellSize * 0.3,
                    color: Colors.grey[600],
                  ),
                ),
        );
      },
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _focalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
      final Offset delta = details.focalPoint - _focalPoint;
      _offset = _baseOffset + delta;
      _constrainOffset();
      _updateController();
    });
  }

  void _onTapDown(TapDownDetails details) {
    setState(() { _isDragging = true; });
  }
  void _onTapUp(TapUpDetails details) {
    setState(() { _isDragging = false; });
  }
  void _onTapCancel() {
    setState(() { _isDragging = false; });
  }

  void _constrainOffset() {
    if (_uiImage == null) return;
    final double imageWidth = _uiImage!.width * _scale;
    final double imageHeight = _uiImage!.height * _scale;
    final double areaWidth = widget.width;
    final double areaHeight = widget.height * 0.8;
    final double maxOffsetX = (imageWidth - areaWidth) / 2;
    final double maxOffsetY = (imageHeight - areaHeight) / 2;
    if (imageWidth > areaWidth) {
      _offset = Offset(_offset.dx.clamp(-maxOffsetX, maxOffsetX), _offset.dy);
    } else {
      _offset = Offset(0, _offset.dy);
    }
    if (imageHeight > areaHeight) {
      _offset = Offset(_offset.dx, _offset.dy.clamp(-maxOffsetY, maxOffsetY));
    } else {
      _offset = Offset(_offset.dx, 0);
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[400]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.grey),
      ),
    );
  }

  double _calculateFontSize(String text, double width) {
    if (text.isEmpty) return 16;
    double baseSize = width * 0.05;
    if (text.length > 50) baseSize *= 0.7;
    else if (text.length > 30) baseSize *= 0.8;
    else if (text.length > 20) baseSize *= 0.9;
    return baseSize.clamp(12.0, 24.0);
  }

  List<Shadow> _buildTextShadows() {
    List<Shadow> shadows = [];
    
    if (widget.enableTextShadow) {
      shadows.add(
        Shadow(
          offset: Offset(widget.shadowOffsetX, widget.shadowOffsetY),
          blurRadius: widget.shadowBlurRadius,
          color: widget.shadowColor.withOpacity(0.5),
        ),
      );
    }
    
    if (widget.enableTextGlow) {
      shadows.addAll([
        Shadow(
          offset: Offset.zero,
          blurRadius: widget.glowRadius,
          color: widget.glowColor.withOpacity(0.8),
        ),
        Shadow(
          offset: Offset.zero,
          blurRadius: widget.glowRadius * 0.5,
          color: widget.glowColor,
        ),
      ]);
    }
    
    return shadows;
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  ImagePainter(this.image);
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, rect, rect, Paint());
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TemplatePreview extends StatelessWidget {
  final String text;
  final File? image;
  final VoidCallback onTap;
  final FontInfo? selectedFont;

  const TemplatePreview({
    super.key,
    required this.text,
    this.image,
    required this.onTap,
    this.selectedFont,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8.0),
        child: InstagramPostTemplate(
          text: text,
          image: image,
          width: 200,
          height: 250,
          isPreview: true,
          selectedFont: selectedFont,
        ),
      ),
    );
  }
}
