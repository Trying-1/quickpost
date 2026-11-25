import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/anime_post_preset_service.dart';
import '../models/anime_custom_layout.dart';

/// Service for persisting and managing user-created custom layouts in SharedPreferences,
/// including JSON backup, single layout export, and cross-device importing.
class AnimeCustomLayoutService {
  static const String _storageKey = 'anime_custom_saved_layouts_v1';

  /// Load all saved custom layouts from local storage, newest first.
  static Future<List<AnimeCustomLayout>> loadCustomLayouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      if (list == null || list.isEmpty) {
        return [];
      }
      return list
          .map((item) {
            try {
              return AnimeCustomLayout.fromJson(item);
            } catch (_) {
              return null;
            }
          })
          .whereType<AnimeCustomLayout>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save or update a custom layout.
  static Future<bool> saveCustomLayout(AnimeCustomLayout layout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await loadCustomLayouts();
      existing.removeWhere((item) => item.id == layout.id);
      existing.insert(0, layout);

      final encodedList = existing.map((item) => item.toJson()).toList();
      return await prefs.setStringList(_storageKey, encodedList);
    } catch (_) {
      return false;
    }
  }

  /// Delete a saved custom layout by ID.
  static Future<bool> deleteCustomLayout(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await loadCustomLayouts();
      existing.removeWhere((item) => item.id == id);
      final encodedList = existing.map((item) => item.toJson()).toList();
      return await prefs.setStringList(_storageKey, encodedList);
    } catch (_) {
      return false;
    }
  }

  /// Export a single layout to a formatted JSON file and optionally invoke native share.
  static Future<String?> exportLayoutToFile(AnimeCustomLayout layout, {bool share = true}) async {
    try {
      final map = layout.toMap();
      final jsonStr = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'type': 'anime_custom_layout_single',
        'exportedAt': DateTime.now().toIso8601String(),
        'layout': map,
      });

      final backupDir = await AnimePostPresetService.getBackupDirectory();
      final sanitizedName = layout.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'layout_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      try {
        const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'application/json',
        });
      } catch (_) {}

      if (share) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Custom Layout - ${layout.name}',
          text: 'Here is my custom anime post layout: ${layout.name}',
        );
      }

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Export all custom layouts as a multi-layout JSON backup and optionally invoke native share.
  static Future<String?> exportAllLayoutsToFile({bool share = true}) async {
    try {
      final layouts = await loadCustomLayouts();
      if (layouts.isEmpty) return null;

      final jsonStr = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'type': 'anime_custom_layouts_backup',
        'exportedAt': DateTime.now().toIso8601String(),
        'count': layouts.length,
        'layouts': layouts.map((l) => l.toMap()).toList(),
      });

      final backupDir = await AnimePostPresetService.getBackupDirectory();
      final fileName = 'anime_layouts_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      try {
        const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'application/json',
        });
      } catch (_) {}

      if (share) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Anime Custom Layouts Backup',
          text: 'Here is a backup of my custom anime post layouts (${layouts.length} layouts).',
        );
      }

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Opens the device file picker to select a layout JSON file and imports layout(s).
  /// Supports both single-layout and multi-layout backup formats.
  /// Returns the count of successfully imported layouts.
  static Future<int> importLayoutsFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result == null || result.files.single.path == null) {
        return 0;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final dynamic decoded = json.decode(content);

      final List<AnimeCustomLayout> importedList = [];

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('layout') && decoded['layout'] is Map) {
          importedList.add(AnimeCustomLayout.fromMap(Map<String, dynamic>.from(decoded['layout'] as Map)));
        } else if (decoded.containsKey('layouts') && decoded['layouts'] is List) {
          for (var item in decoded['layouts'] as List) {
            if (item is Map) {
              importedList.add(AnimeCustomLayout.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        } else if (decoded.containsKey('name') &&
            (decoded.containsKey('contentOffsetX') || decoded.containsKey('componentOffsets') || decoded.containsKey('showRankBadge'))) {
          importedList.add(AnimeCustomLayout.fromMap(decoded));
        }
      } else if (decoded is List) {
        for (var item in decoded) {
          if (item is Map) {
            importedList.add(AnimeCustomLayout.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }

      if (importedList.isEmpty) {
        return 0;
      }

      final existing = await loadCustomLayouts();
      int addedCount = 0;

      for (var imported in importedList) {
        existing.removeWhere((item) => item.id == imported.id);
        existing.insert(0, imported);
        addedCount++;
      }

      final prefs = await SharedPreferences.getInstance();
      final encodedList = existing.map((item) => item.toJson()).toList();
      await prefs.setStringList(_storageKey, encodedList);

      return addedCount;
    } catch (_) {
      return 0;
    }
  }
}
