import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/carousel_post_preset_service.dart';
import '../models/carousel_custom_layout.dart';

/// Service for persisting and managing user-created custom layouts in SharedPreferences,
/// including JSON backup, single layout export, and cross-device importing.
class CarouselCustomLayoutService {
  static const String _storageKey = 'carousel_custom_saved_layouts_v1';

  /// Load all saved custom layouts from local storage, newest first.
  static Future<List<CarouselCustomLayout>> loadCustomLayouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      if (list == null || list.isEmpty) {
        return [];
      }
      return list
          .map((item) {
            try {
              return CarouselCustomLayout.fromJson(item);
            } catch (_) {
              return null;
            }
          })
          .whereType<CarouselCustomLayout>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save or update a custom layout.
  static Future<bool> saveCustomLayout(CarouselCustomLayout layout) async {
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

  /// Export all custom layouts to a JSON file in public Downloads.
  static Future<String?> exportAllLayoutsToFile({String? customFileName}) async {
    try {
      final layouts = await loadCustomLayouts();
      if (layouts.isEmpty) return null;

      final data = {
        'version': 1,
        'type': 'carousel_custom_layouts',
        'exportedAt': DateTime.now().toIso8601String(),
        'layouts': layouts.map((l) => l.toMap()).toList(),
      };

      final jsonStr = json.encode(data);
      final backupDir = await CarouselPostPresetService.getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ?? 'carousel_layouts_backup_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      try {
        const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'application/json',
        });
      } catch (_) {}

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Import custom layouts from a JSON file.
  static Future<int> importLayoutsFromFile({String? filePath}) async {
    try {
      String? path = filePath;
      if (path == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null || result.files.isEmpty || result.files.first.path == null) {
          return 0;
        }
        path = result.files.first.path!;
      }

      final file = File(path);
      if (!await file.exists()) return 0;

      final jsonStr = await file.readAsString();
      final decoded = json.decode(jsonStr);

      final List<dynamic> rawList;
      if (decoded is Map && decoded['layouts'] is List) {
        rawList = decoded['layouts'] as List;
      } else if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map) {
        rawList = [decoded];
      } else {
        return 0;
      }

      int imported = 0;
      for (final item in rawList) {
        if (item is Map) {
          try {
            final layout = CarouselCustomLayout.fromMap(Map<String, dynamic>.from(item));
            final success = await saveCustomLayout(layout);
            if (success) imported++;
          } catch (_) {}
        }
      }
      return imported;
    } catch (_) {
      return 0;
    }
  }
}

