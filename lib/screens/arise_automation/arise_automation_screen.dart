import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../../widgets/advanced_color_picker.dart';

import 'arise_automation_config.dart';
import '../video_creator/widgets/audio_selector_widget.dart';
import '../../services/analytics_service.dart';

class AriseAutomationScreen extends StatefulWidget {
  final List<String>? sharedPaths; // Generic naming
  final String? sharedPurpose;

  const AriseAutomationScreen({
    super.key,
    this.sharedPaths,
    this.sharedPurpose,
  });

  @override
  State<AriseAutomationScreen> createState() => _AriseAutomationScreenState();
}

class _AriseAutomationScreenState extends State<AriseAutomationScreen> {
  static const MethodChannel _platform = MethodChannel('com.quickpost.app/processor');

  List<File> _selectedMedia = []; // renamed from _selectedImages to be generic
  final AriseAutomationConfig _config = AriseAutomationConfig.defaultConfig();
  int _selectedTabIndex = 0;
  bool _isProcessing = false;
  double _processingProgress = 0;
  bool _isBatchProcessing = false;
  int _batchTotalItems = 0;
  int _batchCurrentIndex = 0;
  double _nativeItemProgress = 0;
  double _fakeItemProgress = 0;
  DateTime? _currentItemStartTime;
  Duration _currentItemEstimatedDuration = Duration.zero;
  DateTime? _processingStartTime;
  Duration _elapsedTime = Duration.zero;
  Duration _estimatedRemainingTime = Duration.zero;
  List<String> _outputPaths = [];
  Timer? _progressTimer;
  Timer? _fakeProgressTimer;

  File? _selectedAudio;
  String? _audioDuration;
  bool _isPlayingAudio = false;

  double _fadeInDurationSeconds = 1.0;
  String _qualityPreset = 'fast';
  int _qualityCrf = 23;
  String _qualityTune = 'none';

  @override
  void initState() {
    super.initState();
    _handleIncomingSharedMedia();
    _setupProgressListened();
    AnalyticsService().setCurrentScreen(screenName: 'Arise Automation');
  }

