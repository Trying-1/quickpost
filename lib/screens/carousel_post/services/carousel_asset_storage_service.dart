import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/carousel_image_asset.dart';

/// Service responsible for managing local permanent storage of categorized
/// carousel image assets, including persistent backup export & import (surviving uninstalls).
class CarouselAssetStorageService {
  CarouselAssetStorageService._();
  static final CarouselAssetStorageService instance = CarouselAssetStorageService._();

  static const String _storageKey = 'carousel_stored_image_assets';
  static const String _categoriesKey = 'carousel_asset_categories';

  static const List<String> defaultCategories = [
    'General',
    'Mindset & Stoicism',
    'Quotes & Wisdom',
    'Productivity & Habits',
    'Business & Finance',
    'Book Summaries',
    'Dark Minimal',
    'Aesthetics',
  ];

  Directory? _assetsDir;

  Future<Directory> _getAssetsDirectory() async {
    if (_assetsDir != null && await _assetsDir!.exists()) {
      return _assetsDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/carousel_assets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _assetsDir = dir;
    return dir;
  }

  /// Persistent public backup directory surviving app uninstall and reinstall.
  static Future<Directory> getPublicBackupDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Quick Post Backup/Carousel Assets');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/Quick Post Backup/Carousel Assets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all stored image assets from SharedPreferences.
  Future<List<CarouselImageAsset>> loadAssets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      if (list == null || list.isEmpty) return [];

      final assets = <CarouselImageAsset>[];
      for (final jsonStr in list) {
        try {
          final map = json.decode(jsonStr) as Map<String, dynamic>;
          final asset = CarouselImageAsset.fromMap(map);
          // Verify physical file still exists on disk
          if (File(asset.localPath).existsSync()) {
            assets.add(asset);
          }
        } catch (e) {
          debugPrint('[CarouselAssetStorageService] Corrupt entry ignored: $e');
        }
      }
      return assets;
    } catch (e) {
      debugPrint('[CarouselAssetStorageService] loadAssets error: $e');
      return [];
    }
  }

  /// Saves the updated list of assets into SharedPreferences.
  Future<void> _persistAssets(List<CarouselImageAsset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    final list = assets.map((a) => json.encode(a.toMap())).toList();
    await prefs.setStringList(_storageKey, list);
  }

  /// Loads active category tags.
  Future<List<String>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_categoriesKey);
    if (list != null && list.isNotEmpty) {
      return list;
    }
    return List.from(defaultCategories);
  }

  /// Adds a new user category tag.
  Future<void> addCategory(String categoryName) async {
    final clean = categoryName.trim();
    if (clean.isEmpty) return;
    final current = await loadCategories();
    if (!current.any((c) => c.toLowerCase() == clean.toLowerCase())) {
      current.add(clean);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_categoriesKey, current);
    }
  }

  /// Copies an external image file into sandboxed persistent app storage.
  Future<CarouselImageAsset> importImage({
    required File sourceFile,
    required String name,
    required String category,
  }) async {
    final targetDir = await _getAssetsDirectory();
    final ext = sourceFile.path.split('.').last;
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final targetFile = File('${targetDir.path}/$filename');

    await sourceFile.copy(targetFile.path);

    int? size;
    try {
      size = await targetFile.length();
    } catch (_) {}

    final asset = CarouselImageAsset(
      id: 'asset_${DateTime.now().millisecondsSinceEpoch}_${targetFile.path.hashCode}',
      name: name,
      category: category,
      localPath: targetFile.path,
      createdAt: DateTime.now(),
      fileSizeBytes: size,
    );

    final all = await loadAssets();
    all.insert(0, asset);
    await _persistAssets(all);
    await addCategory(category);

    return asset;
  }

  /// Imports multiple image files in a batch under a designated category.
  Future<List<CarouselImageAsset>> importMultipleImages({
    required List<File> files,
    required String category,
    String? baseNamePrefix,
  }) async {
    final imported = <CarouselImageAsset>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final originalName = file.path.split('/').last.split('.').first;
      final assetName = baseNamePrefix != null
          ? '$baseNamePrefix ${i + 1}'
          : (originalName.isNotEmpty ? originalName : 'Slide Asset ${i + 1}');
      try {
        final a = await importImage(
          sourceFile: file,
          name: assetName,
          category: category,
        );
        imported.add(a);
      } catch (e) {
        debugPrint('[CarouselAssetStorageService] Failed to import ${file.path}: $e');
      }
    }
    return imported;
  }

  /// Deletes a stored asset and its physical file from disk.
  Future<void> deleteAsset(String assetId) async {
    final all = await loadAssets();
    final idx = all.indexWhere((a) => a.id == assetId);
    if (idx != -1) {
      final target = all[idx];
      try {
        final file = File(target.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[CarouselAssetStorageService] Error deleting file: $e');
      }
      all.removeAt(idx);
      await _persistAssets(all);
    }
  }

  /// Exports all stored assets and metadata manifest into a portable ZIP archive.
  Future<String?> exportAssetsToZip({String? customFileName}) async {
    try {
      final assets = await loadAssets();
      if (assets.isEmpty) {
        throw Exception('No assets to export. Upload images first.');
      }

      final archive = Archive();
      final manifestList = <Map<String, dynamic>>[];

      for (int i = 0; i < assets.length; i++) {
        final a = assets[i];
        final file = File(a.localPath);
        if (await file.exists()) {
          final ext = a.localPath.split('.').last;
          final zipEntryName = 'images/${a.id}.$ext';
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(zipEntryName, bytes.length, bytes));

          manifestList.add({
            'id': a.id,
            'name': a.name,
            'category': a.category,
            'zipEntry': zipEntryName,
            'createdAt': a.createdAt.toIso8601String(),
            'fileSizeBytes': bytes.length,
          });
        }
      }

      // Add manifest.json to archive
      final categories = await loadCategories();
      final manifestData = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'totalCount': manifestList.length,
        'categories': categories,
        'assets': manifestList,
      };
      final manifestJsonBytes = utf8.encode(json.encode(manifestData));
      archive.addFile(ArchiveFile('manifest.json', manifestJsonBytes.length, manifestJsonBytes));

      final zipEncoder = ZipEncoder();
      final encodedZip = zipEncoder.encode(archive);
      if (encodedZip == null) {
        throw Exception('ZIP compression failed');
      }

      final backupDir = await getPublicBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = customFileName ?? 'carousel_assets_backup_$timestamp.zip';
      final zipFile = File('${backupDir.path}/$filename');
      await zipFile.writeAsBytes(encodedZip);

      try {
        const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
          'filePath': zipFile.path,
          'mimeType': 'application/zip',
        });
      } catch (_) {}

      return zipFile.path;
    } catch (e) {
      debugPrint('[CarouselAssetStorageService] exportAssetsToZip error: $e');
      rethrow;
    }
  }

  /// Imports a ZIP archive, unzips images, and restores categories and assets.
  Future<int> importAssetsFromZip({String? specificPath}) async {
    String? zipPath = specificPath;
    if (zipPath == null) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return 0;
      }
      zipPath = result.files.first.path!;
    }

    final file = File(zipPath);
    if (!await file.exists()) {
      throw Exception('Selected zip file does not exist');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Locate manifest.json
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null) {
      throw Exception('Invalid Carousel Assets backup: manifest.json is missing');
    }

    final manifestJson = utf8.decode(manifestEntry.content as List<int>);
    final manifestMap = json.decode(manifestJson) as Map<String, dynamic>;
    final rawAssets = (manifestMap['assets'] as List? ?? []);
    final rawCategories = (manifestMap['categories'] as List? ?? []);

    for (final c in rawCategories) {
      if (c != null && c.toString().isNotEmpty) {
        await addCategory(c.toString());
      }
    }

    final targetDir = await _getAssetsDirectory();
    final existingAssets = await loadAssets();
    int importedCount = 0;

    for (final raw in rawAssets) {
      final map = Map<String, dynamic>.from(raw as Map);
      final zipEntryName = map['zipEntry'] as String?;
      if (zipEntryName == null) continue;

      final imgEntry = archive.findFile(zipEntryName);
      if (imgEntry == null) continue;

      final ext = zipEntryName.split('.').last;
      final safeId = map['id']?.toString() ?? 'imported_${DateTime.now().millisecondsSinceEpoch}_$importedCount';
      final targetFile = File('${targetDir.path}/${safeId}.$ext');

      final imgBytes = imgEntry.content as List<int>;
      await targetFile.writeAsBytes(imgBytes);

      final asset = CarouselImageAsset(
        id: safeId,
        name: map['name']?.toString() ?? 'Restored Asset',
        category: map['category']?.toString() ?? 'General',
        localPath: targetFile.path,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        fileSizeBytes: imgBytes.length,
      );

      existingAssets.removeWhere((e) => e.id == asset.id);
      existingAssets.add(asset);
      importedCount++;
    }

    await _persistAssets(existingAssets);
    return importedCount;
  }
}

