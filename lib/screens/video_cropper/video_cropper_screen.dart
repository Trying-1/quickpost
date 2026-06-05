import '../../config/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';

import '../home/home_shell_screen.dart';
import '../../services/app_review_service.dart';
import '../../services/video_perf_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/video_crop_editor.dart';
import '../../widgets/advanced_color_picker.dart';
import '../../services/ad_service.dart';

class VideoCropperScreen extends StatefulWidget {
  final List<String>? sharedVideoPaths;
  final bool isActive;

  const VideoCropperScreen({super.key, this.sharedVideoPaths, this.isActive = true});

  @override
  State<VideoCropperScreen> createState() => _VideoCropperScreenState();
}

class _VideoCropperScreenState extends State<VideoCropperScreen> {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');

  final List<File> _selectedVideos = [];
  final List<CroppedVideoData> _croppedVideos = [];
  final GlobalKey<VideoCropEditorState> _editorKey = GlobalKey<VideoCropEditorState>();

  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _isMuted = false;
  String _selectedAspectRatio = 'free';

  // Performance & Progress
  double _progress = 0.0;
  double _fakeProgress = 0.0;
  double _avgRatio = 0.8;
  String _elapsedTime = "00:00";
  String _remainingTime = "--:--";
  Stopwatch _processStopwatch = Stopwatch();
  Timer? _uiUpdateTimer;
  int _totalInputDurationMs = 0;
  int _totalInputSize = 0;
  int _totalOutputSize = 0;
  String _inputFileName = "";

  // UI State for tabs
  int _selectedTabIndex = 0; // 0: Aspect Ratio, 1: Manager
  bool _isTabContentExpanded = true;
  Color _fillColor = const Color(0xFF1A1A1A);
  String? _bgImagePath;
  double _bgBlur = 10.0;
  double _bgImageBlur = 0.0;
  double _bgBrightness = 1.0;
  double _bgSaturation = 1.0;
  double _bgOpacity = 0.0;

