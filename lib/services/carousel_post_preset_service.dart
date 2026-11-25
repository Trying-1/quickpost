import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CarouselPostPresetService {
  static const String _boxName = 'carousel_post_presets_v1';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  static Future<Directory> getBackupDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Quick Post Backup');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final dir = Directory('${Directory.current.path}/Quick Post Backup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static List<Map<String, dynamic>> getAllPresets() {
    return _box.values
        .map((val) => Map<String, dynamic>.from(val as Map))
        .where((map) => map['id'] != 'latest_preset_auto')
        .toList();
  }

  static Future<void> savePreset(String id, String name, Map<String, dynamic> data) async {
    final entry = {
      'id': id,
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    await _box.put(id, entry);
  }

  static Future<void> deletePreset(String id) async {
    await _box.delete(id);
  }

  static Future<String> exportPresetsToFile({String? customFileName}) async {
    final presets = getAllPresets();
    final jsonStr = json.encode(presets);
    final backupDir = await getBackupDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = customFileName ?? 'carousel_presets_$timestamp.json';
    final file = File('${backupDir.path}/$fileName');
    await file.writeAsString(jsonStr);

    try {
      const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
        'filePath': file.path,
        'mimeType': 'application/json',
      });
    } catch (_) {}

    return file.path;
  }

  static Future<int> importPresetsFromFile({String? filePath}) async {
    String? path = filePath;
    if (path == null) {
      path = await const MethodChannel('com.quickpost.app/processor').invokeMethod<String>('importFile', {
        'mimeType': '*/*',
      });
    }
    if (path == null) return 0;
    final file = File(path);
    if (!await file.exists()) return 0;

    try {
      final content = await file.readAsString();
      final decoded = json.decode(content);
      int count = 0;
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final id = map['id']?.toString() ?? 'preset_${DateTime.now().millisecondsSinceEpoch}_$count';
            await _box.put(id, map);
            count++;
          }
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
