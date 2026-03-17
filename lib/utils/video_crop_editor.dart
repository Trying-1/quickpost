import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../screens/video_cropper/video_cropper_screen.dart';

class VideoCropEditor extends StatefulWidget {
  final File videoFile;
  final CroppedVideoData initialCrop;
  final ValueChanged<CroppedVideoData> onCropChanged;
  final bool isMuted;
  final VoidCallback onMuteToggle;

  const VideoCropEditor({
    super.key,
    required this.videoFile,
    required this.initialCrop,
    required this.onCropChanged,
    required this.isMuted,
    required this.onMuteToggle,
  });

  @override
  State<VideoCropEditor> createState() => _VideoCropEditorState();
}

class _VideoCropEditorState extends State<VideoCropEditor> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  // Aspect ratio presets (matching Image Cropper)
  String? _selectedAspectRatio = 'free';
  static const Map<String, Map<String, dynamic>> _aspectRatios = {
    'free': {'name': 'Free', 'ratio': null, 'icon': Icons.crop_free},
    '1:1': {'name': '1:1', 'ratio': 1.0, 'icon': Icons.crop_square},
    '4:3': {'name': '4:3', 'ratio': 4 / 3, 'icon': Icons.crop_landscape},
    '3:4': {'name': '3:4', 'ratio': 3 / 4, 'icon': Icons.crop_portrait},
    '16:9': {'name': '16:9', 'ratio': 16 / 9, 'icon': Icons.crop_landscape},
    '9:16': {'name': '9:16', 'ratio': 9 / 16, 'icon': Icons.crop_portrait},
  };

  // Crop area properties (Matching Image Cropper style)
  double _cropX = 0.0;
  double _cropY = 0.0;
  double _cropWidth = 200.0;
  double _cropHeight = 200.0;
  
  // Gesture handling
  bool _isDragging = false;
  bool _isResizing = false;
  Offset? _lastPanPosition;

  double _videoDisplayWidth = 0.0;
  double _videoDisplayHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..setLooping(true)
      ..setVolume(widget.isMuted ? 0 : 1)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.play();
        _initializeCropArea();
        setState(() {
          _isInitialized = true;
        });
      });
  }

  void _initializeCropArea() {
    final size = _controller.value.size;
    if (size.width == 0 || size.height == 0) return;

    final double maxWidth = MediaQuery.of(context).size.width - 40;
    final double maxHeight = 400.0;
    
    final double videoAspectRatio = size.width / size.height;
    final double maxAspectRatio = maxWidth / maxHeight;
    
    if (videoAspectRatio > maxAspectRatio) {
      _videoDisplayWidth = maxWidth;
      _videoDisplayHeight = maxWidth / videoAspectRatio;
    } else {
      _videoDisplayHeight = maxHeight;
      _videoDisplayWidth = maxHeight * videoAspectRatio;
    }

    // Initialize crop area to center (~60% of video) and respect aspect ratio
    final dynamic ratioValue = _selectedAspectRatio == null || _selectedAspectRatio == 'free'
        ? null
        : _aspectRatios[_selectedAspectRatio!]!['ratio'];

    if (ratioValue == null) {
      // Free
      _cropWidth = _videoDisplayWidth * 0.6;
      _cropHeight = _videoDisplayHeight * 0.6;
    } else {
      final double ratio = ratioValue as double;
      final double targetW = _videoDisplayWidth * 0.6;
      final double targetH = _videoDisplayHeight * 0.6;

      // Largest rect that fits inside targetW x targetH with this ratio
      double w = targetW;
      double h = w / ratio;
      if (h > targetH) {
        h = targetH;
        w = h * ratio;
      }
      _cropWidth = w;
      _cropHeight = h;
    }

    _cropX = (_videoDisplayWidth - _cropWidth) / 2;
    _cropY = (_videoDisplayHeight - _cropHeight) / 2;
    
    _updateParentCrop();
  }

  void _updateParentCrop() {
    final size = _controller.value.size;
    final double scaleX = size.width / _videoDisplayWidth;
    final double scaleY = size.height / _videoDisplayHeight;

    int x = (_cropX * scaleX).round();
    int y = (_cropY * scaleY).round();
    int w = (_cropWidth * scaleX).round();
    int h = (_cropHeight * scaleY).round();

    // Match native behavior: even-aligned crop rect (common requirement for yuv420p)
    if (x.isOdd) x -= 1;
    if (y.isOdd) y -= 1;
    if (w.isOdd) w -= 1;
    if (h.isOdd) h -= 1;

    final int maxW = size.width.toInt();
    final int maxH = size.height.toInt();
    x = x.clamp(0, maxW);
    y = y.clamp(0, maxH);
    w = w.clamp(2, maxW);
    h = h.clamp(2, maxH);

    // Ensure the crop rect stays inside bounds after rounding
    if (x + w > maxW) {
      w = (maxW - x).clamp(2, maxW);
      if (w.isOdd) w -= 1;
    }
    if (y + h > maxH) {
      h = (maxH - y).clamp(2, maxH);
      if (h.isOdd) h -= 1;
    }

    widget.onCropChanged(CroppedVideoData(
      cropX: x,
      cropY: y,
      cropWidth: w,
      cropHeight: h,
    ));
  }

  void _onPanStart(DragStartDetails details) {
    final Offset localPosition = details.localPosition;
    const double handleSize = 30.0;

    // Check corners for resizing
    bool isTopLeft = (localPosition.dx - _cropX).abs() < handleSize && (localPosition.dy - _cropY).abs() < handleSize;
    bool isTopRight = (localPosition.dx - (_cropX + _cropWidth)).abs() < handleSize && (localPosition.dy - _cropY).abs() < handleSize;
    bool isBottomLeft = (localPosition.dx - _cropX).abs() < handleSize && (localPosition.dy - (_cropY + _cropHeight)).abs() < handleSize;
    bool isBottomRight = (localPosition.dx - (_cropX + _cropWidth)).abs() < handleSize && (localPosition.dy - (_cropY + _cropHeight)).abs() < handleSize;

    if (isTopLeft || isTopRight || isBottomLeft || isBottomRight) {
      setState(() => _isResizing = true);
    } else if (localPosition.dx >= _cropX && localPosition.dx <= _cropX + _cropWidth &&
               localPosition.dy >= _cropY && localPosition.dy <= _cropY + _cropHeight) {
      setState(() => _isDragging = true);
    }
    _lastPanPosition = localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging && !_isResizing) return;
    final Offset delta = details.localPosition - _lastPanPosition!;
    
    setState(() {
      if (_isDragging) {
        _cropX = (_cropX + delta.dx).clamp(0.0, _videoDisplayWidth - _cropWidth);
        _cropY = (_cropY + delta.dy).clamp(0.0, _videoDisplayHeight - _cropHeight);
      } else if (_isResizing) {
        final Offset startPos = _lastPanPosition!;
        const double handleSize = 30.0;

        bool isTopLeft = (startPos.dx - _cropX).abs() < handleSize && (startPos.dy - _cropY).abs() < handleSize;
        bool isTopRight = (startPos.dx - (_cropX + _cropWidth)).abs() < handleSize && (startPos.dy - _cropY).abs() < handleSize;
        bool isBottomLeft = (startPos.dx - _cropX).abs() < handleSize && (startPos.dy - (_cropY + _cropHeight)).abs() < handleSize;
        bool isBottomRight = (startPos.dx - (_cropX + _cropWidth)).abs() < handleSize && (startPos.dy - (_cropY + _cropHeight)).abs() < handleSize;

        final dynamic ratioValue = _selectedAspectRatio == null || _selectedAspectRatio == 'free'
            ? null
            : _aspectRatios[_selectedAspectRatio!]!['ratio'];

        if (ratioValue == null) {
          // Free resize from any corner
          if (isTopLeft) {
            final double newX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50.0);
            final double newY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50.0);
            _cropWidth += (_cropX - newX);
            _cropHeight += (_cropY - newY);
            _cropX = newX;
            _cropY = newY;
          } else if (isTopRight) {
            _cropWidth = (_cropWidth + delta.dx).clamp(50.0, _videoDisplayWidth - _cropX);
            final double newY = (_cropY + delta.dy).clamp(0.0, _cropY + _cropHeight - 50.0);
            _cropHeight += (_cropY - newY);
            _cropY = newY;
          } else if (isBottomLeft) {
            final double newX = (_cropX + delta.dx).clamp(0.0, _cropX + _cropWidth - 50.0);
            _cropWidth += (_cropX - newX);
            _cropX = newX;
            _cropHeight = (_cropHeight + delta.dy).clamp(50.0, _videoDisplayHeight - _cropY);
          } else if (isBottomRight) {
            _cropWidth = (_cropWidth + delta.dx).clamp(50.0, _videoDisplayWidth - _cropX);
            _cropHeight = (_cropHeight + delta.dy).clamp(50.0, _videoDisplayHeight - _cropY);
          }
        } else {
          final double ratio = ratioValue as double;
          // Constrained resize (simplified for bottom-right logic mainly, but applying to others)
          if (isTopLeft || isBottomLeft) {
             // Handle left-side resize with ratio
             double newW = (_cropWidth - delta.dx).clamp(50.0, _cropX + _cropWidth);
             double newH = newW / ratio;
             if (newH > _videoDisplayHeight) {
                newH = _videoDisplayHeight;
                newW = newH * ratio;
             }
             _cropX += (_cropWidth - newW);
             _cropWidth = newW;
             _cropHeight = newH;
          } else {
             // Handle right-side resize with ratio
             double newW = (_cropWidth + delta.dx).clamp(50.0, _videoDisplayWidth - _cropX);
             double newH = newW / ratio;
             if (_cropY + newH > _videoDisplayHeight) {
                newH = (_videoDisplayHeight - _cropY).clamp(50.0, _videoDisplayHeight);
                newW = newH * ratio;
             }
             _cropWidth = newW;
             _cropHeight = newH;
          }
        }
      }
    });
    _lastPanPosition = details.localPosition;
    _updateParentCrop();
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isResizing = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetPosition() {
    setState(() {
      _initializeCropArea();
    });
  }

  void _fitToFrame() {
    setState(() {
      final dynamic ratioValue = _selectedAspectRatio == null
          ? 1.0
          : _aspectRatios[_selectedAspectRatio!]!['ratio'];

      if (ratioValue == null) {
        // Free: fill entire display
        _cropX = 0;
        _cropY = 0;
        _cropWidth = _videoDisplayWidth;
        _cropHeight = _videoDisplayHeight;
      } else {
        final double ratio = ratioValue as double;
        // Largest rect fitting inside the video display
        double w = _videoDisplayWidth;
        double h = w / ratio;
        if (h > _videoDisplayHeight) {
          h = _videoDisplayHeight;
          w = h * ratio;
        }
        _cropWidth = w;
        _cropHeight = h;
        _cropX = (_videoDisplayWidth - _cropWidth) / 2;
        _cropY = (_videoDisplayHeight - _cropHeight) / 2;
      }
      _updateParentCrop();
    });
  }

  void _applyAspectRatio(String key) {
    setState(() {
      if (key == 'free') {
        _selectedAspectRatio = 'free';
      } else {
        _selectedAspectRatio = key;
      }

      final dynamic ratioValue = _aspectRatios[_selectedAspectRatio!]!['ratio'];
      if (ratioValue == null) {
        // keep current size
        _updateParentCrop();
        return;
      }

      final double ratio = ratioValue as double;
      final centerX = _cropX + _cropWidth / 2;
      final centerY = _cropY + _cropHeight / 2;

      // Adjust current crop to ratio by changing height based on width
      double newW = _cropWidth;
      double newH = newW / ratio;
      if (newH > _videoDisplayHeight) {
        newH = _videoDisplayHeight * 0.8;
        newW = newH * ratio;
      }

      _cropWidth = newW.clamp(50.0, _videoDisplayWidth);
      _cropHeight = newH.clamp(50.0, _videoDisplayHeight);
      _cropX = (centerX - _cropWidth / 2).clamp(0.0, _videoDisplayWidth - _cropWidth);
      _cropY = (centerY - _cropHeight / 2).clamp(0.0, _videoDisplayHeight - _cropHeight);

      _updateParentCrop();
    });
  }

  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _isInitialized
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _aspectRatios.entries.map((e) {
                              final key = e.key;
                              final name = e.value['name'] as String;
                              final selected = (_selectedAspectRatio ?? 'free') == key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(name),
                                  selected: selected,
                                  onSelected: (_) => _applyAspectRatio(key),
                                  selectedColor: Colors.blue,
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : Colors.white70,
                                  ),
                                  backgroundColor: Colors.grey[900],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        onTap: () => setState(() => _showControls = !_showControls),
                        child: Container(
                          width: _videoDisplayWidth,
                          height: _videoDisplayHeight,
                          color: Colors.black,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: _controller.value.aspectRatio,
                                    child: VideoPlayer(_controller),
                                  ),
                                ),
                              ),
                              // Dimmed overlay
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: CropOverlayPainter(
                                    cropX: _cropX,
                                    cropY: _cropY,
                                    cropWidth: _cropWidth,
                                    cropHeight: _cropHeight,
                                  ),
                                ),
                              ),
                              // Handles
                              _buildHandle(_cropX, _cropY), // TL
                              _buildHandle(_cropX + _cropWidth, _cropY), // TR
                              _buildHandle(_cropX, _cropY + _cropHeight), // BL
                              _buildHandle(_cropX + _cropWidth, _cropY + _cropHeight), // BR

                              if (_showControls)
                                Center(
                                  child: IconButton(
                                    iconSize: 64,
                                    icon: Icon(
                                      _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                      color: Colors.white70,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Mute toggle & Progress bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(widget.isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white70),
                              onPressed: widget.onMuteToggle,
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.blue,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHandle(double x, double y) {
    return Positioned(
      left: x - 10,
      top: y - 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final double cropX;
  final double cropY;
  final double cropWidth;
  final double cropHeight;

  CropOverlayPainter({
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(cropX, cropY, cropWidth, cropHeight);
    
    // Draw outside area
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(rect),
      ),
      paint,
    );

    // Draw white border for crop area
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);
    
    // Draw grid lines (matching Image Cropper)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cropX + (cropWidth * i / 3), cropY),
        Offset(cropX + (cropWidth * i / 3), cropY + cropHeight),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropX, cropY + (cropHeight * i / 3)),
        Offset(cropX + cropWidth, cropY + (cropHeight * i / 3)),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) => true;
}
