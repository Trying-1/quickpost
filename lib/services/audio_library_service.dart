import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_file.dart';
import '../models/audio_folder.dart';

class AudioLibraryService {
  static const String _audioBoxName = 'audio_library';
  static const String _folderBoxName = 'audio_folders';
  static const String _persistentRootFolderName = 'QuickPostAudio';
  static const String _indexFileName = 'index.json';
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
      if (!_folderBox!.containsKey(AudioFolder.allAudioFolderId)) {
        final allAudioFolder = AudioFolder(
          id: AudioFolder.allAudioFolderId,
          name: 'All Audio',
          description: 'View all extracted audio',
          dateCreated: DateTime.now(),
          colorValue: 0xFF9C27B0, // Purple
          iconName: 'library_music',
        );
        await _folderBox!.put(AudioFolder.allAudioFolderId, allAudioFolder);
      }
    }

    // Attempt to restore library from persistent public index on fresh installs
    await _restoreFromPersistentIndexIfNeeded();
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
    await _persistIndex();
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
      await _persistIndex();
    }
  }

  /// Rename an audio file
  static Future<void> renameAudioFile(String id, String newName) async {
    final audioFile = box.get(id);
    if (audioFile != null) {
      // Update the name in the audio file object
      audioFile.name = newName;
      
      // Save the updated audio file back to Hive
      await box.put(id, audioFile);
      
      // Persist the changes
      await _persistIndex();
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

    // Also clear all folders except the default set, then persist an empty index
    await folderBox.clear();
    await _initializeDefaultFolders();
    await _persistIndex();
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
    await _persistIndex();
    return folder;
  }
  
  /// Update folder
  static Future<void> updateFolder(AudioFolder folder) async {
    await folderBox.put(folder.id, folder);
    await _persistIndex();
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
    await _persistIndex();
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
      await _persistIndex();
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

  /// Get the root directory for persistent audio storage on Android
  static Future<Directory> _getPersistentRootDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/$_persistentRootFolderName');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/$_persistentRootFolderName');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  /// Get the index file that mirrors the audio library state in the persistent directory
  static Future<File> _getIndexFile() async {
    final rootDir = await _getPersistentRootDirectory();
    final indexFile = File('${rootDir.path}/$_indexFileName');
    if (!await indexFile.exists()) {
      await indexFile.create(recursive: true);
    }
    return indexFile;
  }

  /// Persist the current Hive audio library and folders into index.json in the persistent directory
  static Future<void> _persistIndex() async {
    try {
      final rootDir = await _getPersistentRootDirectory();
      final indexFile = await _getIndexFile();

      final allAudio = getAllAudioFiles();
      final allFolders = getAllFolders();

      final audioList = <Map<String, dynamic>>[];
      for (var audio in allAudio) {
        String relativeAudioPath;
        if (audio.audioPath.startsWith(rootDir.path)) {
          relativeAudioPath = audio.audioPath.substring(rootDir.path.length + 1);
        } else {
          relativeAudioPath = audio.audioPath;
        }

        String? relativeThumbPath;
        if (audio.thumbnailPath != null) {
          if (audio.thumbnailPath!.startsWith(rootDir.path)) {
            relativeThumbPath = audio.thumbnailPath!.substring(rootDir.path.length + 1);
          } else {
            relativeThumbPath = audio.thumbnailPath;
          }
        }

        audioList.add({
          'id': audio.id,
          'name': audio.name,
          'relativeAudioPath': relativeAudioPath,
          'relativeThumbnailPath': relativeThumbPath,
          'durationMs': audio.durationMs,
          'dateExtracted': audio.dateExtracted.toIso8601String(),
          'originalVideoPath': audio.originalVideoPath,
          'fileSizeBytes': audio.fileSizeBytes,
          'folderId': audio.folderId,
        });
      }

      final foldersList = allFolders
          .where((f) => f.id != AudioFolder.allAudioFolderId)
          .map((folder) => {
                'id': folder.id,
                'name': folder.name,
                'description': folder.description,
                'dateCreated': folder.dateCreated.toIso8601String(),
                'colorValue': folder.colorValue,
                'iconName': folder.iconName,
              })
          .toList();

      final index = {
        'version': '1.0',
        'lastUpdated': DateTime.now().toIso8601String(),
        'audioCount': audioList.length,
        'folderCount': foldersList.length,
        'folders': foldersList,
        'audio': audioList,
      };

      await indexFile.writeAsString(json.encode(index));
    } catch (_) {
      // If persisting the index fails, we don't want to break the app
    }
  }

  /// On fresh installs (empty Hive boxes), attempt to rebuild the library from the persistent index
  static Future<void> _restoreFromPersistentIndexIfNeeded() async {
    try {
      if (box.isNotEmpty) {
        return;
      }

      final rootDir = await _getPersistentRootDirectory();
      final indexFile = File('${rootDir.path}/$_indexFileName');
      if (!await indexFile.exists()) {
        return;
      }

      final content = await indexFile.readAsString();
      if (content.isEmpty) {
        return;
      }

      final data = json.decode(content) as Map<String, dynamic>;

      final foldersData = data['folders'] as List<dynamic>?;
      final audioData = data['audio'] as List<dynamic>?;

      if ((foldersData == null || foldersData.isEmpty) &&
          (audioData == null || audioData.isEmpty)) {
        return;
      }

      // Rebuild folders from index (excluding the virtual All Audio folder)
      await folderBox.clear();

      if (foldersData != null) {
        for (var folder in foldersData) {
          final map = folder as Map<String, dynamic>;
          final id = map['id'] as String;
          final name = map['name'] as String;
          final description = map['description'] as String?;
          final dateCreatedStr = map['dateCreated'] as String?;
          DateTime dateCreated;
          try {
            dateCreated = dateCreatedStr != null
                ? DateTime.parse(dateCreatedStr)
                : DateTime.now();
          } catch (_) {
            dateCreated = DateTime.now();
          }
          final colorValue = map['colorValue'] as int? ?? 0xFF9C27B0;
          final iconName = map['iconName'] as String?;

          final folderObj = AudioFolder(
            id: id,
            name: name,
            description: description,
            dateCreated: dateCreated,
            colorValue: colorValue,
            iconName: iconName,
          );

          await folderBox.put(id, folderObj);
        }
      }

      // Ensure the virtual All Audio folder exists
      if (!folderBox.containsKey(AudioFolder.allAudioFolderId)) {
        final allAudioFolder = AudioFolder(
          id: AudioFolder.allAudioFolderId,
          name: 'All Audio',
          description: 'View all extracted audio',
          dateCreated: DateTime.now(),
          colorValue: 0xFF9C27B0,
          iconName: 'library_music',
        );
        await folderBox.put(AudioFolder.allAudioFolderId, allAudioFolder);
      }

      // Rebuild audio entries from index
      if (audioData != null) {
        for (var entry in audioData) {
          final map = entry as Map<String, dynamic>;

          final id = map['id'] as String;
          final name = map['name'] as String;
          final relativeAudioPath = map['relativeAudioPath'] as String;
          final relativeThumbPath = map['relativeThumbnailPath'] as String?;
          final durationMs = map['durationMs'] as int;
          final dateExtractedStr = map['dateExtracted'] as String?;
          final originalVideoPath = map['originalVideoPath'] as String?;
          final folderId = map['folderId'] as String? ?? AudioFolder.defaultFolderId;

          final audioFile = File('${rootDir.path}/$relativeAudioPath');
          if (!await audioFile.exists()) {
            continue;
          }

          String? thumbnailPath;
          if (relativeThumbPath != null) {
            final thumbFile = File('${rootDir.path}/$relativeThumbPath');
            if (await thumbFile.exists()) {
              thumbnailPath = thumbFile.path;
            }
          }

          DateTime dateExtracted;
          try {
            dateExtracted = dateExtractedStr != null
                ? DateTime.parse(dateExtractedStr)
                : DateTime.now();
          } catch (_) {
            dateExtracted = DateTime.now();
          }

          int fileSizeBytes;
          try {
            fileSizeBytes = map['fileSizeBytes'] as int? ?? await audioFile.length();
          } catch (_) {
            fileSizeBytes = 0;
          }

          final audioObj = AudioFile(
            id: id,
            name: name,
            audioPath: audioFile.path,
            durationMs: durationMs,
            dateExtracted: dateExtracted,
            thumbnailPath: thumbnailPath,
            originalVideoPath: originalVideoPath,
            fileSizeBytes: fileSizeBytes,
            folderId: folderId,
          );

          await box.put(id, audioObj);
        }
      }
    } catch (_) {
      // If restore fails, fall back to an empty/default library
    }
  }
}
