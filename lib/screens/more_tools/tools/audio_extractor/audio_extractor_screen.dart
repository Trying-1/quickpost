import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/audio_export_format.dart';
import 'services/audio_extractor_service.dart';
import 'widgets/audio_extractor_dialog.dart';

class ExtractorVideoItem {
  final File file;
  String? thumbnailPath;
  int durationMs;
  int fileSizeBytes;
  int width;
  int height;
  String customFileName;
  bool isExtracted;
  ExtractedAudioResult? result;

  ExtractorVideoItem({
    required this.file,
    this.thumbnailPath,
    this.durationMs = 0,
    this.fileSizeBytes = 0,
    this.width = 0,
    this.height = 0,
    String? customFileName,
    this.isExtracted = false,
    this.result,
  }) : customFileName = customFileName ?? _deriveBaseName(file.path);

  static String _deriveBaseName(String path) {
    final raw = path.split('/').last;
    final dot = raw.lastIndexOf('.');
    return dot > 0 ? '${raw.substring(0, dot)}_audio' : '${raw}_audio';
  }

  String get formattedDuration {
    final totalSec = durationMs ~/ 1000;
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String get formattedSize {
    if (fileSizeBytes <= 0) return '0 MB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AudioExtractorScreen extends StatefulWidget {
  const AudioExtractorScreen({super.key});

  @override
  State<AudioExtractorScreen> createState() => _AudioExtractorScreenState();
}

class _AudioExtractorScreenState extends State<AudioExtractorScreen>
    with SingleTickerProviderStateMixin {
  final List<ExtractorVideoItem> _videoQueue = [];
  int _activeVideoIndex = 0;

  VideoPlayerController? _videoController;
  bool _showVideoPlayer = false; // False by default (Audio mode), user can opt to view video
  late AnimationController _waveAnimController;

  int _selectedTabIndex = 0; // 0: Format, 1: Bitrate, 2: Settings, 3: Details
  bool _isTabContentExpanded = true;

  AudioExportFormat _selectedFormat = AudioExportFormat.mp3;
  int _selectedBitrate = 192;
  final TextEditingController _fileNameController = TextEditingController();
  bool _autoAddToLibrary = true;

  bool _isExtracting = false;
  int _batchExtractingIndex = 0; // 1-based index during extraction

  ExtractorVideoItem? get _activeItem =>
      (_videoQueue.isNotEmpty && _activeVideoIndex < _videoQueue.length)
          ? _videoQueue[_activeVideoIndex]
          : null;

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Audio Extractor Tool');
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _videoController?.removeListener(_onControllerTick);
    _videoController?.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickVideos({bool append = false}) async {
    final files = await AudioExtractorService.pickMultipleVideos();
    if (files.isEmpty) return;

    if (!append) {
      if (_videoController != null) {
        _videoController!.removeListener(_onControllerTick);
        await _videoController!.dispose();
        _videoController = null;
      }
      _videoQueue.clear();
      _activeVideoIndex = 0;
    }

    final existingPaths = _videoQueue.map((e) => e.file.path).toSet();
    final newItems = <ExtractorVideoItem>[];

    for (final file in files) {
      if (!existingPaths.contains(file.path)) {
        final item = ExtractorVideoItem(file: file);
        newItems.add(item);
      }
    }

    if (newItems.isEmpty) return;

    setState(() {
      _videoQueue.addAll(newItems);
      _isTabContentExpanded = true;
    });

    // Asynchronously fetch thumbnails & metadata for all new items
    for (final item in newItems) {
      AudioExtractorService.getVideoMetadata(item.file.path).then((meta) {
        if (mounted && meta != null) {
          setState(() {
            item.durationMs = meta['durationMs'] as int? ?? 0;
            item.fileSizeBytes = meta['fileSizeBytes'] as int? ?? 0;
            item.width = meta['width'] as int? ?? 0;
            item.height = meta['height'] as int? ?? 0;
          });
        }
      });

      AudioExtractorService.generateVideoThumbnail(item.file.path).then((thumb) {
        if (mounted && thumb != null) {
          setState(() {
            item.thumbnailPath = thumb;
          });
        }
      });
    }

    // Play active video audio
    if (_activeItem != null) {
      _fileNameController.text = _activeItem!.customFileName;
      _playActiveAudio();
    }
  }

  Future<void> _playActiveAudio() async {
    final item = _activeItem;
    if (item == null) return;

    if (_videoController != null) {
      _videoController!.removeListener(_onControllerTick);
      await _videoController!.dispose();
      _videoController = null;
    }

    final controller = VideoPlayerController.file(item.file);
    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
      controller.addListener(_onControllerTick);
      if (mounted) {
        setState(() {
          _videoController = controller;
        });
      }
    } catch (_) {}
  }

  void _switchActiveVideo(int index) {
    if (index < 0 || index >= _videoQueue.length || index == _activeVideoIndex) return;

    // Save custom filename for current item
    if (_activeItem != null && _fileNameController.text.trim().isNotEmpty) {
      _activeItem!.customFileName = _fileNameController.text.trim();
    }

    setState(() {
      _activeVideoIndex = index;
      _fileNameController.text = _videoQueue[index].customFileName;
    });

    _playActiveAudio();
  }

  void _removeVideoFromQueue(int index) {
    if (index < 0 || index >= _videoQueue.length) return;

    setState(() {
      _videoQueue.removeAt(index);
      if (_videoQueue.isEmpty) {
        _videoController?.removeListener(_onControllerTick);
        _videoController?.dispose();
        _videoController = null;
        _activeVideoIndex = 0;
      } else if (_activeVideoIndex >= _videoQueue.length) {
        _activeVideoIndex = _videoQueue.length - 1;
        _fileNameController.text = _videoQueue[_activeVideoIndex].customFileName;
        _playActiveAudio();
      } else if (index == _activeVideoIndex) {
        _fileNameController.text = _videoQueue[_activeVideoIndex].customFileName;
        _playActiveAudio();
      }
    });
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  Future<void> _extractAudio() async {
    if (_videoQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one video')),
      );
      return;
    }

    // Save active filename
    if (_activeItem != null && _fileNameController.text.trim().isNotEmpty) {
      _activeItem!.customFileName = _fileNameController.text.trim();
    }

    // Pause preview playback
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }

    setState(() {
      _isExtracting = true;
      _batchExtractingIndex = 1;
    });

    final results = <ExtractedAudioResult>[];
    int successCount = 0;

    for (int i = 0; i < _videoQueue.length; i++) {
      if (!mounted) break;
      final item = _videoQueue[i];

      setState(() {
        _batchExtractingIndex = i + 1;
      });

      final result = await AudioExtractorService.extractAudio(
        videoPath: item.file.path,
        format: _selectedFormat,
        bitrate: _selectedBitrate,
        customFileName: item.customFileName.isNotEmpty ? item.customFileName : null,
        folderName: 'Quick Post Audios',
      );

      if (result.success && result.filePath.isNotEmpty) {
        successCount++;
        item.isExtracted = true;
        item.result = result;
        results.add(result);

        if (_autoAddToLibrary) {
          await AudioExtractorService.addToAudioLibrary(
            result: result,
            thumbnailPath: item.thumbnailPath,
            originalVideoPath: item.file.path,
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _isExtracting = false);

    if (results.isNotEmpty) {
      AnalyticsService().logSaveAction(
        feature: 'audio_extractor_batch',
        type: _selectedFormat.extensionName,
      );

      if (mounted) {
        if (results.length == 1) {
          AudioExtractorSuccessSheet.show(
            context,
            result: results.first,
            videoThumbnailPath: _activeItem?.thumbnailPath,
            originalVideoPath: _activeItem?.file.path,
          );
        } else {
          AudioExtractorSuccessSheet.showBatch(
            context,
            batchResults: results,
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to extract audio from videos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _videoQueue.length > 1
              ? 'Audio Extractor (${_videoQueue.length} Videos)'
              : 'Audio Extractor',
        ),
        actions: [
          if (_videoQueue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Add more videos',
              onPressed: _isExtracting ? null : () => _pickVideos(append: true),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Top Batch Queue Strip (when 1 or more videos are loaded) ───
          if (_videoQueue.isNotEmpty)
            _buildBatchQueueStrip(theme, isDark),

          // ─── 1. Active Video Area: Audio Waveform Player / Optional Video Canvas ───
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF121214) : const Color(0xFFF7F8FA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(
                child: _videoQueue.isEmpty
                    ? _buildPickerCard(theme, isDark)
                    : (_showVideoPlayer
                        ? _buildVideoView(theme, isDark)
                        : _buildAudioWaveformPlayer(theme, isDark)),
              ),
            ),
          ),

          // ─── 2. Collapsible Active Tab Drawer ───
          if (_videoQueue.isNotEmpty && _isTabContentExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 240,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _buildActiveTabContent(theme, isDark),
            ),

          // ─── 3. Horizontal Scrollable Control Tabs Dock ───
          if (_videoQueue.isNotEmpty)
            _buildControlTabs(theme, isDark),

          // ─── 4. Bottom Action Bar (Batch Extract CTA) ───
          _buildBottomActionBar(theme, isDark),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Batch Queue Strip: Displays all loaded videos with active selector
  // ─────────────────────────────────────────────────────────────
  Widget _buildBatchQueueStrip(ThemeData theme, bool isDark) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _videoQueue.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          // Last item: "+ Add More" button
          if (i == _videoQueue.length) {
            return InkWell(
              onTap: _isExtracting ? null : () => _pickVideos(append: true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(height: 2),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final item = _videoQueue[i];
          final isSelected = i == _activeVideoIndex;

          return InkWell(
            onTap: _isExtracting ? null : () => _switchActiveVideo(i),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 130,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isSelected
                    ? _selectedFormat.color.withOpacity(isDark ? 0.2 : 0.1)
                    : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _selectedFormat.color : Colors.transparent,
                  width: 1.8,
                ),
              ),
              child: Row(
                children: [
                  // Square Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: Colors.black26,
                      child: (item.thumbnailPath != null && File(item.thumbnailPath!).existsSync())
                          ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                          : const Icon(Icons.movie_outlined, size: 20, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Title & Duration
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.file.path.split('/').last,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? _selectedFormat.color : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.formattedDuration,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Remove button
                  if (!_isExtracting && _videoQueue.length > 1)
                    GestureDetector(
                      onTap: () => _removeVideoFromQueue(i),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
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

  // ─────────────────────────────────────────────────────────────
  // Empty State: Video Picker Card (Multi-select enabled)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPickerCard(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () => _pickVideos(append: false),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 290),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.35),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_rounded,
                size: 34,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Video(s) to Extract Audio',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick single or multiple videos for 1-tap batch extraction',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Pick Single or Multiple Videos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Audio Waveform Music Player Card (Default active video mode)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAudioWaveformPlayer(ThemeData theme, bool isDark) {
    final item = _activeItem;
    if (item == null) return const SizedBox.shrink();

    final isPlaying = _videoController?.value.isPlaying ?? false;
    final position = _videoController?.value.position ?? Duration.zero;
    final duration = _videoController?.value.duration ??
        Duration(milliseconds: item.durationMs > 0 ? item.durationMs : 1);

    final posStr = _formatDuration(position);
    final durStr = _formatDuration(duration);

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track Info Header & "View Video" optional toggle
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 58,
                  height: 58,
                  color: Colors.black26,
                  child: (item.thumbnailPath != null && File(item.thumbnailPath!).existsSync())
                      ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                      : Icon(Icons.music_note_rounded, color: _selectedFormat.color, size: 30),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.file.path.split('/').last,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _selectedFormat.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TARGET: ${_selectedFormat.label}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _selectedFormat.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPlaying ? '🎵 Playing Audio' : '⏸ Paused',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPlaying ? const Color(0xFF2E7D32) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // "View Video" optional toggle button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                icon: const Icon(Icons.videocam_outlined, size: 16),
                label: const Text('View Video', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _showVideoPlayer = true),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Animated Waveform Graphic
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildAnimatedWaveform(isPlaying, _selectedFormat.color),
          ),

          const SizedBox(height: 8),

          // Timeline Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: _selectedFormat.color,
              thumbColor: _selectedFormat.color,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            child: Slider(
              value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
              max: duration.inMilliseconds.toDouble() > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0,
              onChanged: (val) {
                if (_videoController != null) {
                  _videoController!.seekTo(Duration(milliseconds: val.toInt()));
                }
              },
            ),
          ),

          // Duration & Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(
                  '$posStr / $durStr',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Restart audio',
                  onPressed: () => _videoController?.seekTo(Duration.zero),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _togglePlayPause,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _selectedFormat.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Optional Video View
  // ─────────────────────────────────────────────────────────────
  Widget _buildVideoView(ThemeData theme, bool isDark) {
    final item = _activeItem;
    if (item == null) return const SizedBox.shrink();

    final isPlaying = _videoController?.value.isPlaying ?? false;

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (_videoController != null && _videoController!.value.isInitialized)
                    VideoPlayer(_videoController!)
                  else
                    Container(color: Colors.black87),

                  Center(
                    child: InkWell(
                      onTap: _togglePlayPause,
                      borderRadius: BorderRadius.circular(36),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white60, width: 1.5),
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => setState(() => _showVideoPlayer = false),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Audio Mode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.file.path.split('/').last,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.graphic_eq_rounded, size: 16),
                  label: const Text('Back to Audio Mode', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _showVideoPlayer = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Animated Waveform Bars
  // ─────────────────────────────────────────────────────────────
  Widget _buildAnimatedWaveform(bool isPlaying, Color color) {
    return AnimatedBuilder(
      animation: _waveAnimController,
      builder: (context, _) {
        const barCount = 28;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            double normalizedHeight = 0.25;
            if (isPlaying) {
              final phase = (i / barCount) * 2 * math.pi;
              final wave = (math.sin(_waveAnimController.value * 2 * math.pi + phase) + 1) / 2;
              final pseudoRandom = ((i * 7) % 11) / 10.0;
              normalizedHeight = (wave * 0.7 + pseudoRandom * 0.3).clamp(0.2, 0.95);
            }

            return Container(
              width: 3.5,
              height: 38 * normalizedHeight,
              decoration: BoxDecoration(
                color: isPlaying ? color : Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ─────────────────────────────────────────────────────────────
  // Horizontal Scrollable Control Tabs
  // ─────────────────────────────────────────────────────────────
  Widget _buildControlTabs(ThemeData theme, bool isDark) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          _buildTabItem(0, Icons.music_note_rounded, 'Format', _selectedFormat.color),
          _buildTabItem(1, Icons.speed_rounded, 'Bitrate', const Color(0xFF26A69A)),
          _buildTabItem(2, Icons.tune_rounded, 'Settings', const Color(0xFF7E57C2)),
          _buildTabItem(3, Icons.info_outline_rounded, 'Details', const Color(0xFF1E88E5)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        width: 82,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.18 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : (isDark ? Colors.white60 : Colors.grey[600]),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected ? color : (isDark ? Colors.white60 : Colors.grey[600]),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Active Tab Drawer Content
  // ─────────────────────────────────────────────────────────────
  Widget _buildActiveTabContent(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getTabTitle(_selectedTabIndex),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _isTabContentExpanded = false),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildTabSpecificContent(theme, isDark),
          ],
        ),
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Output Audio Format';
      case 1:
        return 'Audio Bitrate & Quality';
      case 2:
        return 'Naming & Storage Settings';
      case 3:
        return 'Video & Audio Track Details';
      default:
        return '';
    }
  }

  Widget _buildTabSpecificContent(ThemeData theme, bool isDark) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildFormatTab(theme, isDark);
      case 1:
        return _buildBitrateTab(theme, isDark);
      case 2:
        return _buildSettingsTab(theme, isDark);
      case 3:
        return _buildDetailsTab(theme, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // Tab 0: Format Selector
  Widget _buildFormatTab(ThemeData theme, bool isDark) {
    return Column(
      children: AudioExportFormat.values.map((format) {
        final isSelected = format == _selectedFormat;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedFormat = format),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? format.color.withOpacity(isDark ? 0.16 : 0.08)
                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? format.color : (isDark ? Colors.white12 : Colors.black12),
                  width: isSelected ? 1.6 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: format.color.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(format.icon, color: format.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              format.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? format.color : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: format.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '.${format.extensionName}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: format.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          format.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: format.color, size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Tab 1: Bitrate Selector
  Widget _buildBitrateTab(ThemeData theme, bool isDark) {
    if (_selectedFormat == AudioExportFormat.wav) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF26A69A).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF26A69A).withOpacity(0.3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: Color(0xFF26A69A), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'WAV uses uncompressed 16-bit PCM at original sampling rate (~1411 kbps) for 100% lossless studio audio.',
                style: TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Bitrate Encoding', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text(
              '$_selectedBitrate kbps',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _selectedFormat.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [128, 192, 256, 320].map((bitrate) {
            final isSelected = bitrate == _selectedBitrate;
            String label = '$bitrate kbps';
            if (bitrate == 128) label += ' (Compact)';
            if (bitrate == 192) label += ' (Standard)';
            if (bitrate == 320) label += ' (Max)';

            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: _selectedFormat.color.withOpacity(0.2),
              backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              side: BorderSide(
                color: isSelected ? _selectedFormat.color : Colors.transparent,
              ),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? _selectedFormat.color : null,
              ),
              onSelected: (_) => setState(() => _selectedBitrate = bitrate),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Tab 2: Settings & Naming
  Widget _buildSettingsTab(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _fileNameController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: _videoQueue.length > 1
                ? 'Filename for Active Video (#${_activeVideoIndex + 1})'
                : 'Audio Filename',
            suffixText: '.${_selectedFormat.extensionName}',
            suffixStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: _selectedFormat.color,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (val) {
            if (_activeItem != null) {
              _activeItem!.customFileName = val;
            }
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Add to Creator Audio Library', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Instantly usable in Quick Post Video Creator', style: TextStyle(fontSize: 10)),
          value: _autoAddToLibrary,
          activeColor: theme.colorScheme.primary,
          onChanged: (val) => setState(() => _autoAddToLibrary = val),
        ),
        Row(
          children: [
            const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF26A69A)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Destination: Music/Quick Post Audios (MediaStore)',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Tab 3: Details & Specs
  Widget _buildDetailsTab(ThemeData theme, bool isDark) {
    final item = _activeItem;
    final totalSec = (item?.durationMs ?? 0) ~/ 1000;
    final durStr = item?.formattedDuration ?? '00:00';
    final resolution = (item != null && item.width > 0) ? '${item.width}x${item.height}' : 'Original';
    final sourceSizeMb = item?.formattedSize ?? '0 MB';

    double estMb = 0.0;
    if (_selectedFormat == AudioExportFormat.wav) {
      estMb = (totalSec * 44100 * 2 * 2) / (1024 * 1024);
    } else {
      estMb = (totalSec * (_selectedBitrate * 1000 / 8)) / (1024 * 1024);
    }

    return Column(
      children: [
        _buildDetailRow('Active Video Duration', durStr, Icons.timer_outlined),
        _buildDetailRow('Active Source Size', sourceSizeMb, Icons.sd_card_outlined),
        _buildDetailRow('Resolution', resolution, Icons.aspect_ratio_rounded),
        _buildDetailRow('Estimated Audio Size', '~${estMb.toStringAsFixed(1)} MB', Icons.audiotrack_rounded),
        if (_videoQueue.length > 1)
          _buildDetailRow('Batch Queue Count', '${_videoQueue.length} videos queued', Icons.playlist_play_rounded),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Bottom Action Bar (Batch Extract CTA)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomActionBar(ThemeData theme, bool isDark) {
    final count = _videoQueue.length;
    final buttonLabel = count <= 1
        ? 'Extract Audio as ${_selectedFormat.label}'
        : 'Extract All ($count Videos) as ${_selectedFormat.label}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedFormat.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (_videoQueue.isEmpty || _isExtracting) ? null : _extractAudio,
            child: _isExtracting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        count > 1
                            ? 'Extracting $_batchExtractingIndex of $count (${((_batchExtractingIndex / count) * 100).toInt()}%)...'
                            : 'Extracting Audio...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(count > 1 ? Icons.dynamic_feed_rounded : _selectedFormat.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _videoQueue.isEmpty ? 'Select Video(s) to Begin' : buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