  String _colorToHex(Color color) {
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _avgRatio = VideoPerfService.getAvgRatio();
    _setupMethodCallHandler();
    _loadInitialVideos();
    AnalyticsService().setCurrentScreen(screenName: 'Video Cropper');
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onProgress") {
        setState(() {
          _progress = (call.arguments as num).toDouble();
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String threeDigits(int n) => n.toString().padLeft(3, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return ((bytes / math.pow(1024, i)).toStringAsFixed(1)) + ' ' + suffixes[i];
  }

  Future<Map<String, int>> _fetchBatchMetadata(List<File> videos) async {
    int totalDur = 0;
    int totalSize = 0;
    for (var f in videos) {
      try {
        final meta = await _channel.invokeMethod<Map>('getVideoMetadata', {'videoPath': f.path});
        if (meta != null) {
          totalDur += meta['durationMs'] as int? ?? 0;
          totalSize += meta['fileSizeBytes'] as int? ?? 0;
        }
      } catch (e) {
        debugPrint('Metadata fetch failed for ${f.path}: $e');
      }
    }
    return {'durationMs': totalDur, 'size': totalSize};
  }

  void _startProgressTimer() {
    _processStopwatch.reset();
    _processStopwatch.start();
    _progress = 0.0;
    _fakeProgress = 0.0;
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isProcessing) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          final elapsed = _processStopwatch.elapsed;
          _elapsedTime = _formatDuration(elapsed);
          
          // Calculate fake progress based on estimation
          if (_totalInputDurationMs > 0) {
            final estimatedTotalMs = _totalInputDurationMs * _avgRatio;
            _fakeProgress = (elapsed.inMilliseconds / estimatedTotalMs).clamp(0.0, 0.99);
          }

          if (_progress > 0.01) {
            final totalEstimatedMs = elapsed.inMilliseconds / _progress;
            final remainingInMs = (totalEstimatedMs - elapsed.inMilliseconds).toInt();
            _remainingTime = _formatDuration(Duration(milliseconds: math.max(0, remainingInMs)));
          } else if (_totalInputDurationMs > 0) {
            // Fallback to learned avgRatio
            final estimatedTotalMs = _totalInputDurationMs * _avgRatio;
            final remainingInMs = (estimatedTotalMs - elapsed.inMilliseconds).toInt();
            _remainingTime = _formatDuration(Duration(milliseconds: math.max(0, remainingInMs)));
          } else {
            _remainingTime = "--:--";
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant VideoCropperScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedVideoPaths != oldWidget.sharedVideoPaths) {
      _loadInitialVideos();
    }
    if (!widget.isActive && oldWidget.isActive) {
      _editorKey.currentState?.pauseVideo();
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

  void _applyAspectRatio(String ratio) {
    setState(() {
      _selectedAspectRatio = ratio;
    });
  }

  Future<void> _processAll({bool fillEnabled = false}) async {
    if (_selectedVideos.isEmpty) return;
    AnalyticsService().logSaveAction(feature: 'video_cropper', type: 'video_batch');
    
    setState(() {
      _isProcessing = true;
      _remainingTime = "--:--";
      _elapsedTime = "00:00";
      _inputFileName = _selectedVideos.isNotEmpty ? _selectedVideos.first.path.split('/').last : "";
    });

    try {
      final meta = await _fetchBatchMetadata(_selectedVideos);
      _totalInputDurationMs = meta['durationMs'] ?? 0;
      _totalInputSize = meta['size'] ?? 0;
      _startProgressTimer();

      final List<Map<String, dynamic>> items = [];
      for (int i = 0; i < _selectedVideos.length; i++) {
        final video = _selectedVideos[i];
        final crop = _croppedVideos[i];
        
        if (!crop.hasCropRect) {
          continue;
        }

        final outputPath = await _channel.invokeMethod<String>('getVideoOutputPath', {
          'filename': 'QuickPost_Cropped_${DateTime.now().millisecondsSinceEpoch}_$i.mp4',
          'isTemporary': true,
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
          'rotation': crop.rotation,
          'isFlipped': crop.isFlipped,
          'fillEnabled': fillEnabled,
          'bgColor': _colorToHex(_fillColor),
          'bgImagePath': _bgImagePath,
          'bgBlur': _bgBlur,
          'bgImageBlur': _bgImageBlur,
          'bgBrightness': _bgBrightness,
          'bgSaturation': _bgSaturation,
          'bgOpacity': _bgOpacity,
        });
      }

      if (items.isEmpty) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please crop the videos first')),
        );
        return;
      }

      final startTime = DateTime.now();
      final List<dynamic>? results = await _channel.invokeMethod('cropVideosBatch', {
        'items': items,
      });
      final endTime = DateTime.now();
      final processingDuration = endTime.difference(startTime).inMilliseconds / 1000.0;

      // Learn and save performance ratio
      if (_totalInputDurationMs > 0) {
        final actualRatio = (endTime.difference(startTime).inMilliseconds) / _totalInputDurationMs;
        await VideoPerfService.updateRatio(actualRatio);
      }

      debugPrint('[VideoCropper] Crop results: $results');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        if (results != null && results.isNotEmpty) {
          final List<String> outputPaths = results.cast<String>();
          
          // Calculate total output size
          int totalOut = 0;
          for (var path in outputPaths) {
            try {
              final outMeta = await _channel.invokeMethod<Map>('getVideoMetadata', {'videoPath': path});
              if (outMeta != null) {
                totalOut += outMeta['fileSizeBytes'] as int? ?? 0;
              }
            } catch (_) {}
          }
          
          setState(() {
            _totalOutputSize = totalOut;
          });

          debugPrint('[VideoCropper] Final output paths: $outputPaths');
          _showCompletionDialog(outputPaths, processingDuration);
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

  void _showCompletionDialog(List<String> outputPaths, double durationInSeconds) {
    AdService().showInterstitialAd();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Processing Complete!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Processed ${outputPaths.length} videoclip${outputPaths.length == 1 ? '' : 's'} in ${durationInSeconds.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Input Size', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(_formatSize(_totalInputSize), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Output Size', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(_formatSize(_totalOutputSize), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // New Action: Save to Device
              StatefulBuilder(
                builder: (context, setDialogState) {
                  bool isSaved = false;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSaved ? null : () async {
                        try {
                          final List<String> newPaths = [];
                          for (var path in outputPaths) {
                            final result = await _channel.invokeMethod<String>('saveVideoToGallery', {'videoPath': path});
                            if (result != null) newPaths.add(result);
                          }
                          
                          // Update outputPaths so subsequent actions use the gallery paths
                          outputPaths.clear();
                          outputPaths.addAll(newPaths);
                          
                          setDialogState(() => isSaved = true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Videos saved to Gallery!')),
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
                      label: Text(isSaved ? 'Saved to Gallery' : 'Save to Gallery', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSaved ? Colors.grey[400] : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Primary Action: Designer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final String path = outputPaths.first;
                    Navigator.pop(context);
                    HomeShellScreen.navigateToTab(4, paths: [path], purpose: 'video_text');
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                  label: const Text('Send to Designer', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Action: Watermark
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final String path = outputPaths.first;
                    Navigator.pop(context);
                    HomeShellScreen.navigateToTab(2, paths: [path], purpose: 'watermark');
                  },
                  icon: const Icon(Icons.branding_watermark_rounded, size: 20),
                  label: const Text('Send to Watermark', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                   Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        OpenFile.open(outputPaths.first);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Preview', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildPreviewArea(hasVideos, currentVideo, currentCrop)),
                if (hasVideos) ...[
                  if (_isTabContentExpanded) _buildActiveTabContent(),
                  _buildControlTabs(),
                ],
              ],
            ),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(bool hasVideos, File? currentVideo, CroppedVideoData? currentCrop) {
    if (!hasVideos || currentVideo == null || currentCrop == null) {
      return Center(
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
      );
    }
    return KeyedSubtree(
      key: ValueKey(currentVideo.path),
      child: VideoCropEditor(
        key: _editorKey,
        videoFile: currentVideo,
        initialCrop: currentCrop,
        onCropChanged: _onCropUpdated,
        isMuted: _isMuted,
        onMuteToggle: () => setState(() => _isMuted = !_isMuted),
        forcedAspectRatio: _selectedAspectRatio,
      ),
    );
  }

  Widget _buildControlTabs() {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _processAll(fillEnabled: false),
              child: const Text('SAVE ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTabItem(0, Icons.aspect_ratio, 'Ratio', AppColors.primary),
                  _buildTabItem(1, Icons.video_collection, 'Manager', AppColors.primary),
                  _buildTabItem(2, Icons.rotate_right, 'Rotate', Colors.teal),
                  _buildTabItem(5, Icons.flip, 'Flip', Colors.orange),
                  _buildTabItem(6, Icons.format_color_fill, 'Fill', Colors.purple),
                  _buildTabItem(3, Icons.fullscreen_rounded, 'Fit', Colors.indigo),
                  _buildTabItem(4, Icons.center_focus_weak, 'Reset', Colors.deepOrange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        if (index >= 2 && index != 6) {
          // Immediate actions
          if (_editorKey.currentState != null) {
            if (index == 2) _editorKey.currentState!.rotateVideo();
            if (index == 5) _editorKey.currentState!.flipHorizontal();
            if (index == 3) _editorKey.currentState!.fitToFrame();
            if (index == 4) _editorKey.currentState!.resetPosition();
          }
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
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: _buildTabSpecificContent(),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildRatioContent();
      case 1: return _buildManagerContent();
      case 6: return _buildFillContent();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildRatioContent() {
    final Map<String, Map<String, dynamic>> aspectRatios = {
      'free': {'name': 'Free', 'ratio': null, 'icon': Icons.crop_free},
      '1:1': {'name': '1:1', 'ratio': 1.0, 'icon': Icons.crop_square},
      '4:3': {'name': '4:3', 'ratio': 4 / 3, 'icon': Icons.crop_landscape},
      '3:4': {'name': '3:4', 'ratio': 3 / 4, 'icon': Icons.crop_portrait},
      '16:9': {'name': '16:9', 'ratio': 16 / 9, 'icon': Icons.crop_landscape},
      '9:16': {'name': '9:16', 'ratio': 9 / 16, 'icon': Icons.crop_portrait},
    };

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: aspectRatios.entries.map((e) {
              final key = e.key;
              final name = e.value['name'] as String;
              final selected = _selectedAspectRatio == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (_) => _applyAspectRatio(key),
                  selectedColor: Colors.blueAccent,
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                  backgroundColor: Colors.grey[100],
                ),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Selected ratio will be applied to the current video.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildManagerContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildVideoManagementBar(),
      ],
    );
  }

  Widget _buildVideoManagementBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Video ${_currentIndex + 1} of ${_selectedVideos.length}',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentIndex > 0 ? _previousVideo : null,
                icon: const Icon(Icons.chevron_left, color: Colors.black),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: _currentIndex < _selectedVideos.length - 1 ? _nextVideo : null,
                icon: const Icon(Icons.chevron_right, color: Colors.black),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _removeVideo,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Remove current video',
              ),
              IconButton(
                onPressed: _pickVideos,
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                tooltip: 'Add more',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: !_isProcessing ? _processAll : null,
          icon: const Icon(Icons.check_circle_outline, size: 22),
          label: const Text(
            'PROCESS ALL VIDEOS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_motion, color: Color(0xFF00796B), size: 28),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cropping Video Batch',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (_selectedVideos.isNotEmpty)
                Text(
                  'Processing ${_selectedVideos.length} clips...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              const SizedBox(height: 28),
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: constraints.maxWidth * _fakeProgress,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF80CBC4), Color(0xFF00796B)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_fakeProgress * 100).toInt()}% Estimated',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                  ),
                  const Text(
                    "Optimizing...",
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTimeInfo("Elapsed", _elapsedTime),
                    Container(width: 1, height: 30, color: Colors.grey[200]),
                    _buildTimeInfo("Est. Left", _remainingTime),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Please keep the app open',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87, fontFamily: 'monospace')),
      ],
    );
  }

  Future<void> _pickBgImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _bgImagePath = image.path);
    }
  }

  void _showColorPicker() {
    Color selectedColor = _fillColor;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Custom Colors',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdvancedColorPicker(
                      initialColor: selectedColor,
                      onColorChanged: (color) => selectedColor = color,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _fillColor = selectedColor);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply Color',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFillContent() {
    final List<Color> colors = [
      const Color(0xFF1A1A1A),
      Colors.black,
      Colors.white,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FILL BACKGROUND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _processAll(fillEnabled: true),
                icon: const Icon(Icons.auto_fix_high, size: 14),
                label: const Text('SAVE FILL (9:16)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GestureDetector(
                    onTap: _showColorPicker,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: const Icon(Icons.colorize, size: 18, color: Colors.black54),
                    ),
                  );
                }
                final color = colors[index - 1];
                final isSelected = _fillColor.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _fillColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickBgImage,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _bgImagePath != null ? AppColors.primary : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_bgImagePath != null ? Icons.image : Icons.image_outlined, 
                          size: 18, color: _bgImagePath != null ? AppColors.primary : Colors.black54),
                        const SizedBox(width: 8),
                        Text(_bgImagePath != null ? 'Image Selected' : 'Pick Bg Image', 
                          style: TextStyle(fontSize: 11, color: _bgImagePath != null ? AppColors.primary : Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),
              if (_bgImagePath != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _bgImagePath = null),
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_bgImagePath != null) ...[
            const Text('IMAGE & BACKDROP SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                   _buildSliderRow('Video Backdrop Opacity', _bgOpacity, 0, 1.0, (v) => setState(() => _bgOpacity = v)),
                   _buildSliderRow('Backdrop Blur Radius', _bgBlur, 0, 20.0, (v) => setState(() => _bgBlur = v)),
                   _buildSliderRow('Image Blur Radius', _bgImageBlur, 0, 20.0, (v) => setState(() => _bgImageBlur = v)),
                   _buildSliderRow('Image Brightness', _bgBrightness, 0.1, 2.0, (v) => setState(() => _bgBrightness = v)),
                   _buildSliderRow('Image Saturation', _bgSaturation, 0, 2.0, (v) => setState(() => _bgSaturation = v)),
                ],
              ),
            ),
          ] else
            const Text('Select a color above or pick a background image to enable advanced adjustments.', 
              style: TextStyle(fontSize: 9, color: Colors.grey, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          SizedBox(
            height: 30,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: AppColors.primary,
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
  int rotation; // 0, 90, 180, 270
  bool isFlipped;

  CroppedVideoData({
    this.cropX = 0,
    this.cropY = 0,
    this.cropWidth = 0,
    this.cropHeight = 0,
    this.rotation = 0,
    this.isFlipped = false,
  });

  bool get hasCropRect => cropWidth > 0 && cropHeight > 0;
}
