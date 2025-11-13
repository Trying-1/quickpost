import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../models/audio_file.dart';
import '../models/audio_folder.dart';
import 'audio_library_service.dart';

/// Service for backing up and restoring audio library
class AudioBackupService {
  static const _channel = MethodChannel('com.quickpost.app/processor');
  
  /// Export entire audio library to Downloads/Quick Post Backup/
  static Future<String> exportAudioLibrary() async {
    try {
      // Get all audio files and folders
      final allAudio = AudioLibraryService.getAllAudioFiles();
      final allFolders = AudioLibraryService.getAllFolders();
      
      // Create backup directory in Downloads
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportDir = Directory('${backupDir.path}/backup_$timestamp');
      await exportDir.create(recursive: true);
      
      // Create subdirectories
      final audioDir = Directory('${exportDir.path}/audio');
      final thumbDir = Directory('${exportDir.path}/thumbnails');
      await audioDir.create();
      await thumbDir.create();
      
      // Copy audio files and thumbnails
      final audioMetadata = <Map<String, dynamic>>[];
      
      for (var audio in allAudio) {
        try {
          // Copy audio file
          final audioFile = File(audio.audioPath);
          if (await audioFile.exists()) {
            final newAudioPath = '${audioDir.path}/${audio.id}.m4a';
            await audioFile.copy(newAudioPath);
            
            // Copy thumbnail if exists
            String? newThumbnailPath;
            if (audio.thumbnailPath != null) {
              final thumbFile = File(audio.thumbnailPath!);
              if (await thumbFile.exists()) {
                newThumbnailPath = '${thumbDir.path}/${audio.id}.jpg';
                await thumbFile.copy(newThumbnailPath);
              }
            }
            
            // Store metadata
            audioMetadata.add({
              'id': audio.id,
              'name': audio.name,
              'audioFileName': '${audio.id}.m4a',
              'thumbnailFileName': audio.thumbnailPath != null ? '${audio.id}.jpg' : null,
              'durationMs': audio.durationMs,
              'dateExtracted': audio.dateExtracted.toIso8601String(),
              'originalVideoPath': audio.originalVideoPath,
              'folderId': audio.folderId,
            });
          }
        } catch (e) {
          // Skip failed files
        }
      }
      
      // Export folders metadata
      final foldersMetadata = allFolders
          .where((f) => f.id != 'all_audio') // Exclude "All Audio" virtual folder
          .map((folder) => {
                'id': folder.id,
                'name': folder.name,
                'iconName': folder.iconName,
                'colorValue': folder.colorValue,
              })
          .toList();
      
      // Create backup manifest
      final manifest = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'audioCount': audioMetadata.length,
        'folderCount': foldersMetadata.length,
        'folders': foldersMetadata,
        'audio': audioMetadata,
      };
      
      // Write manifest.json
      final manifestFile = File('${exportDir.path}/manifest.json');
      await manifestFile.writeAsString(json.encode(manifest));
      
      // Scan media so it's visible in file manager
      await _scanMediaFile(exportDir.path, 'application/json');
      
      return exportDir.path;
    } catch (e) {
      throw Exception('Failed to export audio library: $e');
    }
  }
  
  /// Import audio library from backup directory
  static Future<ImportResult> importAudioLibrary(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        throw Exception('Backup directory not found');
      }
      
      // Read manifest
      final manifestFile = File('${backupDir.path}/manifest.json');
      if (!await manifestFile.exists()) {
        throw Exception('Invalid backup: manifest.json not found');
      }
      
      final manifestContent = await manifestFile.readAsString();
      final manifest = json.decode(manifestContent) as Map<String, dynamic>;
      
      // Get storage directories
      final audioStorageDir = await AudioLibraryService.getAudioStorageDirectory();
      final thumbStorageDir = await AudioLibraryService.getThumbnailStorageDirectory();
      
      int importedCount = 0;
      int skippedCount = 0;
      int foldersCreated = 0;
      
      // Import folders first
      final folders = manifest['folders'] as List<dynamic>?;
      if (folders != null) {
        for (var folderData in folders) {
          final folderId = folderData['id'] as String;
          
          // Check if folder already exists
          final existingFolder = AudioLibraryService.getAllFolders()
              .where((f) => f.id == folderId)
              .firstOrNull;
          
          if (existingFolder == null) {
            // Create new folder
            await AudioLibraryService.createFolder(
              name: folderData['name'] as String,
              iconName: folderData['iconName'] as String?,
              colorValue: folderData['colorValue'] as int,
            );
            foldersCreated++;
          }
        }
      }
      
      // Import audio files
      final audioList = manifest['audio'] as List<dynamic>?;
      if (audioList != null) {
        for (var audioData in audioList) {
          try {
            final audioFileName = audioData['audioFileName'] as String;
            final sourceAudioFile = File('${backupDir.path}/audio/$audioFileName');
            
            if (!await sourceAudioFile.exists()) {
              skippedCount++;
              continue;
            }
            
            // Copy audio file to storage
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final destAudioFile = File('${audioStorageDir.path}/audio_$timestamp.m4a');
            await sourceAudioFile.copy(destAudioFile.path);
            
            // Copy thumbnail if exists
            String? destThumbnailPath;
            final thumbnailFileName = audioData['thumbnailFileName'] as String?;
            if (thumbnailFileName != null) {
              final sourceThumbnailFile = File('${backupDir.path}/thumbnails/$thumbnailFileName');
              if (await sourceThumbnailFile.exists()) {
                final destThumbnailFile = File('${thumbStorageDir.path}/thumb_$timestamp.jpg');
                await sourceThumbnailFile.copy(destThumbnailFile.path);
                destThumbnailPath = destThumbnailFile.path;
              }
            }
            
            // Get file size
            final fileSize = await destAudioFile.length();
            
            // Add to library
            await AudioLibraryService.addAudioFile(
              name: audioData['name'] as String,
              audioPath: destAudioFile.path,
              durationMs: audioData['durationMs'] as int,
              fileSizeBytes: fileSize,
              thumbnailPath: destThumbnailPath,
              originalVideoPath: audioData['originalVideoPath'] as String?,
              folderId: audioData['folderId'] as String? ?? 'default',
            );
            
            importedCount++;
          } catch (e) {
            skippedCount++;
          }
        }
      }
      
      return ImportResult(
        importedCount: importedCount,
        skippedCount: skippedCount,
        foldersCreated: foldersCreated,
      );
    } catch (e) {
      throw Exception('Failed to import audio library: $e');
    }
  }
  
  /// Get list of available backups
  static Future<List<BackupInfo>> getAvailableBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) {
        return [];
      }
      
      final backups = <BackupInfo>[];
      final entities = backupDir.listSync();
      
      for (var entity in entities) {
        if (entity is Directory && entity.path.contains('backup_')) {
          try {
            final manifestFile = File('${entity.path}/manifest.json');
            if (await manifestFile.exists()) {
              final manifestContent = await manifestFile.readAsString();
              final manifest = json.decode(manifestContent) as Map<String, dynamic>;
              
              backups.add(BackupInfo(
                path: entity.path,
                name: entity.path.split('/').last,
                exportDate: DateTime.parse(manifest['exportDate'] as String),
                audioCount: manifest['audioCount'] as int,
                folderCount: manifest['folderCount'] as int,
              ));
            }
          } catch (e) {
            // Skip invalid backups
          }
        }
      }
      
      // Sort by date (newest first)
      backups.sort((a, b) => b.exportDate.compareTo(a.exportDate));
      
      return backups;
    } catch (e) {
      return [];
    }
  }
  
  /// Delete a backup
  static Future<void> deleteBackup(String backupPath) async {
    final backupDir = Directory(backupPath);
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }
  
  /// Get backup directory in Downloads
  static Future<Directory> _getBackupDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Quick Post Backup');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/Quick Post Backup');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      return backupDir;
    }
  }
  
  static Future<void> _scanMediaFile(String filePath, String mimeType) async {
    try {
      await _channel.invokeMethod('scanMediaFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
    } catch (e) {
      // Silently fail - media scanner is not critical
    }
  }
}

class ImportResult {
  final int importedCount;
  final int skippedCount;
  final int foldersCreated;
  
  ImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.foldersCreated,
  });
}

class BackupInfo {
  final String path;
  final String name;
  final DateTime exportDate;
  final int audioCount;
  final int folderCount;
  
  BackupInfo({
    required this.path,
    required this.name,
    required this.exportDate,
    required this.audioCount,
    required this.folderCount,
  });
}
