import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../models/audio_file.dart';
import '../../../services/audio_library_service.dart';
import '../../audio_library/audio_library_screen_with_folders.dart';

class AudioSelectorWidget extends StatelessWidget {
  final File? selectedAudio;
  final String? audioDuration;
  final bool isPlayingAudio;
  final Function(File, String?) onAudioSelected;
  final Function() onAudioRemoved;
  final Function(bool) onPlaybackToggle;
  final bool isProcessing;
  
  static const platform = MethodChannel('com.quickpost.app/processor');
  
  const AudioSelectorWidget({
    Key? key,
    required this.selectedAudio,
    required this.audioDuration,
    required this.isPlayingAudio,
    required this.onAudioSelected,
    required this.onAudioRemoved,
    required this.onPlaybackToggle,
    required this.isProcessing,
  }) : super(key: key);
  
  Future<void> _pickAudio(BuildContext context) async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Audio Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_music, color: Colors.purple),
              title: const Text('Audio Library'),
              subtitle: const Text('Use saved audio'),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.audio_file, color: Colors.orange),
              title: const Text('Audio File'),
              subtitle: const Text('Select an audio file'),
              onTap: () => Navigator.pop(context, 'audio'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.blue),
              title: const Text('Extract from Video'),
              subtitle: const Text('Extract and save audio'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    if (source == 'library') {
      await _openAudioLibrary(context);
      return;
    }
    
    try {
      if (source == 'video') {
        await _extractAudioFromVideo(context);
      } else {
        final result = await platform.invokeMethod('pickAudioFile', {'source': source});
        if (result != null) {
          final durationResult = await platform.invokeMethod('getAudioDuration', {'audioPath': result});
          onAudioSelected(File(result as String), durationResult as String?);
        }
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick audio: ${e.message}')),
        );
      }
    }
  }
  
  Future<void> _openAudioLibrary(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioLibraryScreenWithFolders(
          onAudioSelected: (audioFile) {
            onAudioSelected(File(audioFile.audioPath), audioFile.durationFormatted);
          },
        ),
      ),
    );
  }
  
  Future<void> _extractAudioFromVideo(BuildContext context) async {
    // Show video preview dialog
    final shouldExtract = await _showVideoPreviewDialog(context);
    if (shouldExtract != true) return;
    
    try {
      final result = await platform.invokeMethod('pickAudioFile', {'source': 'video'});
      if (result != null) {
        final audioPath = result as String;
        final durationResult = await platform.invokeMethod('getAudioDuration', {'audioPath': audioPath});
        
        // Save to library
        await _saveToLibrary(audioPath, durationResult as String?);
        
        onAudioSelected(File(audioPath), durationResult);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio extracted and saved to library'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract audio: $e')),
        );
      }
    }
  }
  
  Future<bool?> _showVideoPreviewDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extract Audio'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Select a video to extract audio from.\n\nThe audio will be saved to your library for future use.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SELECT VIDEO'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveToLibrary(String audioPath, String? duration) async {
    try {
      final audioFile = File(audioPath);
      final fileSize = await audioFile.length();
      
      // Parse duration
      int durationMs = 0;
      if (duration != null) {
        final parts = duration.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]) ?? 0;
          final seconds = int.tryParse(parts[1]) ?? 0;
          durationMs = (minutes * 60 + seconds) * 1000;
        }
      }
      
      // Copy to permanent storage
      final audioDir = await AudioLibraryService.getAudioStorageDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newAudioFile = File('${audioDir.path}/audio_$timestamp.m4a');
      await audioFile.copy(newAudioFile.path);
      
      // Generate thumbnail (optional)
      String? thumbnailPath;
      // Note: We can't generate thumbnail from audio, but we could save video thumbnail if we had video path
      
      // Save to library
      await AudioLibraryService.addAudioFile(
        name: 'Extracted Audio ${DateTime.now().day}/${DateTime.now().month}',
        audioPath: newAudioFile.path,
        durationMs: durationMs,
        fileSizeBytes: fileSize,
        thumbnailPath: thumbnailPath,
      );
    } catch (e) {
      // Silently fail - not critical
    }
  }
  
  Future<void> _togglePlayback() async {
    if (selectedAudio == null) return;
    
    try {
      if (isPlayingAudio) {
        await platform.invokeMethod('stopAudio');
        onPlaybackToggle(false);
      } else {
        await platform.invokeMethod('playAudio', {'audioPath': selectedAudio!.path});
        onPlaybackToggle(true);
      }
    } on PlatformException catch (e) {
      onPlaybackToggle(false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add Audio Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isProcessing ? null : () => _pickAudio(context),
            icon: const Icon(Icons.audio_file, size: 18),
            label: const Text('Audio'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        
        // Show selected audio if any
        if (selectedAudio != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              // Play button
              InkWell(
                onTap: isProcessing ? null : _togglePlayback,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Icon(
                    isPlayingAudio ? Icons.stop : Icons.play_arrow,
                    size: 18,
                    color: Colors.green[700],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Audio info
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.audiotrack, color: Colors.orange[700], size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          selectedAudio!.path.split('/').last,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (audioDuration != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          audioDuration!,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: isProcessing ? null : onAudioRemoved,
                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
