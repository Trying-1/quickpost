import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/audio_file.dart';
import '../../services/audio_library_service.dart';

class AudioLibraryScreen extends StatefulWidget {
  final Function(AudioFile)? onAudioSelected;

  const AudioLibraryScreen({
    Key? key,
    this.onAudioSelected,
  }) : super(key: key);

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  List<AudioFile> _audioFiles = [];
  bool _isLoading = true;
  VideoPlayerController? _previewController;
  String? _playingAudioId;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _loadAudioFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = AudioLibraryService.getAllAudioFiles();
      setState(() {
        _audioFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio library: $e')),
        );
      }
    }
  }

  Future<void> _playAudio(AudioFile audioFile) async {
    // Stop current playback
    await _previewController?.pause();
    await _previewController?.dispose();

    setState(() => _playingAudioId = audioFile.id);

    try {
      _previewController = VideoPlayerController.file(File(audioFile.audioPath));
      await _previewController!.initialize();
      await _previewController!.play();

      _previewController!.addListener(() {
        if (_previewController!.value.position >= _previewController!.value.duration) {
          setState(() => _playingAudioId = null);
        }
      });
    } catch (e) {
      setState(() => _playingAudioId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    await _previewController?.pause();
    await _previewController?.dispose();
    _previewController = null;
    setState(() => _playingAudioId = null);
  }

  Future<void> _renameAudio(AudioFile audioFile) async {
    final controller = TextEditingController(text: audioFile.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Audio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != audioFile.name) {
      try {
        await AudioLibraryService.renameAudioFile(audioFile.id, newName);
        await _loadAudioFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio renamed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error renaming audio: $e')),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _deleteAudio(AudioFile audioFile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audio'),
        content: Text('Delete "${audioFile.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (_playingAudioId == audioFile.id) {
          await _stopAudio();
        }
        await AudioLibraryService.deleteAudioFile(audioFile.id);
        await _loadAudioFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting audio: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAll() async {
    if (_audioFiles.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All'),
        content: Text('Delete all ${_audioFiles.length} audio files?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _stopAudio();
        await AudioLibraryService.clearAll();
        await _loadAudioFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All audio files deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing library: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Library'),
        actions: [
          if (_audioFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _audioFiles.isEmpty
              ? _buildEmptyState()
              : _buildAudioList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No audio files yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Extract audio from videos to build your library',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioList() {
    return Column(
      children: [
        // Storage info
        FutureBuilder<int>(
          future: AudioLibraryService.getTotalStorageUsed(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(12),
              color: Colors.purple[50],
              child: Row(
                children: [
                  Icon(Icons.storage, size: 16, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Text(
                    '${_audioFiles.length} files • ${AudioLibraryService.formatBytes(snapshot.data!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Audio list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _audioFiles.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final audioFile = _audioFiles[index];
              final isPlaying = _playingAudioId == audioFile.id;

              return ListTile(
                leading: _buildThumbnail(audioFile),
                title: Text(
                  audioFile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(audioFile.durationFormatted, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Icon(Icons.storage, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(audioFile.fileSizeFormatted, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(audioFile.dateFormatted, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Play/Stop button
                    IconButton(
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      color: isPlaying ? Colors.red : Colors.purple,
                      onPressed: () {
                        if (isPlaying) {
                          _stopAudio();
                        } else {
                          _playAudio(audioFile);
                        }
                      },
                    ),
                    // Rename button
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: Colors.blue[400],
                      onPressed: () => _renameAudio(audioFile),
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red[400],
                      onPressed: () => _deleteAudio(audioFile),
                    ),
                  ],
                ),
                onTap: widget.onAudioSelected != null
                    ? () {
                        Navigator.pop(context);
                        widget.onAudioSelected!(audioFile);
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(AudioFile audioFile) {
    if (audioFile.thumbnailPath != null && File(audioFile.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(audioFile.thumbnailPath!),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: Colors.purple[700]),
    );
  }
}
