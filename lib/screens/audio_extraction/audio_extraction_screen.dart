import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../models/audio_folder.dart';
import '../../services/audio_library_service.dart';
import '../../services/analytics_service.dart';
import '../../services/ad_service.dart';

class AudioExtractionScreen extends StatefulWidget {
  const AudioExtractionScreen({Key? key}) : super(key: key);

  @override
  State<AudioExtractionScreen> createState() => _AudioExtractionScreenState();
}

class _AudioExtractionScreenState extends State<AudioExtractionScreen> {
  static const platform = MethodChannel('com.quickpost.app/processor');
  
  List<VideoItem> _videos = [];
  bool _isExtracting = false;
  List<AudioFolder> _folders = [];
  String _selectedFolderId = 'default';

  @override
  void initState() {
    super.initState();
    _loadFolders();
    AnalyticsService().setCurrentScreen(screenName: 'Audio Extraction');
  }

  @override
  void dispose() {
    for (var video in _videos) {
      video.controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFolders() async {
    final folders = AudioLibraryService.getAllFolders()
        .where((f) => f.id != 'all_audio') // Exclude "All Audio" from selection
        .toList();
    setState(() => _folders = folders);
  }

  Future<void> _pickVideos() async {
    try {
      final result = await platform.invokeMethod('pickMultipleVideos');
      if (result != null && result is List) {
        final videoPaths = result.cast<String>();
        
        for (var path in videoPaths) {
          // Get video metadata
          Map<String, dynamic>? metadata;
          try {
            final result = await platform.invokeMethod('getVideoMetadata', {'videoPath': path});
            metadata = result != null ? Map<String, dynamic>.from(result) : null;
          } catch (e) {
            // Metadata not critical
          }
          
          // Generate thumbnail
          String? thumbnailPath;
          try {
            thumbnailPath = await platform.invokeMethod('generateVideoThumbnail', {'videoPath': path});
          } catch (e) {
            // Thumbnail not critical
          }

          final videoItem = VideoItem(
            path: path,
            name: path.split('/').last,
            durationMs: metadata?['durationMs'] as int? ?? 0,
            fileSizeBytes: metadata?['fileSizeBytes'] as int? ?? 0,
            thumbnailPath: thumbnailPath,
          );

          setState(() => _videos.add(videoItem));
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking videos: ${e.message}')),
        );
      }
    }
  }

  Future<void> _removeVideo(int index) async {
    final video = _videos[index];
    await video.controller?.dispose();
    setState(() => _videos.removeAt(index));
  }

  Future<void> _previewVideo(VideoItem video) async {
    // Initialize video controller if not already done
    if (video.controller == null) {
      video.controller = VideoPlayerController.file(File(video.path));
      await video.controller!.initialize();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video Player
            AspectRatio(
              aspectRatio: video.controller!.value.aspectRatio,
              child: VideoPlayer(video.controller!),
            ),
            // Controls
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      video.controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        if (video.controller!.value.isPlaying) {
                          video.controller!.pause();
                        } else {
                          video.controller!.play();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.white, size: 32),
                    onPressed: () {
                      video.controller!.pause();
                      video.controller!.seekTo(Duration.zero);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () {
                      video.controller!.pause();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Pause video when dialog closes
      video.controller?.pause();
    });
  }

  Future<void> _extractAllAudio() async {
    if (_videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add videos first')),
      );
      return;
    }

    AnalyticsService().logSaveAction(feature: 'audio_extraction', type: 'audio_batch');
    setState(() => _isExtracting = true);

    int successCount = 0;
    int failCount = 0;

    for (var video in _videos) {
      try {
        // Extract audio
        final audioPath = await platform.invokeMethod('extractAudioFromVideo', {
          'videoPath': video.path,
        });

        if (audioPath != null) {
          // Get audio duration
          final durationResult = await platform.invokeMethod('getAudioDuration', {
            'audioPath': audioPath,
          });

          // Copy to permanent storage
          final audioFile = File(audioPath as String);
          final fileSize = await audioFile.length();
          
          final audioDir = await AudioLibraryService.getAudioStorageDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newAudioFile = File('${audioDir.path}/audio_$timestamp.m4a');
          await audioFile.copy(newAudioFile.path);

          // Parse duration
          int durationMs = video.durationMs;
          if (durationResult != null) {
            final parts = (durationResult as String).split(':');
            if (parts.length == 2) {
              final minutes = int.tryParse(parts[0]) ?? 0;
              final seconds = int.tryParse(parts[1]) ?? 0;
              durationMs = (minutes * 60 + seconds) * 1000;
            }
          }

          // Copy thumbnail to permanent storage
          String? permanentThumbnailPath;
          if (video.thumbnailPath != null) {
            final thumbDir = await AudioLibraryService.getThumbnailStorageDirectory();
            final thumbFile = File(video.thumbnailPath!);
            if (await thumbFile.exists()) {
              final newThumbFile = File('${thumbDir.path}/thumb_$timestamp.jpg');
              await thumbFile.copy(newThumbFile.path);
              permanentThumbnailPath = newThumbFile.path;
            }
          }

          // Save to library
          await AudioLibraryService.addAudioFile(
            name: video.name.replaceAll('.mp4', '').replaceAll('.mov', ''),
            audioPath: newAudioFile.path,
            durationMs: durationMs,
            fileSizeBytes: fileSize,
            thumbnailPath: permanentThumbnailPath,
            originalVideoPath: video.path,
            folderId: _selectedFolderId,
          );

          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    setState(() {
      _isExtracting = false;
      _videos.clear();
    });

    if (mounted) {
      if (successCount > 0) {
        AdService().showInterstitialAd();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Extracted $successCount audio${successCount != 1 ? 's' : ''}'
              '${failCount > 0 ? ', $failCount failed' : ''}'),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'library_music':
        return Icons.library_music;
      case 'trending_up':
        return Icons.trending_up;
      case 'spa':
        return Icons.spa;
      case 'music_note':
        return Icons.music_note;
      default:
        return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Audio'),
        actions: [
          if (_videos.isNotEmpty && !_isExtracting)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
              onPressed: () {
                setState(() => _videos.clear());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Folder Selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Save to Folder:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedFolderId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _folders.map((folder) {
                    return DropdownMenuItem(
                      value: folder.id,
                      child: Row(
                        children: [
                          Icon(
                            _getIconData(folder.iconName),
                            size: 20,
                            color: Color(folder.colorValue),
                          ),
                          const SizedBox(width: 8),
                          Text(folder.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedFolderId = value);
                    }
                  },
                ),
              ],
            ),
          ),

          // Video List
          Expanded(
            child: _videos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No videos added',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add videos',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _videos.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      return ListTile(
                        leading: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildVideoThumbnail(video),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          video.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(video.durationMs),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.storage, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _formatFileSize(video.fileSizeBytes),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeVideo(index),
                        ),
                        onTap: () => _previewVideo(video),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExtracting ? null : _pickVideos,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Videos'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExtracting ? null : _extractAllAudio,
                    icon: _isExtracting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.audiotrack),
                    label: Text(_isExtracting ? 'Extracting...' : 'Extract Audio'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
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

  Widget _buildVideoThumbnail(VideoItem video) {
    if (video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(video.thumbnailPath!),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.videocam, color: Colors.purple[700]),
    );
  }
}

class VideoItem {
  final String path;
  final String name;
  final int durationMs;
  final int fileSizeBytes;
  final String? thumbnailPath;
  VideoPlayerController? controller;

  VideoItem({
    required this.path,
    required this.name,
    required this.durationMs,
    required this.fileSizeBytes,
    this.thumbnailPath,
  });
}
