import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_image_asset.dart';

/// Service responsible for managing local permanent storage of categorized
/// anime image assets, including persistent backup export & import (surviving uninstalls).
class AnimeAssetStorageService {
  AnimeAssetStorageService._();
  static final AnimeAssetStorageService instance = AnimeAssetStorageService._();

  static const String _storageKey = 'anime_stored_image_assets';
  static const String _categoriesKey = 'anime_asset_categories';

  static const List<String> defaultCategories = [
    'General',
  ];

  Directory? _assetsDir;

  Future<Directory> _getAssetsDirectory() async {
    if (_assetsDir != null && await _assetsDir!.exists()) {
      return _assetsDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/anime_assets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _assetsDir = dir;
    return dir;
  }

  /// Persistent public backup directory surviving app uninstall and reinstall.
  static Future<Directory> getPublicBackupDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Quick Post Backup/Anime Assets');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/Quick Post Backup/Anime Assets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get all stored categories (defaults + user added ones)
  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_categoriesKey) ?? [];
    final set = <String>{...defaultCategories, ...custom};
    final list = set.toList();
    list.sort((a, b) {
      if (a == 'General') return -1;
      if (b == 'General') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  /// Add a new custom anime category
  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_categoriesKey) ?? [];
    if (!custom.contains(trimmed) && !defaultCategories.contains(trimmed)) {
      custom.add(trimmed);
      await prefs.setStringList(_categoriesKey, custom);
    }
  }

  /// Delete a category (does not delete images, moves images to 'General')
  Future<void> deleteCategory(String category) async {
    if (category == 'General') return;
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_categoriesKey) ?? [];
    custom.remove(category);
    await prefs.setStringList(_categoriesKey, custom);

