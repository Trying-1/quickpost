import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class ImageCropEditor extends StatefulWidget {
  final File imageFile;
  final Function(File croppedImage) onCropComplete;

  const ImageCropEditor({
    super.key,
    required this.imageFile,
    required this.onCropComplete,
  });

  @override
  State<ImageCropEditor> createState() => _ImageCropEditorState();
}

class _ImageCropEditorState extends State<ImageCropEditor> {
  late ui.Image _image;
  bool _isImageLoaded = false;
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  Offset _focalPoint = Offset.zero;
  final double _baseCropSize = 300.0;

  double get _cropSize {
    final Size size = MediaQuery.of(context).size;
    // Use up to 70% of the shortest side, but within [240, 360]
    final double responsive = (size.shortestSide * 0.7).clamp(240.0, 360.0);
    return responsive;
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final Uint8List bytes = await widget.imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setState(() {
        _image = frameInfo.image;
        _isImageLoaded = true;
        _initializeImagePosition();
      });
    } catch (e) {
      // Error loading - UI will show empty state
    }
  }

  void _initializeImagePosition() {
    // Calculate initial scale to fit image within crop area
    final double imageAspectRatio = _image.width / _image.height;
    
    if (imageAspectRatio > 1.0) {
      // Landscape image - fit height
      _scale = _cropSize / _image.height;
    } else {
      // Portrait image - fit width
      _scale = _cropSize / _image.width;
    }

    // Center the image
    _offset = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop & Position Image'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isImageLoaded ? _cropImage : null,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Drag and zoom to position your image in the square area',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Crop area
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double size = _cropSize;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _isImageLoaded
                          ? GestureDetector(
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: _onScaleUpdate,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translate(_offset.dx, _offset.dy)
                                  ..scale(_scale),
                                child: SizedBox(
                                  width: _image.width.toDouble(),
                                  height: _image.height.toDouble(),
                                  child: CustomPaint(
                                    painter: ImagePainter(_image),
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _resetPosition,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _fitToSquare,
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('Fit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _focalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Update scale
      _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
      
      // Update offset
      final Offset delta = details.focalPoint - _focalPoint;
      _offset = _baseOffset + delta;
      
      // Constrain the image to keep it within the crop area
      _constrainOffset();
    });
  }

  void _constrainOffset() {
    final double imageWidth = _image.width * _scale;
    final double imageHeight = _image.height * _scale;
    
    // Calculate the maximum allowed offset to keep image within crop area
    final double maxOffsetX = (imageWidth - _cropSize) / 2;
    final double maxOffsetY = (imageHeight - _cropSize) / 2;
    
    // Constrain X offset
    if (imageWidth > _cropSize) {
      _offset = Offset(
        _offset.dx.clamp(-maxOffsetX, maxOffsetX),
        _offset.dy,
      );
    } else {
      // If image is smaller than crop area, center it
      _offset = Offset(0, _offset.dy);
    }
    
    // Constrain Y offset
    if (imageHeight > _cropSize) {
      _offset = Offset(
        _offset.dx,
        _offset.dy.clamp(-maxOffsetY, maxOffsetY),
      );
    } else {
      // If image is smaller than crop area, center it
      _offset = Offset(_offset.dx, 0);
    }
  }

  void _resetPosition() {
    setState(() {
      _initializeImagePosition();
    });
  }

  void _fitToSquare() {
    setState(() {
      final double imageAspectRatio = _image.width / _image.height;
      if (imageAspectRatio > 1.0) {
        // Landscape image - fit height
        _scale = _cropSize / _image.height;
      } else {
        // Portrait image - fit width
        _scale = _cropSize / _image.width;
      }
      _offset = Offset.zero;
    });
  }

  Future<void> _cropImage() async {
    try {
      // Calculate the crop area in the original image coordinates
      final double imageWidth = _image.width * _scale;
      final double imageHeight = _image.height * _scale;
      
      // Calculate the crop rectangle in original image coordinates
      final double cropX = (_cropSize - imageWidth) / 2 - _offset.dx;
      final double cropY = (_cropSize - imageHeight) / 2 - _offset.dy;
      
      final double srcX = cropX / _scale;
      final double srcY = cropY / _scale;
      final double srcWidth = _cropSize / _scale;
      final double srcHeight = _cropSize / _scale;
      
      // Create a canvas to draw the cropped image
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // Draw the cropped portion of the image
      final Rect srcRect = Rect.fromLTWH(
        srcX.clamp(0, _image.width.toDouble()),
        srcY.clamp(0, _image.height.toDouble()),
        srcWidth.clamp(0, _image.width.toDouble()),
        srcHeight.clamp(0, _image.height.toDouble()),
      );
      final Rect dstRect = Rect.fromLTWH(0, 0, _cropSize, _cropSize);
      
      canvas.drawImageRect(_image, srcRect, dstRect, Paint());
      
      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(
        _cropSize.toInt(),
        _cropSize.toInt(),
      );
      
      // Convert to bytes
      final ByteData? byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData != null) {
        // Save to temporary file
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/cropped_image_${DateTime.now().millisecondsSinceEpoch}.png';
        final File croppedFile = File(tempPath);
        await croppedFile.writeAsBytes(byteData.buffer.asUint8List());
        
        // Call the callback with the cropped image
        widget.onCropComplete(croppedFile);
        
        // Navigate back
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to crop image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
