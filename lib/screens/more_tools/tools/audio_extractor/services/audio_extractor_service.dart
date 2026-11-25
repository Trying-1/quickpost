import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quickpost/models/audio_file.dart';
import 'package:quickpost/services/audio_library_service.dart';
import '../models/audio_export_format.dart';

class AudioExtractorService {
  static const MethodChannel _platform = MethodChannel('com.quickpost.app/processor');

  /// Pick a video file from device gallery matching app-wide video picker
  static Future<File?> pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final file = File(video.path);
        if (await file.exists()) {
          return file;
        }
      }
    } catch (e) {
      // Fallback or error handled by caller
    }
    return null;
  }

  /// Pick one or multiple video files from gallery for batch processing
  static Future<List<File>> pickMultipleVideos() async {
    // 1. Try native multiple video picker from MainActivity
    try {
      final result = await _platform.invokeMethod('pickMultipleVideos');
      if (result != null && result is List) {
        final paths = result.cast<String>();
        final files = paths.map((p) => File(p)).where((f) => f.existsSync()).toList();
        if (files.isNotEmpty) return files;
      }
    } catch (_) {}

    // 2. Try ImagePicker multiple media
    try {
      final picker = ImagePicker();
      final List<XFile> medias = await picker.pickMultipleMedia();
      final videoFiles = medias
          .where((m) {
            final p = m.path.toLowerCase();
            return p.endsWith('.mp4') ||
                p.endsWith('.mov') ||
                p.endsWith('.mkv') ||
                p.endsWith('.webm') ||
                p.endsWith('.3gp');
          })
          .map((m) => File(m.path))
          .where((f) => f.existsSync())
          .toList();
      if (videoFiles.isNotEmpty) return videoFiles;
    } catch (_) {}

    // 3. Single video fallback if multi-picker was not selected
    final single = await pickVideo();
    if (single != null) return [single];

    return [];
  }

  /// Get video metadata: duration, dimensions, filesize
  static Future<Map<String, dynamic>?> getVideoMetadata(String videoPath) async {
    try {
      final result = await _platform.invokeMethod<Map<dynamic, dynamic>>(
        'getVideoMetadata',
        {'videoPath': videoPath},
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}
    return null;
  }

  /// Generate a thumbnail for the video
  static Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final result = await _platform.invokeMethod<String>(
        'generateVideoThumbnail',
        {'videoPath': videoPath},
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Extract audio from video into MP3, WAV, or M4A
  static Future<ExtractedAudioResult> extractAudio({
    required String videoPath,
    required AudioExportFormat format,
    int bitrate = 192,
    String? customFileName,
    String folderName = 'Quick Post Audios',
  }) async {
    try {
      final result = await _platform.invokeMethod<Map<dynamic, dynamic>>(
        'extractAudioAdvanced',
        {
          'videoPath': videoPath,
          'format': format.extensionName,
          'bitrate': bitrate,
          'folderName': folderName,
          'customFileName': customFileName,
        },
      );

      if (result != null) {
        return ExtractedAudioResult.fromMap(result, format);
      }

      return ExtractedAudioResult(
        success: false,
        filePath: '',
        fileName: '',
        format: format,
        durationMs: 0,
        fileSizeBytes: 0,
        sampleRate: 44100,
        channels: 2,
        errorMessage: 'Extraction returned empty response',
      );
    } on PlatformException catch (e) {
      return ExtractedAudioResult(
        success: false,
        filePath: '',
        fileName: '',
        format: format,
        durationMs: 0,
        fileSizeBytes: 0,
        sampleRate: 44100,
        channels: 2,
        errorMessage: e.message ?? 'Platform error during audio extraction',
      );
    } catch (e) {
      return ExtractedAudioResult(
        success: false,
        filePath: '',
        fileName: '',
        format: format,
        durationMs: 0,
        fileSizeBytes: 0,
        sampleRate: 44100,
        channels: 2,
        errorMessage: e.toString(),
      );
    }
  }

  /// Save extracted audio into Quick Post's internal Audio Library
  static Future<AudioFile?> addToAudioLibrary({
    required ExtractedAudioResult result,
    String? thumbnailPath,
    String? originalVideoPath,
    String folderId = 'default',
  }) async {
    try {
      if (!result.success || result.filePath.isEmpty) return null;

      final sourceFile = File(result.filePath);
      if (!await sourceFile.exists()) return null;

      final appAudioDir = await AudioLibraryService.getAudioStorageDirectory();
      final destinationFileName = 'lib_${DateTime.now().millisecondsSinceEpoch}.${result.format.extensionName}';
      final permanentAudioFile = File('${appAudioDir.path}/$destinationFileName');
      await sourceFile.copy(permanentAudioFile.path);

      String? permanentThumbPath;
      if (thumbnailPath != null) {
        final thumbFile = File(thumbnailPath);
        if (await thumbFile.exists()) {
          final thumbDir = await AudioLibraryService.getThumbnailStorageDirectory();
          final destThumb = File('${thumbDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await thumbFile.copy(destThumb.path);
          permanentThumbPath = destThumb.path;
        }
      }

      final audioFile = await AudioLibraryService.addAudioFile(
        name: result.fileName.isNotEmpty ? result.fileName : 'Audio_${DateTime.now().millisecondsSinceEpoch}',
        audioPath: permanentAudioFile.path,
        durationMs: result.durationMs,
        thumbnailPath: permanentThumbPath,
        originalVideoPath: originalVideoPath,
        fileSizeBytes: result.fileSizeBytes,
        folderId: folderId,
      );

      return audioFile;
    } catch (e) {
      return null;
    }
  }

  /// Open audio file with external music player
  static Future<void> openAudioFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (_) {}
  }

  /// Share audio file via Android share sheet
  static Future<void> shareAudioFile(String filePath, {String? fileName}) async {
    try {
      final file = XFile(filePath, name: fileName);
      await Share.shareXFiles([file], text: 'Extracted audio track');
    } catch (_) {}
  }

  /// Share multiple extracted audio files via Android share sheet
  static Future<void> shareMultipleAudioFiles(List<String> filePaths) async {
    try {
      final files = filePaths.map((p) => XFile(p)).toList();
      await Share.shareXFiles(files, text: 'Extracted audio tracks');
    } catch (_) {}
  }
}

