import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../services/analytics_service.dart';
import '../../config/app_theme.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import '../home/home_shell_screen.dart';
import '../../services/app_review_service.dart';
import '../../services/ad_service.dart';

class ImageCropperScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final bool returnResultOnCrop;

  const ImageCropperScreen({
    super.key,
    this.sharedImagePaths,
    this.returnResultOnCrop = false,
  });

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  
  List<File> _selectedImages = [];
  List<CroppedImageData> _croppedImages = [];
  int _currentImageIndex = 0;
  bool _isLoading = false;

  // Crop area properties
  double _cropX = 0.0;
  double _cropY = 0.0;
  double _cropWidth = 200.0;
  double _cropHeight = 200.0;
  double _imageScale = 1.0;
  double _imageOffsetX = 0.0;
  double _imageOffsetY = 0.0;
  
  // Gesture handling
  bool _isDragging = false;
  bool _isResizing = false;
  Offset? _lastPanPosition;
  
  // Aspect ratio presets
  String? _selectedAspectRatio;
  static const Map<String, Map<String, dynamic>> _aspectRatios = {
    'free': {'name': 'Free', 'ratio': null, 'icon': Icons.crop_free},
    '1:1': {'name': 'Square', 'ratio': 1.0, 'icon': Icons.crop_square},
    '4:3': {'name': '4:3', 'ratio': 4/3, 'icon': Icons.crop_landscape},
    '3:4': {'name': '3:4', 'ratio': 3/4, 'icon': Icons.crop_portrait},
    '16:9': {'name': '16:9', 'ratio': 16/9, 'icon': Icons.crop_landscape},
    '9:16': {'name': '9:16', 'ratio': 9/16, 'icon': Icons.crop_portrait},
    '3:2': {'name': '3:2', 'ratio': 3/2, 'icon': Icons.crop_landscape},
    '2:3': {'name': '2:3', 'ratio': 2/3, 'icon': Icons.crop_portrait},
  };

  // Image display properties
  ui.Image? _currentUiImage;
  double _imageDisplayWidth = 0.0;
  double _imageDisplayHeight = 0.0;
  
  // Transform properties
  int _rotation = 0; // 0, 90, 180, 270
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadSharedImages();
    AnalyticsService().setCurrentScreen(screenName: 'Image Cropper');
  }

  @override
  void didUpdateWidget(covariant ImageCropperScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedImagePaths != oldWidget.sharedImagePaths) {
      _loadSharedImages();
    }
  }

  void _loadSharedImages() {
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      setState(() {
        _selectedImages = widget.sharedImagePaths!.map((p) => File(p)).toList();
        _croppedImages = List.generate(_selectedImages.length, (index) => CroppedImageData());
        _currentImageIndex = 0;
      });
      _loadCurrentImage();
      print('[ImageCropperScreen] Loaded ${_selectedImages.length} shared image(s)');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.photos.request();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images.map((xFile) => File(xFile.path)).toList();
        _croppedImages = List.generate(_selectedImages.length, (index) => CroppedImageData());
        _currentImageIndex = 0;
      });
      await _loadCurrentImage();
    }
  }

  Future<void> _loadCurrentImage() async {
    if (_selectedImages.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final File currentImage = _selectedImages[_currentImageIndex];
      final Uint8List bytes = await currentImage.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      _currentUiImage = frameInfo.image;
      
      // Calculate display dimensions to fit in the crop area
      final double maxWidth = MediaQuery.of(context).size.width - 40;
      final double maxHeight = 400;
      
      final double imageAspectRatio = _currentUiImage!.width / _currentUiImage!.height;
      final double maxAspectRatio = maxWidth / maxHeight;
      
      if (imageAspectRatio > maxAspectRatio) {
        _imageDisplayWidth = maxWidth;
        _imageDisplayHeight = maxWidth / imageAspectRatio;
      } else {
        _imageDisplayHeight = maxHeight;
        _imageDisplayWidth = maxHeight * imageAspectRatio;
      }
      
      // Check if this image has saved crop settings
      final CroppedImageData currentData = _croppedImages[_currentImageIndex];
      if (currentData.displayCropWidth > 0 && currentData.displayImageWidth == _imageDisplayWidth) {
        // Restore saved crop settings
        _cropX = currentData.displayCropX;
        _cropY = currentData.displayCropY;
        _cropWidth = currentData.displayCropWidth;
        _cropHeight = currentData.displayCropHeight;
        _rotation = currentData.rotation;
        _flipHorizontal = currentData.flipHorizontal;
        _flipVertical = currentData.flipVertical;
      } else {
        // Initialize crop area to center of image (first time)
        _cropWidth = _imageDisplayWidth * 0.6;
        _cropHeight = _imageDisplayHeight * 0.6;
        _cropX = (_imageDisplayWidth - _cropWidth) / 2;
        _cropY = (_imageDisplayHeight - _cropHeight) / 2;
        _rotation = 0;
        _flipHorizontal = false;
        _flipVertical = false;
      }
      
      // Reset image transform
      _imageScale = 1.0;
      _imageOffsetX = 0.0;
      _imageOffsetY = 0.0;
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load image. Please try again.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onPanStart(DragStartDetails details) {
    final Offset localPosition = details.localPosition;
    
    // Larger touch targets for better usability
    const double cornerHandleSize = 30.0;
    const double edgeHandleSize = 20.0;
    
    // Check if touching corner handles for resizing (priority)
    final bool isTopLeft = (localPosition.dx - _cropX).abs() < cornerHandleSize && 
                          (localPosition.dy - _cropY).abs() < cornerHandleSize;
    final bool isTopRight = (localPosition.dx - (_cropX + _cropWidth)).abs() < cornerHandleSize && 
                           (localPosition.dy - _cropY).abs() < cornerHandleSize;
    final bool isBottomLeft = (localPosition.dx - _cropX).abs() < cornerHandleSize && 
                             (localPosition.dy - (_cropY + _cropHeight)).abs() < cornerHandleSize;
    final bool isBottomRight = (localPosition.dx - (_cropX + _cropWidth)).abs() < cornerHandleSize && 
                              (localPosition.dy - (_cropY + _cropHeight)).abs() < cornerHandleSize;
    
    if (isTopLeft || isTopRight || isBottomLeft || isBottomRight) {
      setState(() => _isResizing = true);
      _lastPanPosition = localPosition;
      return;
    }
    
    // Check if touching edge handles for resizing
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
      setState(() => _isResizing = true);
      _lastPanPosition = localPosition;
      return;
    }
    
    // Check if inside crop area for dragging
    if (localPosition.dx >= _cropX && localPosition.dx <= _cropX + _cropWidth &&
        localPosition.dy >= _cropY && localPosition.dy <= _cropY + _cropHeight) {
      setState(() => _isDragging = true);
    }
    
    _lastPanPosition = localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging && !_isResizing) return;
    
    final Offset delta = details.localPosition - _lastPanPosition!;
    
    if (_isDragging) {
      setState(() {
        _cropX = (_cropX + delta.dx).clamp(0.0, _imageDisplayWidth - _cropWidth);
        _cropY = (_cropY + delta.dy).clamp(0.0, _imageDisplayHeight - _cropHeight);
      });
    } else if (_isResizing) {
      // Determine which handle based on initial position
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
          // Resize from top-left corner
          _cropX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50);
          _cropY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50);
          _cropWidth = (_cropWidth - delta.dx).clamp(50.0, _imageDisplayWidth - _cropX);
          _cropHeight = (_cropHeight - delta.dy).clamp(50.0, _imageDisplayHeight - _cropY);
        } else if (isTopRight) {
          // Resize from top-right corner
          _cropY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50);
          _cropWidth = (_cropWidth + delta.dx).clamp(50.0, _imageDisplayWidth - _cropX);
          _cropHeight = (_cropHeight - delta.dy).clamp(50.0, _imageDisplayHeight - _cropY);
        } else if (isBottomLeft) {
          // Resize from bottom-left corner
          _cropX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50);
          _cropWidth = (_cropWidth - delta.dx).clamp(50.0, _imageDisplayWidth - _cropX);
          _cropHeight = (_cropHeight + delta.dy).clamp(50.0, _imageDisplayHeight - _cropY);
        } else if (isBottomRight) {
          // Resize from bottom-right corner
          _cropWidth = (_cropWidth + delta.dx).clamp(50.0, _imageDisplayWidth - _cropX);
          _cropHeight = (_cropHeight + delta.dy).clamp(50.0, _imageDisplayHeight - _cropY);
        } else if (isTopEdge) {
          // Resize from top edge
          _cropY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50);
          _cropHeight = (_cropHeight - delta.dy).clamp(50.0, _imageDisplayHeight - _cropY);
        } else if (isBottomEdge) {
          // Resize from bottom edge
          _cropHeight = (_cropHeight + delta.dy).clamp(50.0, _imageDisplayHeight - _cropY);
        } else if (isLeftEdge) {
          // Resize from left edge
          _cropX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50);
          _cropWidth = (_cropWidth - delta.dx).clamp(50.0, _imageDisplayWidth - _cropX);
        } else if (isRightEdge) {
          // Resize from right edge
          _cropWidth = (_cropWidth + delta.dx).clamp(50.0, _imageDisplayWidth - _cropX);
        }
        
        // Apply aspect ratio constraint if selected
        if (_selectedAspectRatio != null && _selectedAspectRatio != 'free') {
          final aspectRatio = _aspectRatios[_selectedAspectRatio!]!['ratio'] as double;
          final double currentRatio = _cropWidth / _cropHeight;
          
          if (currentRatio > aspectRatio) {
            // Current crop is wider than target ratio, adjust width
            _cropWidth = _cropHeight * aspectRatio;
          } else {
            // Current crop is taller than target ratio, adjust height
            _cropHeight = _cropWidth / aspectRatio;
          }
          
          // Ensure crop area stays within image bounds
          if (_cropX + _cropWidth > _imageDisplayWidth) {
            _cropX = _imageDisplayWidth - _cropWidth;
          }
          if (_cropY + _cropHeight > _imageDisplayHeight) {
            _cropY = _imageDisplayHeight - _cropHeight;
          }
        }
      });
    }
    
    _lastPanPosition = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isResizing = false;
    });
    _lastPanPosition = null;
  }

  void _applyAspectRatio(String aspectRatioKey) {
    if (aspectRatioKey == 'free') {
      setState(() {
        _selectedAspectRatio = null;
      });
      return;
    }

    final aspectRatio = _aspectRatios[aspectRatioKey]!['ratio'] as double;
    setState(() {
      _selectedAspectRatio = aspectRatioKey;
      
      // Calculate new dimensions maintaining aspect ratio
      final double currentRatio = _cropWidth / _cropHeight;
      
      if (currentRatio > aspectRatio) {
        // Current crop is wider than target ratio, adjust width
        _cropWidth = _cropHeight * aspectRatio;
      } else {
        // Current crop is taller than target ratio, adjust height
        _cropHeight = _cropWidth / aspectRatio;
      }
      
      // Ensure crop area stays within image bounds
      if (_cropX + _cropWidth > _imageDisplayWidth) {
        _cropX = _imageDisplayWidth - _cropWidth;
      }
      if (_cropY + _cropHeight > _imageDisplayHeight) {
        _cropY = _imageDisplayHeight - _cropHeight;
      }
      
      // Ensure minimum size
      _cropWidth = _cropWidth.clamp(50.0, _imageDisplayWidth - _cropX);
      _cropHeight = _cropHeight.clamp(50.0, _imageDisplayHeight - _cropY);
    });
  }

  void _saveCurrentCropSettings() {
    // Save current crop settings to the data object
    _croppedImages[_currentImageIndex].displayCropX = _cropX;
    _croppedImages[_currentImageIndex].displayCropY = _cropY;
    _croppedImages[_currentImageIndex].displayCropWidth = _cropWidth;
    _croppedImages[_currentImageIndex].displayCropHeight = _cropHeight;
    _croppedImages[_currentImageIndex].displayImageWidth = _imageDisplayWidth;
    _croppedImages[_currentImageIndex].displayImageHeight = _imageDisplayHeight;
    _croppedImages[_currentImageIndex].rotation = _rotation;
    _croppedImages[_currentImageIndex].flipHorizontal = _flipHorizontal;
    _croppedImages[_currentImageIndex].flipVertical = _flipVertical;
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      _saveCurrentCropSettings();
      setState(() {
        _currentImageIndex--;
      });
      _loadCurrentImage();
    }
  }

  void _nextImage() {
    if (_currentImageIndex < _selectedImages.length - 1) {
      _saveCurrentCropSettings();
      setState(() {
        _currentImageIndex++;
      });
      _loadCurrentImage();
    }
  }

  void _undoCrop() {
    setState(() {
      _croppedImages[_currentImageIndex] = CroppedImageData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crop undone'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _removeCurrentImage() {
    if (_selectedImages.isEmpty) return;
    
    setState(() {
      _selectedImages.removeAt(_currentImageIndex);
      _croppedImages.removeAt(_currentImageIndex);
      
      // Adjust current index
      if (_currentImageIndex >= _selectedImages.length && _selectedImages.isNotEmpty) {
        _currentImageIndex = _selectedImages.length - 1;
      }
      
      // If no images left, reset
      if (_selectedImages.isEmpty) {
        _currentImageIndex = 0;
        _currentUiImage = null;
      }
    });
    
    // Reload current image if there are still images
    if (_selectedImages.isNotEmpty) {
      _loadCurrentImage();
    }
  }

  void _rotateImage() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
      // Reset crop area when rotating
      if (_rotation == 90 || _rotation == 270) {
        // Swap width and height
        final temp = _imageDisplayWidth;
        _imageDisplayWidth = _imageDisplayHeight;
        _imageDisplayHeight = temp;
      }
      _cropWidth = _imageDisplayWidth * 0.6;
      _cropHeight = _imageDisplayHeight * 0.6;
      _cropX = (_imageDisplayWidth - _cropWidth) / 2;
      _cropY = (_imageDisplayHeight - _cropHeight) / 2;
    });
  }

  void _flipHorizontally() {
    setState(() {
      _flipHorizontal = !_flipHorizontal;
    });
  }

  void _flipVertically() {
    setState(() {
      _flipVertical = !_flipVertical;
    });
  }

  void _resetCrop() {
    setState(() {
      _cropWidth = _imageDisplayWidth * 0.6;
      _cropHeight = _imageDisplayHeight * 0.6;
      _cropX = (_imageDisplayWidth - _cropWidth) / 2;
      _cropY = (_imageDisplayHeight - _cropHeight) / 2;
      _rotation = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _selectedAspectRatio = null;
    });
  }

  Future<void> _cropCurrentImage() async {
    if (_currentUiImage == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final File currentImageFile = _selectedImages[_currentImageIndex];
      
      // Calculate crop coordinates in image pixels
      final int originalWidth = _currentUiImage!.width;
      final int originalHeight = _currentUiImage!.height;
      
      final double imageAspectRatio = originalWidth / originalHeight;
      final double displayAspectRatio = _imageDisplayWidth / _imageDisplayHeight;
      
      double imageDisplayX = 0;
      double imageDisplayY = 0;
      double imageDisplayWidth = _imageDisplayWidth;
      double imageDisplayHeight = _imageDisplayHeight;
      
      if (imageAspectRatio > displayAspectRatio) {
        imageDisplayWidth = _imageDisplayHeight * imageAspectRatio;
        imageDisplayX = (_imageDisplayWidth - imageDisplayWidth) / 2;
      } else {
        imageDisplayHeight = _imageDisplayWidth / imageAspectRatio;
        imageDisplayY = (_imageDisplayHeight - imageDisplayHeight) / 2;
      }
      
      final double scaleX = originalWidth / imageDisplayWidth;
      final double scaleY = originalHeight / imageDisplayHeight;
      
      final double adjustedCropX = _cropX - imageDisplayX;
      final double adjustedCropY = _cropY - imageDisplayY;
      
      final int cropX = (adjustedCropX * scaleX).round().clamp(0, originalWidth);
      final int cropY = (adjustedCropY * scaleY).round().clamp(0, originalHeight);
      final int cropWidth = (_cropWidth * scaleX).round().clamp(1, originalWidth - cropX);
      final int cropHeight = (_cropHeight * scaleY).round().clamp(1, originalHeight - cropY);

      final startTime = DateTime.now();
      final List<dynamic>? results = await _channel.invokeMethod('cropImagesBatch', {
        'items': [{
          'inputPath': currentImageFile.path,
          'x': cropX,
          'y': cropY,
          'width': cropWidth,
          'height': cropHeight,
          'rotation': _rotation,
          'isFlipped': _flipHorizontal,
        }]
      });
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

      if (results != null && results.isNotEmpty) {
        final path = results.first as String;
        if (widget.returnResultOnCrop) {
          Navigator.pop(context, path);
        } else {
          _showSingleCropSuccessDialog(path, duration);
        }
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cropping image: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _scanMediaFile(String filePath) async {
    try {
      await _channel.invokeMethod('scanMediaFile', {
        'filePath': filePath,
        'mimeType': 'image/jpeg',
      });
    } catch (e) {
      // Silently fail - media scanner is not critical
    }
  }

  Future<void> _exportAllCroppedImages() async {
    if (_selectedImages.isEmpty) return;
    AnalyticsService().logSaveAction(feature: 'image_cropper', type: 'image_batch');
    AnalyticsService().logEvent(
      name: 'bulk_crop_started',
    );
    setState(() => _isLoading = true);
    
    try {
      AnalyticsService().logImageBulkCropStarted(imageCount: _selectedImages.length);
      final List<Map<String, dynamic>> items = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final data = _croppedImages[i];
        final File file = _selectedImages[i];
        
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final originalWidth = frame.image.width;
        final originalHeight = frame.image.height;
        
        final double imageAspectRatio = originalWidth / originalHeight;
        final double displayAspectRatio = _imageDisplayWidth / _imageDisplayHeight;
        
        double imageDisplayX = 0;
        double imageDisplayY = 0;
        double imageDisplayWidth = _imageDisplayWidth;
        double imageDisplayHeight = _imageDisplayHeight;
        
        if (imageAspectRatio > displayAspectRatio) {
          imageDisplayWidth = _imageDisplayHeight * imageAspectRatio;
          imageDisplayX = (_imageDisplayWidth - imageDisplayWidth) / 2;
        } else {
          imageDisplayHeight = _imageDisplayWidth / imageAspectRatio;
          imageDisplayY = (_imageDisplayHeight - imageDisplayHeight) / 2;
        }
        
        final double scaleX = originalWidth / imageDisplayWidth;
        final double scaleY = originalHeight / imageDisplayHeight;
        
        final dX = data.displayCropWidth > 0 ? data.displayCropX : _cropX;
        final dY = data.displayCropWidth > 0 ? data.displayCropY : _cropY;
        final dW = data.displayCropWidth > 0 ? data.displayCropWidth : _cropWidth;
        final dH = data.displayCropWidth > 0 ? data.displayCropHeight : _cropHeight;
        final rot = data.displayCropWidth > 0 ? data.rotation : _rotation;
        final flip = data.displayCropWidth > 0 ? data.flipHorizontal : _flipHorizontal;

        final adjustedCropX = dX - imageDisplayX;
        final adjustedCropY = dY - imageDisplayY;
        
        final int cropX = (adjustedCropX * scaleX).round().clamp(0, originalWidth);
        final int cropY = (adjustedCropY * scaleY).round().clamp(0, originalHeight);
        final int cropWidth = (dW * scaleX).round().clamp(1, originalWidth - cropX);
        final int cropHeight = (dH * scaleY).round().clamp(1, originalHeight - cropY);

        items.add({
          'inputPath': file.path,
          'x': cropX,
          'y': cropY,
          'width': cropWidth,
          'height': cropHeight,
          'rotation': rot,
          'isFlipped': flip,
        });
      }

      final startTime = DateTime.now();
      final List<dynamic>? results = await _channel.invokeMethod('cropImagesBatch', {
        'items': items
      });
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

      if (results != null && results.isNotEmpty) {
        // Cache the result files back to the state so we can navigate to text box later
        for (int i = 0; i < results.length; i++) {
          _croppedImages[i].file = File(results[i] as String);
        }
        AnalyticsService().logImageBulkCropSuccess(
          imageCount: results.length,
          processingTimeMs: endTime.difference(startTime).inMilliseconds,
        );
        _showExportSuccessDialog(results.length, 'Gallery', duration);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting images: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _showSingleCropSuccessDialog(String path, double duration) {
    AdService().showInterstitialAd();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Gradient
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[700]!, Colors.purple[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background pattern or glow
                      Positioned(
                        right: -20,
                        top: -20,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Crop Perfected!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Info Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.speed, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                Text(
                                  '${duration.toStringAsFixed(2)}s',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt, size: 16, color: Colors.purple[700]),
                                const SizedBox(width: 6),
                                Text(
                                  'GPU Engine',
                                  style: TextStyle(
                                    color: Colors.purple[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your image has been processed using our hardware-accelerated Pro Engine.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              HomeShellScreen.navigateToTab(
                                9,
                                paths: [path],
                                purpose: 'cropper',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[600],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.text_fields),
                                SizedBox(width: 12),
                                Text('Add Text Overlay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // New Action: Save to Gallery
                          StatefulBuilder(
                            builder: (context, setDialogState) {
                              bool isSaved = false;
                              return OutlinedButton.icon(
                                onPressed: isSaved ? null : () async {
                                  try {
                                    final result = await _channel.invokeMethod<String>('saveImageToGallery', {'imagePath': path});
                                    if (result != null) {
                                      setDialogState(() => isSaved = true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Image saved to Gallery!')),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Save failed: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(isSaved ? Icons.check : Icons.download_rounded, size: 20),
                                label: Text(isSaved ? 'Saved to Gallery' : 'Save to Gallery', style: const TextStyle(fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isSaved ? Colors.grey[100] : Colors.blue[50],
                                  foregroundColor: isSaved ? Colors.grey[600] : Colors.blue[700],
                                  minimumSize: const Size(double.infinity, 54),
                                  side: BorderSide(color: isSaved ? Colors.grey[300]! : Colors.blue[200]!),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    await OpenFile.open(path);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  child: Text('View Image', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text('Dismiss', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExportSuccessDialog(int count, String path, double duration) {
    AdService().showInterstitialAd();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Success Gradient
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[700]!, Colors.green[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: -10,
                        bottom: -10,
                        child: Icon(Icons.check_circle_outline, size: 100, color: Colors.white.withOpacity(0.1)),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.batch_prediction_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Batch Complete!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Subtitle
                      Text(
                        'Successfully processed $count images',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Metrics Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.timer_outlined, color: Colors.blue[700], size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${duration.toStringAsFixed(2)}s',
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text('Total Time', style: TextStyle(color: Colors.blue[400], fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange[100]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.bolt_rounded, color: Colors.orange[700], size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'v2.0',
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text('GPU Engine', style: TextStyle(color: Colors.orange[400], fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Primary Action
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          final firstImg = _croppedImages.firstWhere((img) => img.file != null);
                          HomeShellScreen.navigateToTab(
                            9,
                            paths: [firstImg.file!.path],
                            purpose: 'cropper',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: Colors.purple.withOpacity(0.4),
                        ),
                        child: const Text('Design with Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      // New Action: Save to Gallery
                      StatefulBuilder(
                        builder: (context, setDialogState) {
                          bool isSaved = false;
                          return OutlinedButton.icon(
                            onPressed: isSaved ? null : () async {
                              try {
                                final List<String> newPaths = [];
                                for (var imgData in _croppedImages) {
                                  if (imgData.file != null) {
                                    final result = await _channel.invokeMethod<String>('saveImageToGallery', {'imagePath': imgData.file!.path});
                                    if (result != null) newPaths.add(result);
                                  }
                                }
                                
                                // Update file paths so subsequent actions use gallery paths
                                for (int i = 0; i < _croppedImages.length; i++) {
                                  if (i < newPaths.length) {
                                    _croppedImages[i].file = File(newPaths[i]);
                                  }
                                }
                                
                                setDialogState(() => isSaved = true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('All images saved to Gallery!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Save failed: $e')),
                                  );
                                }
                              }
                            },
                            icon: Icon(isSaved ? Icons.check : Icons.download_rounded, size: 20),
                            label: Text(isSaved ? 'Saved to Gallery' : 'Save all to Gallery', style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isSaved ? Colors.grey[100] : Colors.blue[50],
                              foregroundColor: isSaved ? Colors.grey[600] : Colors.blue[700],
                              minimumSize: const Size(double.infinity, 54),
                              side: BorderSide(color: isSaved ? Colors.grey[300]! : Colors.blue[200]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Secondary Actions
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              label: const Text('Dismiss'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 20, color: Colors.grey[200]),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await OpenFile.open(path);
                              },
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Gallery'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selectedImages.isEmpty
            ? _buildEmptyState()
            : _buildCropperInterface(),
      ),
      bottomNavigationBar: _selectedImages.isNotEmpty ? _buildBottomNavBar() : null,
      floatingActionButton: _selectedImages.isNotEmpty ? FloatingActionButton(
        onPressed: _pickImages,
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add more images',
      ) : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No images selected',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the button below to select images',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Select Images'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropperInterface() {
    return Column(
      children: [
        // Combined counter, navigation, and aspect ratio selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Column(
            children: [
              // Top row: Counter and transform buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_currentImageIndex + 1}/${_selectedImages.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _removeCurrentImage,
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        tooltip: 'Remove image',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _rotateImage,
                        icon: const Icon(Icons.rotate_right, size: 20),
                        tooltip: 'Rotate 90°',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: _flipHorizontally,
                        icon: Icon(Icons.flip, size: 20, color: _flipHorizontal ? Colors.blue : null),
                        tooltip: 'Flip horizontal',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: _resetCrop,
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Reset',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: _croppedImages[_currentImageIndex].file != null ? _undoCrop : null,
                        icon: const Icon(Icons.undo, size: 20),
                        tooltip: 'Undo crop',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bottom row: Aspect ratio selector
              SizedBox(
                height: 35,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aspectRatios.length,
                  itemBuilder: (context, index) {
                    final aspectRatioKey = _aspectRatios.keys.elementAt(index);
                    final aspectRatioData = _aspectRatios[aspectRatioKey]!;
                    final isSelected = _selectedAspectRatio == aspectRatioKey;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _applyAspectRatio(aspectRatioKey),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.purple : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected ? Colors.purple : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                aspectRatioData['icon'] as IconData,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                aspectRatioData['name'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      
        // Image display area - Responsive with max height
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                final double maxHeight = 420.0;
                // Center a sized box to limit height while filling width
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: availableWidth,
                      maxHeight: maxHeight,
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _currentUiImage == null
                            ? const Center(child: Text('Error loading image'))
                            : _buildImageCropper(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCropper() {
    return Center(
      child: Container(
        width: _imageDisplayWidth,
        height: _imageDisplayHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: ImagePainter(
                    _currentUiImage!,
                    rotation: _rotation,
                    flipHorizontal: _flipHorizontal,
                    flipVertical: _flipVertical,
                  ),
                ),
              ),
            ),
            
            // Crop overlay
            Positioned.fill(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: CropOverlayPainter(
                    cropX: _cropX,
                    cropY: _cropY,
                    cropWidth: _cropWidth,
                    cropHeight: _cropHeight,
                    imageWidth: _imageDisplayWidth,
                    imageHeight: _imageDisplayHeight,
                    isDragging: _isDragging,
                    isResizing: _isResizing,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bottom Nav Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // Navigation and crop controls
            Row(
              children: [
                // Previous button
                IconButton(
                  onPressed: _currentImageIndex > 0 ? _previousImage : null,
                  icon: const Icon(Icons.chevron_left, size: 24),
                  tooltip: 'Previous image',
                  style: IconButton.styleFrom(
                    backgroundColor: _currentImageIndex > 0 ? Colors.grey[200] : Colors.grey[100],
                    foregroundColor: _currentImageIndex > 0 ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                // Crop This button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _croppedImages[_currentImageIndex].file != null ? null : _cropCurrentImage,
                    child: Text(
                      _croppedImages[_currentImageIndex].file != null ? 'Cropped' : 'Crop This',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _croppedImages[_currentImageIndex].file != null ? Colors.green : Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Export All button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedImages.isNotEmpty ? _exportAllCroppedImages : null,
                    child: const Text(
                      'Export All',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Next button
                IconButton(
                  onPressed: _currentImageIndex < _selectedImages.length - 1 ? _nextImage : null,
                  icon: const Icon(Icons.chevron_right, size: 24),
                  tooltip: 'Next image',
                  style: IconButton.styleFrom(
                    backgroundColor: _currentImageIndex < _selectedImages.length - 1 ? Colors.grey[200] : Colors.grey[100],
                    foregroundColor: _currentImageIndex < _selectedImages.length - 1 ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress indicator
            if (_croppedImages.isNotEmpty)
              Row(
                children: [
                  const Text('Progress: '),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _croppedImages.where((data) => data.file != null).length / _croppedImages.length,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_croppedImages.where((data) => data.file != null).length}/${_croppedImages.length}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
          ],
        ),
      ),
        ),
      ],
    );
  }
}

class CroppedImageData {
  File? file;
  int cropX;
  int cropY;
  int cropWidth;
  int cropHeight;
  
  // Store display crop settings (for UI restoration)
  double displayCropX;
  double displayCropY;
  double displayCropWidth;
  double displayCropHeight;
  double displayImageWidth;
  double displayImageHeight;
  
  // Transform settings
  int rotation;
  bool flipHorizontal;
  bool flipVertical;

  CroppedImageData({
    this.file,
    this.cropX = 0,
    this.cropY = 0,
    this.cropWidth = 0,
    this.cropHeight = 0,
    this.displayCropX = 0,
    this.displayCropY = 0,
    this.displayCropWidth = 0,
    this.displayCropHeight = 0,
    this.displayImageWidth = 0,
    this.displayImageHeight = 0,
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final int rotation;
  final bool flipHorizontal;
  final bool flipVertical;

  ImagePainter(
    this.image, {
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    
    // Save canvas state
    canvas.save();
    
    // Apply transformations from center
    canvas.translate(size.width / 2, size.height / 2);
    
    // Apply rotation
    if (rotation != 0) {
      canvas.rotate(rotation * 3.14159 / 180);
    }
    
    // Apply flips
    canvas.scale(
      flipHorizontal ? -1.0 : 1.0,
      flipVertical ? -1.0 : 1.0,
    );
    
    // Translate back
    canvas.translate(-size.width / 2, -size.height / 2);
    
    // Calculate aspect ratios
    final double imageAspectRatio = image.width / image.height;
    final double displayAspectRatio = size.width / size.height;
    
    Rect sourceRect;
    Rect destRect;
    
    if (imageAspectRatio > displayAspectRatio) {
      // Image is wider than display - fit to height
      final double scaledWidth = size.height * imageAspectRatio;
      final double offsetX = (size.width - scaledWidth) / 2;
      sourceRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      destRect = Rect.fromLTWH(offsetX, 0, scaledWidth, size.height);
    } else {
      // Image is taller than display - fit to width
      final double scaledHeight = size.width / imageAspectRatio;
      final double offsetY = (size.height - scaledHeight) / 2;
      sourceRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      destRect = Rect.fromLTWH(0, offsetY, size.width, scaledHeight);
    }
    
    canvas.drawImageRect(image, sourceRect, destRect, paint);
    
    // Restore canvas state
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
           oldDelegate.flipHorizontal != flipHorizontal ||
           oldDelegate.flipVertical != flipVertical;
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