    // Reassign any assets using this category to General
    final assets = await getAssets();
    bool updated = false;
    for (int i = 0; i < assets.length; i++) {
      if (assets[i].animeName.toLowerCase() == category.toLowerCase()) {
        assets[i] = assets[i].copyWith(animeName: 'General');
        updated = true;
      }
    }
    if (updated) {
      await _saveAssetsList(assets);
    }
  }

  /// Load all assets from local index, verifying files exist
  Future<List<AnimeImageAsset>> getAssets({String? filterAnime}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      final List<AnimeImageAsset> validAssets = [];

      for (final jsonStr in jsonList) {
        try {
          final asset = AnimeImageAsset.fromJson(jsonStr);
          if (File(asset.filePath).existsSync()) {
            if (filterAnime == null ||
                filterAnime.isEmpty ||
                filterAnime == 'All' ||
                asset.animeName.toLowerCase() == filterAnime.toLowerCase()) {
              validAssets.add(asset);
            }
          }
        } catch (e) {
          debugPrint('Error parsing asset JSON: $e');
        }
      }

      // Sort newest first
      validAssets.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return validAssets;
    } catch (e) {
      debugPrint('Error fetching anime assets: $e');
      return [];
    }
  }

  /// Import multiple images from temporary or external file paths into
  /// persistent app storage under an anime category and optional tags.
  Future<List<AnimeImageAsset>> importImages({
    required String animeName,
    List<String>? tags,
    required List<String> sourceFilePaths,
  }) async {
    final targetDir = await _getAssetsDirectory();
    final List<AnimeImageAsset> imported = [];
    final category = animeName.trim().isEmpty ? 'General' : animeName.trim();
    final cleanTags = tags != null
        ? tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList()
        : <String>[];

    // Ensure category is registered
    await addCategory(category);

    for (final srcPath in sourceFilePaths) {
      final srcFile = File(srcPath);
      if (!await srcFile.exists()) continue;

      try {
        final id = 'asset_${DateTime.now().millisecondsSinceEpoch}_${srcPath.hashCode.abs()}';
        final extension = srcPath.contains('.') ? srcPath.split('.').last : 'jpg';
        final destinationFile = File('${targetDir.path}/$id.$extension');

        // Copy permanently into documents directory
        await srcFile.copy(destinationFile.path);

        final size = await destinationFile.length();
        final asset = AnimeImageAsset(
          id: id,
          filePath: destinationFile.path,
          animeName: category,
          tags: cleanTags,
          addedAt: DateTime.now(),
          fileSizeBytes: size,
        );

        imported.add(asset);
      } catch (e) {
        debugPrint('Failed to copy and import asset $srcPath: $e');
      }
    }

    if (imported.isNotEmpty) {
      final current = await _loadRawAssets();
      current.addAll(imported);
      await _saveAssetsList(current);
    }

    return imported;
  }

  /// Import a single image file into asset storage
  Future<AnimeImageAsset?> importSingleImage({
    required String animeName,
    List<String>? tags,
    required String sourceFilePath,
  }) async {
    final results = await importImages(
      animeName: animeName,
      tags: tags,
      sourceFilePaths: [sourceFilePath],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update the anime category for a specific asset
  Future<bool> updateAssetCategory(String assetId, String newAnimeName) async {
    return updateAssetTags(assetId, animeName: newAnimeName);
  }

  /// Tag many assets with one anime name in a single read/write. Returns count updated.
  Future<int> tagAssets(Iterable<String> assetIds, String animeName) async {
    final category = animeName.trim().isEmpty ? 'General' : animeName.trim();
    await addCategory(category);
    final ids = assetIds.toSet();
    final assets = await _loadRawAssets();
    int updated = 0;
    for (int i = 0; i < assets.length; i++) {
      if (ids.contains(assets[i].id)) {
        assets[i] = assets[i].copyWith(animeName: category);
        updated++;
      }
    }
    if (updated > 0) await _saveAssetsList(assets);
    return updated;
  }

  /// Update category and/or tags for a specific asset
  Future<bool> updateAssetTags(
    String assetId, {
    String? animeName,
    List<String>? tags,
  }) async {
    final assets = await _loadRawAssets();
    final index = assets.indexWhere((a) => a.id == assetId);
    if (index == -1) return false;

    String finalCategory = assets[index].animeName;
    if (animeName != null) {
      finalCategory = animeName.trim().isEmpty ? 'General' : animeName.trim();
      await addCategory(finalCategory);
    }

    final finalTags = tags != null
        ? tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList()
        : assets[index].tags;

    assets[index] = assets[index].copyWith(
      animeName: finalCategory,
      tags: finalTags,
    );
    await _saveAssetsList(assets);
    return true;
  }

  // ===========================================================================
  // SMART TAG MATCHING & SLIDE AUTO-POPULATION
  // ===========================================================================

  /// Normalizes anime names or tags for flexible matching (case-insensitive, trims, removes punctuation)
  static String normalizeAnimeName(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ') // remove bracketed text e.g. (TV), [Season 1]
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Determines if an asset's tag/animeName matches a slide's anime title
  static bool isAnimeMatch(String assetTag, String slideAnimeTitle) {
    final cleanTag = normalizeAnimeName(assetTag);
    final cleanTitle = normalizeAnimeName(slideAnimeTitle);

    if (cleanTag.isEmpty || cleanTitle.isEmpty) return false;
    if (cleanTag == 'general' || cleanTag == 'all') return false;

    // Exact match
    if (cleanTag == cleanTitle) return true;

    // Direct containment
    if (cleanTitle.contains(cleanTag) || cleanTag.contains(cleanTitle)) return true;

    // Check subtitle segments before/after colons, dashes, slashes
    final parts = slideAnimeTitle
        .split(RegExp(r'[:\-/|]'))
        .map(normalizeAnimeName)
        .where((s) => s.length >= 2);
    for (final part in parts) {
      if (part == cleanTag || part.contains(cleanTag) || cleanTag.contains(part)) {
        return true;
      }
    }

    // Word token overlap (e.g. "Jujutsu Kaisen Season 2" matches "Jujutsu Kaisen")
    final tagWords = cleanTag.split(' ').where((w) => w.length > 2).toSet();
    final titleWords = cleanTitle.split(' ').where((w) => w.length > 2).toSet();
    if (tagWords.isNotEmpty && titleWords.isNotEmpty) {
      final intersection = tagWords.intersection(titleWords);
      if (tagWords.length <= 2 && intersection.isNotEmpty) {
        return true;
      }
      if (intersection.length >= 2) {
        return true;
      }
    }

    return false;
  }

  /// Find all stored assets matching a specific anime title (by animeName, tags, or file name)
  Future<List<AnimeImageAsset>> findAssetsForAnime(String animeTitle) async {
    final assets = await getAssets();
    final trimmed = animeTitle.trim();
    if (trimmed.isEmpty) return [];

    final List<AnimeImageAsset> matches = [];
    for (final asset in assets) {
      bool matched = false;
      for (final tag in asset.allTags) {
        if (isAnimeMatch(tag, trimmed)) {
          matched = true;
          break;
        }
      }
      if (!matched && isAnimeMatch(asset.displayName, trimmed)) {
        matched = true;
      }
      if (matched) {
        matches.add(asset);
      }
    }
    return matches;
  }

  /// Automatically matches and assigns stored tagged images to slides based on each slide's animeName.
  /// Ensures different images are assigned to slides sharing the same anime when multiple images are available.
  Future<Map<int, AnimeImageAsset>> autoMatchAssetsForSlides(List<AnimeCarouselSlide> slides) async {
    final allAssets = await getAssets();
    if (allAssets.isEmpty) return {};

    final Map<int, AnimeImageAsset> result = {};
    final Set<String> usedAssetIds = {};

    for (int i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final targetTitle = slide.type == SlideType.anime
          ? slide.animeName.trim()
          : (slide.type == SlideType.cover ? slide.coverTitle.trim() : '');

      if (targetTitle.isEmpty) continue;

      // Find matching assets
      final matchingAssets = allAssets.where((asset) {
        for (final tag in asset.allTags) {
          if (isAnimeMatch(tag, targetTitle)) return true;
        }
        return false;
      }).toList();

      if (matchingAssets.isEmpty) continue;

      // Pick an unused asset first if available
      AnimeImageAsset? chosen;
      for (final asset in matchingAssets) {
        if (!usedAssetIds.contains(asset.id)) {
          chosen = asset;
          break;
        }
      }
      // If all matches were used, reuse the first match
      chosen ??= matchingAssets.first;

      usedAssetIds.add(chosen.id);
      result[i] = chosen;
    }

    return result;
  }

  /// Delete an asset and remove its underlying file
  Future<bool> deleteAsset(String assetId) async {
    final assets = await _loadRawAssets();
    final index = assets.indexWhere((a) => a.id == assetId);
    if (index == -1) return false;

    final target = assets.removeAt(index);
    try {
      final file = File(target.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting asset file: $e');
    }

    await _saveAssetsList(assets);
    return true;
  }

  /// Counts of assets per category
  Future<Map<String, int>> getCategoryCounts() async {
    final assets = await getAssets();
    final Map<String, int> counts = {'All': assets.length};
    for (final a in assets) {
      counts[a.animeName] = (counts[a.animeName] ?? 0) + 1;
    }
    return counts;
  }

  // ===========================================================================
  // BACKUP EXPORT & IMPORT (SURVIVING UNINSTALL / REINSTALL)
  // ===========================================================================

  /// Package all labeled images and metadata into a portable .zip backup
  /// saved in public Downloads/Quick Post Backup/Anime Assets/ and shareable.
  Future<String?> exportAssetsToZip({bool share = true}) async {
    try {
      final assets = await getAssets();
      if (assets.isEmpty) return null;

      final categories = await getCategories();
      final archive = Archive();

      final List<Map<String, dynamic>> assetManifest = [];

      for (final asset in assets) {
        final file = File(asset.filePath);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final ext = asset.filePath.contains('.') ? asset.filePath.split('.').last : 'jpg';
        final archiveFilePath = 'images/${asset.id}.$ext';

        archive.addFile(ArchiveFile(archiveFilePath, bytes.length, bytes));

        assetManifest.add({
          'id': asset.id,
          'archivePath': archiveFilePath,
          'animeName': asset.animeName,
          'tags': asset.tags,
          'addedAt': asset.addedAt.toIso8601String(),
          'fileSizeBytes': bytes.length,
          'displayName': asset.displayName,
        });
      }

      if (assetManifest.isEmpty) return null;

      // Add manifest.json with labels and categorization
      final manifestMap = {
        'version': 1,
        'type': 'anime_labeled_assets_backup',
        'exportedAt': DateTime.now().toIso8601String(),
        'count': assetManifest.length,
        'categories': categories,
        'assets': assetManifest,
      };

      final manifestBytes = utf8.encode(jsonEncode(manifestMap));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;

      final backupDir = await getPublicBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'anime_assets_backup_$timestamp.zip';
      final backupFile = File('${backupDir.path}/$fileName');
      await backupFile.writeAsBytes(zipData);

      // Trigger Android media scanner so it's instantly discoverable
      try {
        const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
          'filePath': backupFile.path,
          'mimeType': 'application/zip',
        });
      } catch (_) {}

      if (share) {
        await Share.shareXFiles(
          [XFile(backupFile.path)],
          subject: 'Anime Labeled Images Backup',
          text: 'Backup of ${assetManifest.length} labeled anime images from Quick Post.',
        );
      }

      return backupFile.path;
    } catch (e) {
      debugPrint('Error exporting anime assets to zip: $e');
      return null;
    }
  }

  /// Import labeled images from a .zip backup archive (from Downloads or FilePicker),
  /// unpacking images into permanent storage and restoring anime categories.
  Future<int> importAssetsFromZip({String? specificZipPath}) async {
    try {
      String? zipPath = specificZipPath;

      if (zipPath == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
          dialogTitle: 'Select Anime Assets Backup ZIP',
        );

        if (result == null || result.files.isEmpty || result.files.single.path == null) {
          return 0;
        }
        zipPath = result.files.single.path!;
      }

      final zipFile = File(zipPath);
      if (!await zipFile.exists()) return 0;

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestArchiveFile = archive.findFile('manifest.json');
      if (manifestArchiveFile == null) {
        throw Exception('Invalid backup: manifest.json is missing.');
      }

      final manifestStr = utf8.decode(manifestArchiveFile.content as List<int>);
      final manifestMap = jsonDecode(manifestStr) as Map<String, dynamic>;

      final rawCategories = (manifestMap['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      for (final cat in rawCategories) {
        await addCategory(cat);
      }

      final rawAssets = manifestMap['assets'] as List<dynamic>? ?? [];
      final targetDir = await _getAssetsDirectory();
      final currentAssets = await _loadRawAssets();

      int importedCount = 0;

      for (final item in rawAssets) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final id = map['id'] as String? ?? 'asset_${DateTime.now().millisecondsSinceEpoch}_$importedCount';
        final archivePath = map['archivePath'] as String?;
        final animeName = map['animeName'] as String? ?? 'General';
        final addedAt = map['addedAt'] != null
            ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
            : DateTime.now();

        if (archivePath == null) continue;
        final imageArchiveFile = archive.findFile(archivePath);
        if (imageArchiveFile == null) continue;

        final ext = archivePath.contains('.') ? archivePath.split('.').last : 'jpg';
        final targetFile = File('${targetDir.path}/$id.$ext');

        // Extract image bytes to permanent app storage
        await targetFile.writeAsBytes(imageArchiveFile.content as List<int>);

        final rawTags = map['tags'];
        List<String> parsedTags = [];
        if (rawTags is List) {
          parsedTags = rawTags.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }

        final size = await targetFile.length();
        final restoredAsset = AnimeImageAsset(
          id: id,
          filePath: targetFile.path,
          animeName: animeName,
          tags: parsedTags,
          addedAt: addedAt,
          fileSizeBytes: size,
        );

        // Update or append
        final existingIndex = currentAssets.indexWhere((a) => a.id == id);
        if (existingIndex != -1) {
          currentAssets[existingIndex] = restoredAsset;
        } else {
          currentAssets.add(restoredAsset);
        }

        importedCount++;
      }

      if (importedCount > 0) {
        await _saveAssetsList(currentAssets);
      }

      return importedCount;
    } catch (e) {
      debugPrint('Error importing anime assets from zip: $e');
      rethrow;
    }
  }

  /// Check public backup directory for existing backup files (e.g. after reinstall)
  static Future<List<File>> getExistingBackups() async {
    try {
      final dir = await getPublicBackupDirectory();
      if (!await dir.exists()) return [];

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.zip'))
          .toList();

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint('Error reading existing backups: $e');
      return [];
    }
  }

  // Internal helper to read without filters
  Future<List<AnimeImageAsset>> _loadRawAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    final List<AnimeImageAsset> list = [];
    for (final str in jsonList) {
      try {
        list.add(AnimeImageAsset.fromJson(str));
      } catch (_) {}
    }
    return list;
  }

  // Internal helper to persist asset list
  Future<void> _saveAssetsList(List<AnimeImageAsset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = assets.map((a) => a.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }
}