  bool _isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || 
           lower.endsWith('.mov') || 
           lower.endsWith('.mkv') || 
           lower.endsWith('.avi');
  }

  void _handleIncomingSharedMedia() {
    if (widget.sharedPurpose == 'automation' &&
        widget.sharedPaths != null &&
        widget.sharedPaths!.isNotEmpty) {
      setState(() {
        _selectedMedia = widget.sharedPaths!.map((path) => File(path)).toList();
      });
    }
  }

  void _cancelFakeProgressTimer() {
    _fakeProgressTimer?.cancel();
    _fakeProgressTimer = null;
  }

  void _cancelAllProgressTimers() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _cancelFakeProgressTimer();
  }

  int _estimateVideoProcessingMs({required bool blurEnabled, required int videoDurationSeconds}) {
    // Empirical timings provided by you:
    // - With blur: ~36s processing for 15s video => 2.4x
    // - Without blur: ~11s processing for 15s video => 0.733x
    final ratio = blurEnabled ? 2.4 : 11.0 / 15.0;
    final estimatedMs = (videoDurationSeconds * ratio * 1000).round();
    return estimatedMs.clamp(1500, 10 * 60 * 1000);
  }

  int _estimateImageProcessingMs({required bool blurEnabled}) {
    // Fast, but still show motion.
    return blurEnabled ? 1200 : 600;
  }

  void _setOverallProgressFromItemProgress({required int itemIndex, required int totalItems, required double itemProgress}) {
    final safeTotal = totalItems <= 0 ? 1 : totalItems;
    final clampedItemProgress = itemProgress.clamp(0.0, 1.0);
    final overall = ((itemIndex + clampedItemProgress) / safeTotal).clamp(0.0, 1.0);

    if (mounted) {
      setState(() {
        _processingProgress = overall;
      });
    }
  }

  void _startFakeProgressForCurrentItem({required int estimatedMs}) {
    _cancelFakeProgressTimer();
    _currentItemStartTime = DateTime.now();
    _currentItemEstimatedDuration = Duration(milliseconds: estimatedMs);
    _fakeItemProgress = 0;
    
    _fakeProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || !_isProcessing || !_isBatchProcessing || _currentItemStartTime == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_currentItemStartTime!);
      final denomMs = _currentItemEstimatedDuration.inMilliseconds <= 0 ? 1 : _currentItemEstimatedDuration.inMilliseconds;
      final t = (elapsed.inMilliseconds / denomMs).clamp(0.0, 1.0);

      // Fake progress should never reach 100% on its own.
      final fakeTarget = (t * 0.95).clamp(0.0, 0.95);
      final mergedItemProgress = (fakeTarget > _nativeItemProgress ? fakeTarget : _nativeItemProgress);
      _fakeItemProgress = fakeTarget;

      _setOverallProgressFromItemProgress(
        itemIndex: _batchCurrentIndex,
        totalItems: _batchTotalItems,
        itemProgress: mergedItemProgress,
      );
    });
  }

  String _currentStep = "";
  final Map<String, int> _stepTimings = {};
  DateTime? _stepStartTime;

  void _recordStepTiming(String step) {
    if (_stepStartTime != null && _currentStep.isNotEmpty) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _stepTimings[_currentStep] = (_stepTimings[_currentStep] ?? 0) + duration.inMilliseconds;
    }
    _currentStep = step;
    _stepStartTime = DateTime.now();
  }

  void _setupProgressListened() {
    _platform.setMethodCallHandler((call) async {
      debugPrint('Automation: MethodChannel call received: ${call.method}');
      if (call.method == 'onProgress') {
        final progress = (call.arguments as num).toDouble();
        debugPrint('Automation: Progress received: $progress');
        if (mounted) {
          setState(() {
            if (_isBatchProcessing) {
              _nativeItemProgress = progress.clamp(0.0, 1.0);
              final mergedItemProgress = (_nativeItemProgress > _fakeItemProgress ? _nativeItemProgress : _fakeItemProgress);
              _processingProgress = ((_batchCurrentIndex + mergedItemProgress) / (_batchTotalItems <= 0 ? 1 : _batchTotalItems)).clamp(0.0, 1.0);
            } else {
              _processingProgress = progress;
            }
            if (_processingStartTime != null) {
              _elapsedTime = DateTime.now().difference(_processingStartTime!);
              if (progress > 0) {
                final totalEstimatedMs = _elapsedTime.inMilliseconds / progress;
                _estimatedRemainingTime = Duration(
                  milliseconds: (totalEstimatedMs * (1 - progress)).round(),
                );
              }
            }
          });
        }
      } else if (call.method == 'onStep') {
        final step = call.arguments as String;
        if (mounted) {
          setState(() {
            _recordStepTiming(step);
          });
        }
      } else if (call.method == 'onComplete') {
        _recordStepTiming(""); // Finalize last step
        debugPrint('Automation: Process complete');
      } else if (call.method == 'onError') {
        _recordStepTiming(""); // Finalize last step
        debugPrint('Automation: Process error: ${call.arguments}');
      }
    });
  }

  @override
  void didUpdateWidget(covariant AriseAutomationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedPaths != oldWidget.sharedPaths) {
      _handleIncomingSharedMedia();
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    // Use pickMedia if available or build both
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick Images'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await picker.pickMultiImage();
                if (images.isNotEmpty) {
                  setState(() {
                    _selectedMedia.addAll(images.map((image) => File(image.path)));
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Pick Video'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
                if (video != null) {
                  setState(() {
                    _selectedMedia.add(File(video.path));
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelAllProgressTimers();
    super.dispose();
  }

  Future<void> _createVideoFromAutomation(String templateId) async {
    if (_isProcessing) return;

    if (_selectedMedia.isEmpty) {
      await _pickMedia();
    }
    if (_selectedMedia.isEmpty || !mounted) return;
    AnalyticsService().logSaveAction(feature: 'arise_automation', type: 'video_batch');
    AnalyticsService().logEvent(
      name: 'automation_started',
      parameters: {
        'item_count': _selectedMedia.length,
        'template': templateId,
      },
    );

    setState(() {
      _isProcessing = true;
      _isBatchProcessing = true;
      _batchTotalItems = _selectedMedia.length;
      _batchCurrentIndex = 0;
      _nativeItemProgress = 0;
      _fakeItemProgress = 0;
      _processingProgress = 0;
      _processingStartTime = DateTime.now();
      _elapsedTime = Duration.zero;
      _estimatedRemainingTime = Duration.zero;
      _outputPaths = [];
    });

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isProcessing) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_processingStartTime!);
        });
      } else {
        timer.cancel();
      }
    });

    final Map<String, dynamic> automationSettings = _config.toMap();

    // Duration logic: if audio is selected, use its duration, else default to 8s
    int finalDuration = 8;
    if (_selectedAudio != null && _audioDuration != null) {
      try {
        final parts = _audioDuration!.split(':');
        if (parts.length == 2) {
          finalDuration = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        } else {
          finalDuration = int.parse(parts[0]);
        }
      } catch (e) {
        finalDuration = 8;
      }
    }

    try {
      final List<String> results = [];
      for (int i = 0; i < _selectedMedia.length; i++) {
        _batchCurrentIndex = i;
        _nativeItemProgress = 0;
        _fakeItemProgress = 0;
        final media = _selectedMedia[i];
        final isVideo = _isVideoFile(media.path);
        
        final params = <String, dynamic>{
          'imagePath': media.path, // Still using imagePath for consistency in MethodChannel
          'isVideo': isVideo,
          'duration': (_selectedAudio == null && isVideo) ? 0 : finalDuration,
          'template': templateId,
          'fadeInDuration': templateId == 'fade_in' ? _fadeInDurationSeconds : 0.0,
          'zoomScale': 1.2,
          'zoomDuration': 2.0,
          'audioPath': _selectedAudio?.path,
          'automationSettings': automationSettings,
          'qualitySettings': <String, dynamic>{
            'preset': _qualityPreset,
            'crf': _qualityCrf,
            'tune': _qualityTune,
          },
          'imageScale': _config.imageScale,
        };

        final blurEnabled = _config.useBackgroundImage;
        _startFakeProgressForCurrentItem(
          estimatedMs: isVideo 
              ? (finalDuration * 1000 * 3) // Estimate 3x real-time for video automation
              : _estimateVideoProcessingMs(
                  blurEnabled: blurEnabled,
                  videoDurationSeconds: finalDuration,
                ),
        );

        final result = await _platform.invokeMethod('createVideo', params);
        _cancelFakeProgressTimer();
        if (result != null) results.add(result as String);

        _setOverallProgressFromItemProgress(
          itemIndex: i + 1,
          totalItems: _selectedMedia.length,
          itemProgress: 0,
        );
      }

      _cancelAllProgressTimers();
      _recordStepTiming(""); // Stop last step timing
      setState(() {
        _outputPaths = results;
        _isProcessing = false;
        _isBatchProcessing = false;
        _processingProgress = 1.0;
      });

      if (!mounted) return;

      if (_outputPaths.isEmpty) {
        _showErrorDialog('No videos were created');
        return;
      }

      _showSuccessDialog();
    } on PlatformException catch (e) {
      setState(() {
        _isProcessing = false;
        _isBatchProcessing = false;
      });
      _cancelAllProgressTimers();
      if (!mounted) return;
      _showErrorDialog('Failed to create video: ${e.message}');
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isBatchProcessing = false;
      });
      _cancelAllProgressTimers();
      if (!mounted) return;
      _showErrorDialog('Failed to create video: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            const Text('Processing Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Created ${_outputPaths.length} videos successfully.'),
            const SizedBox(height: 16),
            const Text('Performance Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            ..._stepTimings.entries.map((entry) {
              final seconds = entry.value / 1000.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${seconds.toStringAsFixed(2)}s', style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              );
            }).toList(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Time', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_elapsedTime.inSeconds}.${(_elapsedTime.inMilliseconds % 1000).toString().padLeft(3, '0')}s', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          if (_outputPaths.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(_outputPaths.last);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('OPEN LAST'),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    Color selectedColor = currentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                initialColor: currentColor,
                onColorChanged: (color) => selectedColor = color,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    onColorChanged(selectedColor);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSection(),
                const SizedBox(height: 12),
                _buildConfigSection(),
                const SizedBox(height: 12),
                _buildActionSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Input Media',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (_selectedMedia.isNotEmpty)
                  Text(
                    '${_selectedMedia.length} selected',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedMedia.isEmpty)
              OutlinedButton.icon(
                onPressed: _pickMedia,
                icon: const Icon(Icons.perm_media_outlined),
                label: const Text('Pick Media'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedMedia.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _selectedMedia[index];
                        final isVideo = _isVideoFile(file.path);
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: isVideo 
                                ? Container(
                                    height: 200,
                                    width: 112,
                                    color: Colors.black12,
                                    child: const Center(
                                      child: Icon(Icons.videocam, color: Colors.black54),
                                    ),
                                  )
                                : Image.file(
                                    file,
                                    height: 200,
                                    width: 112,
                                    fit: BoxFit.cover,
                                  ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMedia.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickMedia,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Media'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pipeline Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildControlTabs(),
            const SizedBox(height: 12),
            _buildSelectedTabControls(),
            const Divider(height: 32),
            _buildAudioSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Audio Selection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        AudioSelectorWidget(
          selectedAudio: _selectedAudio,
          audioDuration: _audioDuration,
          isPlayingAudio: _isPlayingAudio,
          onAudioSelected: (audio, duration) {
            setState(() {
              _selectedAudio = audio;
              _audioDuration = duration;
            });
          },
          onAudioRemoved: () {
            setState(() {
              _selectedAudio = null;
              _audioDuration = null;
              _isPlayingAudio = false;
            });
          },
          onPlaybackToggle: (isPlaying) {
            setState(() => _isPlayingAudio = isPlaying);
          },
          isProcessing: _isProcessing,
        ),
      ],
    );
  }

  Widget _buildControlTabs() {
    final tabs = [
      {'icon': Icons.blur_on, 'label': 'Background', 'color': Colors.blue},
      {'icon': Icons.rounded_corner, 'label': 'Frame', 'color': Colors.teal},
      {'icon': Icons.border_all, 'label': 'Border', 'color': Colors.deepOrange},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          final tab = tabs[index];
          final Color baseColor = tab['color'] as Color;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? baseColor.withOpacity(0.12) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? baseColor : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    size: 16,
                    color: isSelected ? baseColor : Colors.grey[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? baseColor : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedTabControls() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildBackgroundControls();
      case 1:
        return _buildFrameControls();
      case 2:
        return _buildBorderControls();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBackgroundControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Use Background Blur'),
          subtitle: const Text('Pad with blurred version of image'),
          value: _config.useBackgroundImage,
          onChanged: (val) => setState(() => _config.useBackgroundImage = val),
        ),
        if (_config.useBackgroundImage) ...[
          _buildSliderSetting(
            label: 'Blur Radius',
            value: _config.backgroundBlurRadius,
            min: 0,
            max: 50,
            onChanged: (val) => setState(() => _config.backgroundBlurRadius = val),
          ),
        ] else
          ListTile(
            title: const Text('Background Color'),
            subtitle: const Text('Pad with solid color'),
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _config.paddingColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
            onTap: () => _showColorPicker(
              'Background Color',
              _config.paddingColor,
              (color) => setState(() => _config.paddingColor = color),
            ),
          ),
        const Divider(),
        _buildSliderSetting(
          label: 'Background Brightness',
          value: _config.backgroundBrightness,
          min: 0,
          max: 2,
          onChanged: (val) => setState(() => _config.backgroundBrightness = val),
        ),
        _buildSliderSetting(
          label: 'Background Saturation',
          value: _config.backgroundSaturation,
          min: 0,
          max: 2,
          onChanged: (val) => setState(() => _config.backgroundSaturation = val),
        ),
      ],
    );
  }

  Widget _buildFrameControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Rounded Corners'),
          value: _config.roundedCorners,
          onChanged: (val) => setState(() => _config.roundedCorners = val),
        ),
        if (_config.roundedCorners)
          _buildSliderSetting(
            label: 'Corner Radius',
            value: _config.cornerRadius,
            min: 0,
            max: 100,
            onChanged: (val) => setState(() => _config.cornerRadius = val),
          ),
        const Divider(),
        _buildSliderSetting(
          label: 'Image Scale',
          value: _config.imageScale,
          min: 0.1,
          max: 1.2,
          onChanged: (val) => setState(() => _config.imageScale = val),
        ),
      ],
    );
  }

  Widget _buildBorderControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Border Stroke'),
          value: _config.strokeEnabled,
          onChanged: (val) => setState(() => _config.strokeEnabled = val),
        ),
        if (_config.strokeEnabled) ...[
          _buildSliderSetting(
            label: 'Stroke Width',
            value: _config.strokeWidth,
            min: 0,
            max: 20,
            onChanged: (val) => setState(() => _config.strokeWidth = val),
          ),
          ListTile(
            title: const Text('Stroke Color'),
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _config.strokeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
            onTap: () => _showColorPicker(
              'Stroke Color',
              _config.strokeColor,
              (color) => setState(() => _config.strokeColor = color),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSliderSetting(
          label: 'Duration (seconds)',
          value: _config.videoDuration.toDouble(),
          min: 1,
          max: 30,
          divisions: 29,
          onChanged: (val) => setState(() => _config.videoDuration = val.round()),
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value.toStringAsFixed(1)),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _saveImageFromAutomation() async {
    if (_isProcessing) return;

    if (_selectedMedia.isEmpty) {
      await _pickMedia();
    }
    if (_selectedMedia.isEmpty || !mounted) return;

    setState(() {
      _isProcessing = true;
      _isBatchProcessing = true;
      _batchTotalItems = _selectedMedia.length;
      _batchCurrentIndex = 0;
      _nativeItemProgress = 0;
      _fakeItemProgress = 0;
      _processingProgress = 0;
      _processingStartTime = DateTime.now();
      _elapsedTime = Duration.zero;
      _estimatedRemainingTime = Duration.zero;
      _outputPaths = [];
    });

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isProcessing) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_processingStartTime!);
        });
      } else {
        timer.cancel();
      }
    });

    try {
      final Map<String, dynamic> automationSettings = _config.toMap();
      final List<String> results = [];
      
      for (int i = 0; i < _selectedMedia.length; i++) {
        _batchCurrentIndex = i;
        _nativeItemProgress = 0;
        _fakeItemProgress = 0;
        final image = _selectedMedia[i];
        final isVideo = _isVideoFile(image.path);
        
        if (isVideo) {
          // Skip image save for video files, or we could extract a frame?
          // For now, let's just skip or show a skip message
          continue;
        }
        
        _startFakeProgressForCurrentItem(
          estimatedMs: _estimateImageProcessingMs(
            blurEnabled: _config.useBackgroundImage,
          ),
        );

        final result = await _platform.invokeMethod('saveProcessedImage', {
          'imagePath': image.path,
          'automationSettings': automationSettings,
        });
        
        _cancelFakeProgressTimer();
        if (result != null) results.add(result as String);

        _setOverallProgressFromItemProgress(
          itemIndex: i + 1,
          totalItems: _selectedMedia.length,
          itemProgress: 0,
        );
      }

      _cancelAllProgressTimers();
      setState(() {
        _outputPaths = results;
        _isProcessing = false;
        _isBatchProcessing = false;
        _processingProgress = 1.0;
      });

      if (!mounted) return;

      if (_outputPaths.isEmpty) {
        _showErrorDialog('No images were saved');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${_outputPaths.length} images to gallery'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN LAST',
            onPressed: () {
              OpenFile.open(_outputPaths.last);
            },
          ),
        ),
      );
    } on PlatformException catch (e) {
      _cancelAllProgressTimers();
      setState(() {
        _isProcessing = false;
        _isBatchProcessing = false;
      });
      if (!mounted) return;
      _showErrorDialog('Failed to save images: ${e.message}');
    } catch (e) {
      _cancelAllProgressTimers();
      setState(() {
        _isProcessing = false;
        _isBatchProcessing = false;
      });
      if (!mounted) return;
      _showErrorDialog('Failed to save images: $e');
    }
  }

  Widget _buildActionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Video Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Fade-in Settings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildSliderSetting(
              label: 'Fade-in Duration (s)',
              value: _fadeInDurationSeconds,
              min: 0.0,
              max: 3.0,
              divisions: 30,
              onChanged: _isProcessing
                  ? (_) {}
                  : (v) {
                      setState(() {
                        _fadeInDurationSeconds = v;
                      });
                    },
            ),
            SwitchListTile(
              title: const Text('Fade Whole Video'),
              subtitle: const Text('Fade background alongside foreground'),
              value: _config.fadeWholeVideo,
              onChanged: _isProcessing
                  ? null
                  : (v) => setState(() => _config.fadeWholeVideo = v),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quality',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Preset')),
                DropdownButton<String>(
                  value: _qualityPreset,
                  onChanged: _isProcessing
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _qualityPreset = v;
                          });
                        },
                  items: const [
                    DropdownMenuItem(value: 'ultrafast', child: Text('ultrafast')),
                    DropdownMenuItem(value: 'fast', child: Text('fast')),
                    DropdownMenuItem(value: 'medium', child: Text('medium')),
                    DropdownMenuItem(value: 'slow', child: Text('slow')),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Tune')),
                DropdownButton<String>(
                  value: _qualityTune,
                  onChanged: _isProcessing
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _qualityTune = v;
                          });
                        },
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('none')),
                    DropdownMenuItem(value: 'film', child: Text('film')),
                    DropdownMenuItem(value: 'animation', child: Text('animation')),
                    DropdownMenuItem(value: 'grain', child: Text('grain')),
                  ],
                ),
              ],
            ),
            _buildSliderSetting(
              label: 'CRF (lower = better)',
              value: _qualityCrf.toDouble(),
              min: 18.0,
              max: 30.0,
              divisions: 12,
              onChanged: _isProcessing
                  ? (_) {}
                  : (v) {
                      setState(() {
                        _qualityCrf = v.round().clamp(18, 30);
                      });
                    },
            ),
            const SizedBox(height: 12),
            if (_isProcessing) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 24,
                        width: constraints.maxWidth * (_processingProgress.clamp(0.0, 1.0)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple[400]!, Colors.purple[700]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            '${(_processingProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Elapsed: ${_formatDuration(_elapsedTime)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (_processingProgress > 0.05 && _processingProgress < 0.99)
                    Text(
                      'Rem: ${_formatDuration(_estimatedRemainingTime)}',
                      style: TextStyle(color: Colors.purple[700], fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              if (_isBatchProcessing) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Video ${_batchCurrentIndex + 1} of $_batchTotalItems',
                    style: TextStyle(
                      color: Colors.purple[800],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (_currentStep.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _currentStep,
                        style: TextStyle(
                          color: Colors.purple[800],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _createVideoFromAutomation('fade_in'),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Fade-in Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _createVideoFromAutomation('plain'),
              icon: const Icon(Icons.movie_creation_outlined),
              label: const Text('Simple Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _saveImageFromAutomation,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Save Processed Image'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blueGrey[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
