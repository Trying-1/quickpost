import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

import 'arise_automation_config.dart';
import '../video_creator/widgets/audio_selector_widget.dart';

class AriseAutomationScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const AriseAutomationScreen({
    super.key,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<AriseAutomationScreen> createState() => _AriseAutomationScreenState();
}

class _AriseAutomationScreenState extends State<AriseAutomationScreen> {
  static const MethodChannel _platform = MethodChannel('com.quickpost.app/processor');

  List<File> _selectedImages = [];
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
    _handleIncomingSharedImages();
    _setupProgressListened();
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
      } else if (call.method == 'onComplete') {
        debugPrint('Automation: Process complete');
      } else if (call.method == 'onError') {
        debugPrint('Automation: Process error: ${call.arguments}');
      }
    });
  }

  @override
  void didUpdateWidget(covariant AriseAutomationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedImagePaths != oldWidget.sharedImagePaths) {
      _handleIncomingSharedImages();
    }
  }

  void _handleIncomingSharedImages() {
    if (widget.sharedPurpose == 'automation' &&
        widget.sharedImagePaths != null &&
        widget.sharedImagePaths!.isNotEmpty) {
      setState(() {
        _selectedImages = widget.sharedImagePaths!.map((path) => File(path)).toList();
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() {
      _selectedImages = images.map((image) => File(image.path)).toList();
    });
  }

  @override
  void dispose() {
    _cancelAllProgressTimers();
    super.dispose();
  }

  Future<void> _createVideoFromAutomation(String templateId) async {
    if (_isProcessing) return;

    if (_selectedImages.isEmpty) {
      await _pickImages();
    }
    if (_selectedImages.isEmpty || !mounted) return;

    setState(() {
      _isProcessing = true;
      _isBatchProcessing = true;
      _batchTotalItems = _selectedImages.length;
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
      for (int i = 0; i < _selectedImages.length; i++) {
        _batchCurrentIndex = i;
        _nativeItemProgress = 0;
        _fakeItemProgress = 0;
        final image = _selectedImages[i];
        final params = <String, dynamic>{
          'imagePath': image.path,
          'duration': finalDuration,
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
        };

        final blurEnabled = _config.useBackgroundImage;
        _startFakeProgressForCurrentItem(
          estimatedMs: _estimateVideoProcessingMs(
            blurEnabled: blurEnabled,
            videoDurationSeconds: finalDuration,
          ),
        );

        final result = await _platform.invokeMethod('createVideo', params);
        _cancelFakeProgressTimer();
        if (result != null) results.add(result as String);

        _setOverallProgressFromItemProgress(
          itemIndex: i + 1,
          totalItems: _selectedImages.length,
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
        _showErrorDialog('No videos were created');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created ${_outputPaths.length} videos'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN LAST',
            onPressed: () {
              if (_outputPaths.isNotEmpty) {
                OpenFile.open(_outputPaths.last);
              }
            },
          ),
        ),
      );
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
    final colors = [
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $title'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: colors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final color = colors[index];
              return GestureDetector(
                onTap: () {
                  onColorChanged(color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == currentColor ? Colors.blue : Colors.grey[300]!,
                      width: color == currentColor ? 3 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
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
                  'Input Images',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (_selectedImages.isNotEmpty)
                  Text(
                    '${_selectedImages.length} selected',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedImages.isEmpty)
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pick Images'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImages[index],
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
                                    _selectedImages.removeAt(index);
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
                    onPressed: _pickImages,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Replace Images'),
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
            subtitle: const Text('Solid color padding'),
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

    if (_selectedImages.isEmpty) {
      await _pickImages();
    }
    if (_selectedImages.isEmpty || !mounted) return;

    setState(() {
      _isProcessing = true;
      _isBatchProcessing = true;
      _batchTotalItems = _selectedImages.length;
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
      
      for (int i = 0; i < _selectedImages.length; i++) {
        _batchCurrentIndex = i;
        _nativeItemProgress = 0;
        _fakeItemProgress = 0;
        final image = _selectedImages[i];
        final params = <String, dynamic>{
          'imagePath': image.path,
          'automationSettings': automationSettings,
        };

        final blurEnabled = _config.useBackgroundImage;
        _startFakeProgressForCurrentItem(
          estimatedMs: _estimateImageProcessingMs(blurEnabled: blurEnabled),
        );

        final result = await _platform.invokeMethod('saveProcessedImage', params);
        _cancelFakeProgressTimer();
        if (result != null) results.add(result as String);

        _setOverallProgressFromItemProgress(
          itemIndex: i + 1,
          totalItems: _selectedImages.length,
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
