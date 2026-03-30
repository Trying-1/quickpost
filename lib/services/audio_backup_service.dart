import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../models/audio_file.dart';
import '../models/audio_folder.dart';
import 'audio_library_service.dart';

/// Callback for progress updates during import/export
typedef ProgressCallback = void Function(double progress, String status, int current, int total);

/// Service for backing up and restoring audio library
class AudioBackupService {
  static const _channel = MethodChannel('com.quickpost.app/processor');
  static bool _isCancelled = false;

  /// Request cancellation of the current long-running operation.
  static void cancelCurrentOperation() {
    _isCancelled = true;
  }

  /// Reset cancellation flag before starting a new operation.
  static void _resetCancellation() {
    _isCancelled = false;
  }
  
  /// Export entire audio library to Downloads/Quick Post Backup/
  static Future<String> exportAudioLibrary({ProgressCallback? onProgress}) async {
    try {
      // Reset cancellation at the start of a new export
      _resetCancellation();

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
      await audioDir.create();
      
      // Copy audio files
      final audioMetadata = <Map<String, dynamic>>[];
      final totalAudio = allAudio.length;

      // Initialize progress UI with total count
      if (totalAudio > 0) {
        onProgress?.call(0.0, 'Preparing export...', 0, totalAudio);
      }
      
      for (int i = 0; i < allAudio.length; i++) {
        if (_isCancelled) {
          throw Exception('CANCELLED');
        }

        final audio = allAudio[i];
        try {
          // Update progress
          onProgress?.call(
            (i + 1) / totalAudio,
            'Exporting: ${audio.name}',
            i + 1,
            totalAudio,
          );
          
          // Copy audio file
          final audioFile = File(audio.audioPath);
          if (await audioFile.exists()) {
            final newAudioPath = '${audioDir.path}/${audio.id}.m4a';
            await audioFile.copy(newAudioPath);
            
            // Store metadata
            audioMetadata.add({
              'id': audio.id,
              'name': audio.name,
              'audioFileName': '${audio.id}.m4a',
              'thumbnailFileName': null,
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
      
      // Export folders metadata (excluding virtual "All Audio" folder)
      final foldersMetadata = allFolders
          .where((f) => f.id != 'all_audio')
          .map((folder) => {
                'id': folder.id,
                'name': folder.name,
                'description': folder.description,
                'dateCreated': folder.dateCreated.toIso8601String(),
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
  
  /// Let the user pick a backup folder via the native folder picker.
  /// Returns the selected directory path, or null if the user cancels.
  static Future<String?> pickBackupFolder() async {
    try {
      print('[AudioBackupService] Invoking native pickBackupFolder');
      final result = await _channel.invokeMethod<String>('pickBackupFolder');
      print('[AudioBackupService] pickBackupFolder result: $result');
      if (result == null || result.isEmpty) {
        return null;
      }
      return result;
    } catch (e) {
      print('[AudioBackupService] pickBackupFolder error: $e');
      return null;
    }
  }

  /// Import audio library from a SAF-picked backup folder.
  /// [treeUri] must be the content:// tree URI string returned by pickBackupFolder.
  static Future<ImportResult> importAudioLibraryFromSafUri(String treeUri, {ProgressCallback? onProgress}) async {
    try {
      _resetCancellation();
      print('[AudioBackupService] SAF import requested from treeUri: $treeUri');

      // Listen for native progress events during SAF import.
      // NOTE: MethodChannel supports a single handler process-wide, so we set it here
      // for the duration of the import.
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSafImportProgress') {
          final args = call.arguments;
          if (args is Map) {
            final current = (args['current'] as int?) ?? 0;
            final total = (args['total'] as int?) ?? 0;
            final status = (args['status'] as String?) ?? 'Importing...';
            final safeTotal = total <= 0 ? 1 : total;
            final progress = (current / safeTotal).clamp(0.0, 1.0);
            onProgress?.call(progress, status, current, total);
          }
        }
      });

      // Get destination directories in app storage
      final audioStorageDir = await AudioLibraryService.getAudioStorageDirectory();

      // Ask native side to read manifest.json and copy files into our dirs
      final resultMap = await _channel.invokeMethod<dynamic>('importBackupFromSaf', {
        'treeUri': treeUri,
        'audioDestDir': audioStorageDir.path,
      });

      if (resultMap == null) {
        throw Exception('Native SAF import returned null result');
      }
      if (resultMap is! Map) {
        throw Exception('Invalid SAF import result type: ${resultMap.runtimeType}');
      }

      final foldersData = (resultMap['folders'] as List?) ?? const [];
      final audioData = (resultMap['audio'] as List?) ?? const [];
      final importedCountNative = (resultMap['importedCount'] as int?) ?? 0;
      final skippedCountNative = (resultMap['skippedCount'] as int?) ?? 0;

      int importedCount = 0;
      int skippedCount = 0;
      int foldersCreated = 0;

      // Import folders first, similar to legacy import
      for (final dynamic folderDyn in foldersData) {
        if (folderDyn is! Map) continue;
        final folderId = folderDyn['id'] as String?;
        final folderName = folderDyn['name'] as String?;
        if (folderId == null || folderName == null) continue;

        final existingFolder = AudioLibraryService.getAllFolders()
            .where((f) => f.id == folderId)
            .firstOrNull;

        if (existingFolder == null) {
          await AudioLibraryService.createFolder(
            name: folderName,
            description: folderDyn['description'] as String?,
            iconName: folderDyn['iconName'] as String?,
            colorValue: (folderDyn['colorValue'] as int?) ?? 0xFF9C27B0,
          );
          foldersCreated++;
        }
      }

      // Import audio files
      final totalAudioSaf = audioData.length;
      int indexSaf = 0;

      // Initialize progress UI with total count
      if (totalAudioSaf > 0) {
        onProgress?.call(0.0, 'Preparing import...', 0, totalAudioSaf);
      }
      for (final dynamic audioDyn in audioData) {
        try {
          if (_isCancelled) {
            throw Exception('CANCELLED');
          }

          if (audioDyn is! Map) {
            skippedCount++;
            continue;
          }

          final audioPath = audioDyn['audioPath'] as String?;
          final name = audioDyn['name'] as String?;
          final durationValue = audioDyn['durationMs'];

          print('[AudioBackupService] Processing audio: name=$name, path=$audioPath, duration=$durationValue');

          if (audioPath == null || name == null || durationValue == null) {
            print('[AudioBackupService] Skipping audio due to missing fields');
            skippedCount++;
            continue;
          }

          final destAudioFile = File(audioPath);
          if (!await destAudioFile.exists()) {
            print('[AudioBackupService] Audio file does not exist: $audioPath');
            skippedCount++;
            continue;
          }
          
          print('[AudioBackupService] Audio file exists: $audioPath (${await destAudioFile.length()} bytes)');

          final fileSize = await destAudioFile.length();
          final durationMs = durationValue is int
              ? durationValue
              : (durationValue as num).toInt();

          final originalVideoPath = audioDyn['originalVideoPath'] as String?;
          var folderId = (audioDyn['folderId'] as String?) ?? 'default';

          // Validate that the folder exists, otherwise use 'default'
          final folderExists = AudioLibraryService.getAllFolders()
              .any((f) => f.id == folderId);
          if (!folderExists) {
            print('[AudioBackupService] Folder $folderId does not exist, using default');
            folderId = 'default';
          }

          print('[AudioBackupService] Adding audio to library: $name (folderId=$folderId)');
          
          await AudioLibraryService.addAudioFile(
            name: name,
            audioPath: destAudioFile.path,
            durationMs: durationMs,
            fileSizeBytes: fileSize,
            thumbnailPath: null,
            originalVideoPath: originalVideoPath,
            folderId: folderId,
          );

          print('[AudioBackupService] Audio added successfully');
          importedCount++;
        } catch (e) {
          print('[AudioBackupService] Error importing audio: $e');
          skippedCount++;
        }
      }

      final result = ImportResult(
        importedCount: importedCount,
        skippedCount: skippedCount,
        foldersCreated: foldersCreated,
      );

      print('[AudioBackupService] SAF import finished. '
          'imported=${result.importedCount}, skipped=${result.skippedCount}, foldersCreated=${result.foldersCreated}, '
          'nativeImported=$importedCountNative, nativeSkipped=$skippedCountNative');

      return result;
    } catch (e) {
      print('[AudioBackupService] importAudioLibraryFromSafUri error: $e');
      throw Exception('Failed to import audio library via SAF: $e');
    } finally {
      // Detach handler after import completes.
      _channel.setMethodCallHandler(null);
    }
  }
  
  /// Import audio library from backup directory
  static Future<ImportResult> importAudioLibrary(String backupPath, {ProgressCallback? onProgress}) async {
    try {
      _resetCancellation();
      print('[AudioBackupService] Import requested from: $backupPath');
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        print('[AudioBackupService] Backup directory does not exist: ${backupDir.path}');
        throw Exception('Backup directory not found');
      }
      
      // Read manifest
      final manifestFile = File('${backupDir.path}/manifest.json');
      if (!await manifestFile.exists()) {
        print('[AudioBackupService] manifest.json not found in: ${backupDir.path}');
        throw Exception('Invalid backup: manifest.json not found');
      }
      
      final manifestContent = await manifestFile.readAsString();
      print('[AudioBackupService] Loaded manifest length: ${manifestContent.length}');
      final manifest = json.decode(manifestContent) as Map<String, dynamic>;
      
      // Get storage directories
      final audioStorageDir = await AudioLibraryService.getAudioStorageDirectory();
      
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
            // Create new folder, restoring description when available
            await AudioLibraryService.createFolder(
              name: folderData['name'] as String,
              description: folderData['description'] as String?,
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
        final totalAudio = audioList.length;
        int index = 0;

        // Initialize progress UI with total count
        if (totalAudio > 0) {
          onProgress?.call(0.0, 'Preparing import...', 0, totalAudio);
        }
        for (var audioData in audioList) {
          try {
            if (_isCancelled) {
              throw Exception('CANCELLED');
            }

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
            
            // Get file size
            final fileSize = await destAudioFile.length();

            // Progress update
            index++;
            final name = audioData['name'] as String? ?? audioFileName;
            if (totalAudio > 0) {
              onProgress?.call(
                index / totalAudio,
                'Importing: $name',
                index,
                totalAudio,
              );
            }

            // Add to library
            await AudioLibraryService.addAudioFile(
              name: audioData['name'] as String,
              audioPath: destAudioFile.path,
              durationMs: audioData['durationMs'] as int,
              fileSizeBytes: fileSize,
              thumbnailPath: null,
              originalVideoPath: audioData['originalVideoPath'] as String?,
              folderId: audioData['folderId'] as String? ?? 'default',
            );
            
            importedCount++;
          } catch (e) {
            skippedCount++;
          }
        }
      }
      
      final result = ImportResult(
        importedCount: importedCount,
        skippedCount: skippedCount,
        foldersCreated: foldersCreated,
      );
      print('[AudioBackupService] Import finished. imported=${result.importedCount}, skipped=${result.skippedCount}, foldersCreated=${result.foldersCreated}');
      return result;
    } catch (e) {
      print('[AudioBackupService] importAudioLibrary error: $e');
      throw Exception('Failed to import audio library: $e');
    }
  }
  
  /// Get list of available backups
  static Future<List<BackupInfo>> getAvailableBackups() async {
    try {
      final backups = <BackupInfo>[];
      final visitedPaths = <String>{};

      // Primary backup directory used by export
      final primaryBackupDir = await _getBackupDirectory();
      final candidateRoots = <Directory>[];

      print('[AudioBackupService] Primary backup dir: ${primaryBackupDir.path}');
      if (await primaryBackupDir.exists()) {
        candidateRoots.add(primaryBackupDir);
      }

      for (final root in candidateRoots) {
        print('[AudioBackupService] Scanning root: ${root.path}');
        List<FileSystemEntity> entities;
        try {
          // Search recursively so we can find backup folders at any depth
          entities = root.listSync(recursive: true, followLinks: false);
        } catch (_) {
          continue;
        }

        for (var entity in entities) {
          if (entity is! Directory) continue;

          final path = entity.path;
          if (visitedPaths.contains(path)) continue;

          try {
            final manifestFile = File('$path/manifest.json');
            if (await manifestFile.exists()) {
              print('[AudioBackupService] Found manifest in: $path');
              final manifestContent = await manifestFile.readAsString();
              final manifest = json.decode(manifestContent) as Map<String, dynamic>;

              backups.add(BackupInfo(
                path: path,
                name: path.split('/').last,
                exportDate: DateTime.parse(manifest['exportDate'] as String),
                audioCount: manifest['audioCount'] as int,
                folderCount: manifest['folderCount'] as int,
              ));

              visitedPaths.add(path);
            } else {
              print('[AudioBackupService] No manifest.json in: $path');
            }
          } catch (e) {
            print('[AudioBackupService] Error reading manifest in $path: $e');
            // Skip invalid backups
          }
        }
      }

      print('[AudioBackupService] Total backups found: ${backups.length}');
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
