import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';

import '../home/home_shell_screen.dart';
import '../../services/app_review_service.dart';
import '../../utils/video_crop_editor.dart';

class VideoCropperScreen extends StatefulWidget {
  final List<String>? sharedVideoPaths;

  const VideoCropperScreen({super.key, this.sharedVideoPaths});

  @override
  State<VideoCropperScreen> createState() => _VideoCropperScreenState();
}

class _VideoCropperScreenState extends State<VideoCropperScreen> {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');

  final List<File> _selectedVideos = [];
  final List<CroppedVideoData> _croppedVideos = [];

  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadInitialVideos();
  }

  @override
  void didUpdateWidget(covariant VideoCropperScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedVideoPaths != oldWidget.sharedVideoPaths) {
      _loadInitialVideos();
    }
  }

  void _loadInitialVideos() {
    if (widget.sharedVideoPaths != null && widget.sharedVideoPaths!.isNotEmpty) {
      setState(() {
        _selectedVideos.clear();
        _selectedVideos.addAll(widget.sharedVideoPaths!.map((p) => File(p)));
        _croppedVideos
          ..clear()
          ..addAll(List.generate(_selectedVideos.length, (_) => CroppedVideoData()));
        _currentIndex = 0;
      });
    }
  }

  Future<void> _pickVideos() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      setState(() {
        _selectedVideos.add(File(video.path));
        _croppedVideos.add(CroppedVideoData());
        _currentIndex = _selectedVideos.length - 1;
      });
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  void _removeVideo() {
    if (_selectedVideos.isEmpty) return;
    setState(() {
      _selectedVideos.removeAt(_currentIndex);
      _croppedVideos.removeAt(_currentIndex);
      if (_currentIndex >= _selectedVideos.length && _selectedVideos.isNotEmpty) {
        _currentIndex = _selectedVideos.length - 1;
      }
    });
  }

  void _previousVideo() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _nextVideo() {
    if (_currentIndex < _selectedVideos.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _onCropUpdated(CroppedVideoData data) {
    if (_currentIndex >= 0 && _currentIndex < _croppedVideos.length) {
      setState(() {
        _croppedVideos[_currentIndex] = data;
      });
    }
  }

  Future<void> _processAll() async {
    if (_selectedVideos.isEmpty) return;
    // Check if all videos have a crop rect (Done was pressed)
    // For convenience, if not set, we could use a default center square
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final List<Map<String, dynamic>> items = [];
      for (int i = 0; i < _selectedVideos.length; i++) {
        final video = _selectedVideos[i];
        final crop = _croppedVideos[i];
        
        if (!crop.hasCropRect) {
          continue;
        }

        final outputPath = await _channel.invokeMethod<String>('getVideoOutputPath', {
          'filename': 'QuickPost_Cropped_${DateTime.now().millisecondsSinceEpoch}_$i.mp4',
        });

        debugPrint('[VideoCropper] Generated output path: $outputPath');

        if (outputPath == null || outputPath.isEmpty) {
          continue;
        }

        items.add({
          'inputPath': video.path,
          'outputPath': outputPath,
          'x': crop.cropX,
          'y': crop.cropY,
          'width': crop.cropWidth,
          'height': crop.cropHeight,
        });
      }

      if (items.isEmpty) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please crop the videos first')),
        );
        return;
      }

      final List<dynamic>? results = await _channel.invokeMethod('cropVideosBatch', {
        'items': items,
      });

      debugPrint('[VideoCropper] Crop results: $results');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        if (results != null && results.isNotEmpty) {
          final List<String> outputPaths = results.cast<String>();
          debugPrint('[VideoCropper] Final output paths: $outputPaths');
          _showCompletionDialog(outputPaths);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCompletionDialog(List<String> outputPaths) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Processing Complete'),
        content: Text('Successfully cropped ${outputPaths.length} videos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (outputPaths.isNotEmpty) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(outputPaths.first);
              },
              child: const Text('Open First'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final String path = outputPaths.first;
                debugPrint('[VideoCropper] Sending to Text Box: $path');
                final file = File(path);
                if (await file.exists()) {
                  final length = await file.length();
                  debugPrint('[VideoCropper] File exists, size: $length bytes');
                  if (length > 0) {
                    Navigator.pop(context);
                    HomeShellScreen.navigateToTab(
                      4, // Text Box Tab
                      paths: [path],
                      purpose: 'video_cropper', // Changed from 'text_box' to trigger refresh logic if needed
                    );
                  } else {
                    debugPrint('[VideoCropper] ERROR: File is empty');
                  }
                } else {
                  debugPrint('[VideoCropper] ERROR: File does not exist at path: $path');
                }
              },
              icon: const Icon(Icons.text_fields),
              label: const Text('Send to Text Box'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideos = _selectedVideos.isNotEmpty;
    final currentVideo = hasVideos ? _selectedVideos[_currentIndex] : null;
    final currentCrop = hasVideos ? _croppedVideos[_currentIndex] : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Video Cropper'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: hasVideos && !_isProcessing ? _processAll : null,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: hasVideos && currentVideo != null && currentCrop != null
                    ? KeyedSubtree(
                        key: ValueKey(currentVideo.path),
                        child: VideoCropEditor(
                          videoFile: currentVideo,
                          initialCrop: currentCrop,
                          onCropChanged: _onCropUpdated,
                          isMuted: _isMuted,
                          onMuteToggle: () => setState(() => _isMuted = !_isMuted),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_library_outlined, size: 64, color: Colors.black26),
                            const SizedBox(height: 16),
                            const Text(
                              'No videos selected',
                              style: TextStyle(color: Colors.black54, fontSize: 18),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _pickVideos,
                              icon: const Icon(Icons.add),
                              label: const Text('Pick Videos'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (hasVideos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_currentIndex + 1} / ${_selectedVideos.length}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _removeVideo,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Remove current video',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _currentIndex > 0 ? _previousVideo : null,
                            icon: const Icon(Icons.chevron_left, color: Colors.black),
                          ),
                          IconButton(
                            onPressed: _currentIndex < _selectedVideos.length - 1 ? _nextVideo : null,
                            icon: const Icon(Icons.chevron_right, color: Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing Videos...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CroppedVideoData {
  int cropX;
  int cropY;
  int cropWidth;
  int cropHeight;

  CroppedVideoData({
    this.cropX = 0,
    this.cropY = 0,
    this.cropWidth = 0,
    this.cropHeight = 0,
  });

  bool get hasCropRect => cropWidth > 0 && cropHeight > 0;
}
