import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_file.dart';
import '../models/audio_folder.dart';

class AudioLibraryService {
  static const String _audioBoxName = 'audio_library';
  static const String _folderBoxName = 'audio_folders';
  static Box<AudioFile>? _audioBox;
  static Box<AudioFolder>? _folderBox;

  /// Initialize Hive and open the audio library boxes
  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AudioFileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AudioFolderAdapter());
    }
    
    _audioBox = await Hive.openBox<AudioFile>(_audioBoxName);
    _folderBox = await Hive.openBox<AudioFolder>(_folderBoxName);
    
    // Initialize default folders if empty
    if (_folderBox!.isEmpty) {
      await _initializeDefaultFolders();
    } else {
      // Check if "All Audio" folder exists, if not add it
      if (!_folderBox!.containsKey('all_audio')) {
        final allAudioFolder = AudioFolder(
          id: 'all_audio',
          name: 'All Audio',
          description: 'View all extracted audio',
          dateCreated: DateTime.now(),
          colorValue: 0xFF9C27B0, // Purple
          iconName: 'library_music',
        );
        await _folderBox!.put('all_audio', allAudioFolder);
      }
    }
  }
  
  /// Initialize default folders
  static Future<void> _initializeDefaultFolders() async {
    final defaultFolders = AudioFolder.getDefaultFolders();
    for (var folder in defaultFolders) {
      await _folderBox!.put(folder.id, folder);
    }
  }

  /// Get the audio library box
  static Box<AudioFile> get box {
    if (_audioBox == null || !_audioBox!.isOpen) {
      throw Exception('AudioLibraryService not initialized. Call init() first.');
    }
    return _audioBox!;
  }
  
  /// Get the folder box
  static Box<AudioFolder> get folderBox {
    if (_folderBox == null || !_folderBox!.isOpen) {
      throw Exception('AudioLibraryService not initialized. Call init() first.');
    }
    return _folderBox!;
  }

  /// Get directory for storing extracted audio files
  static Future<Directory> getAudioStorageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/extracted_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Get directory for storing audio thumbnails
  static Future<Directory> getThumbnailStorageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${appDir.path}/audio_thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  /// Add a new audio file to the library
  static Future<AudioFile> addAudioFile({
    required String name,
    required String audioPath,
    required int durationMs,
    String? thumbnailPath,
    String? originalVideoPath,
    required int fileSizeBytes,
    String folderId = 'default',
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final audioFile = AudioFile(
      id: id,
      name: name,
      audioPath: audioPath,
      durationMs: durationMs,
      dateExtracted: DateTime.now(),
      thumbnailPath: thumbnailPath,
      originalVideoPath: originalVideoPath,
      fileSizeBytes: fileSizeBytes,
      folderId: folderId,
    );

    await box.put(id, audioFile);
    return audioFile;
  }

  /// Get all audio files from the library
  static List<AudioFile> getAllAudioFiles() {
    return box.values.toList()
      ..sort((a, b) => b.dateExtracted.compareTo(a.dateExtracted));
  }

  /// Get audio file by ID
  static AudioFile? getAudioFile(String id) {
    return box.get(id);
  }

  /// Delete an audio file from the library
  static Future<void> deleteAudioFile(String id) async {
    final audioFile = box.get(id);
    if (audioFile != null) {
      // Delete the actual audio file
      final audioFileObj = File(audioFile.audioPath);
      if (await audioFileObj.exists()) {
        await audioFileObj.delete();
      }

      // Delete the thumbnail if it exists
      if (audioFile.thumbnailPath != null) {
        final thumbFile = File(audioFile.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      // Remove from Hive
      await box.delete(id);
    }
  }

  /// Clear all audio files from the library
  static Future<void> clearAll() async {
    // Delete all audio files
    for (var audioFile in box.values) {
      final audioFileObj = File(audioFile.audioPath);
      if (await audioFileObj.exists()) {
        await audioFileObj.delete();
      }

      if (audioFile.thumbnailPath != null) {
        final thumbFile = File(audioFile.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }
    }

    // Clear the box
    await box.clear();
  }

  /// Get total storage used by audio library
  static Future<int> getTotalStorageUsed() async {
    int total = 0;
    for (var audioFile in box.values) {
      total += audioFile.fileSizeBytes;
      
      if (audioFile.thumbnailPath != null) {
        final thumbFile = File(audioFile.thumbnailPath!);
        if (await thumbFile.exists()) {
          total += await thumbFile.length();
        }
      }
    }
    return total;
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Close the Hive boxes
  static Future<void> close() async {
    await _audioBox?.close();
    await _folderBox?.close();
  }
  
  // ==================== FOLDER MANAGEMENT ====================
  
  /// Get all folders
  static List<AudioFolder> getAllFolders() {
    return folderBox.values.toList()
      ..sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
  }
  
  /// Get folder by ID
  static AudioFolder? getFolder(String id) {
    return folderBox.get(id);
  }
  
  /// Create a new folder
  static Future<AudioFolder> createFolder({
    required String name,
    String? description,
    int colorValue = 0xFF9C27B0,
    String? iconName,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final folder = AudioFolder(
      id: id,
      name: name,
      description: description,
      dateCreated: DateTime.now(),
      colorValue: colorValue,
      iconName: iconName,
    );
    
    await folderBox.put(id, folder);
    return folder;
  }
  
  /// Update folder
  static Future<void> updateFolder(AudioFolder folder) async {
    await folderBox.put(folder.id, folder);
  }
  
  /// Delete folder (moves audio to default folder)
  static Future<void> deleteFolder(String folderId) async {
    if (folderId == 'default') {
      throw Exception('Cannot delete default folder');
    }
    
    // Move all audio files to default folder
    final audioFiles = getAudioFilesByFolder(folderId);
    for (var audio in audioFiles) {
      audio.folderId = 'default';
      await box.put(audio.id, audio);
    }
    
    // Delete the folder
    await folderBox.delete(folderId);
  }
  
  /// Get audio files by folder
  static List<AudioFile> getAudioFilesByFolder(String folderId) {
    return box.values.where((audio) => audio.folderId == folderId).toList()
      ..sort((a, b) => b.dateExtracted.compareTo(a.dateExtracted));
  }
  
  /// Move audio file to folder
  static Future<void> moveAudioToFolder(String audioId, String folderId) async {
    final audio = box.get(audioId);
    if (audio != null) {
      audio.folderId = folderId;
      await box.put(audioId, audio);
    }
  }
  
  /// Get audio count by folder
  static int getAudioCountByFolder(String folderId) {
    return box.values.where((audio) => audio.folderId == folderId).length;
  }
  
  /// Get folder with audio count
  static Map<String, dynamic> getFolderWithCount(String folderId) {
    final folder = getFolder(folderId);
    final count = getAudioCountByFolder(folderId);
    return {
      'folder': folder,
      'count': count,
    };
  }
}
