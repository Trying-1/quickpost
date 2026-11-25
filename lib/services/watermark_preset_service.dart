import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/watermark_preset.dart';

class WatermarkPresetService {
  static const String _boxName = 'watermark_presets';
  static const String _presetKey = 'last_used_preset';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(WatermarkPresetAdapter());
    }
    await Hive.openBox<WatermarkPreset>(_boxName);
  }

  static Box<WatermarkPreset> get _box => Hive.box<WatermarkPreset>(_boxName);

  static List<WatermarkPreset> getAllPresets() {
    return _box.values.toList();
  }

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

  static Future<String> exportPresetsToFile({String? customFileName}) async {
    final jsonStr = await exportPresetsJson();
    final backupDir = await getBackupDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = customFileName ?? 'watermark_presets_$timestamp.json';
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

  static Future<String> exportPresetsJson() async {
    final presets = getAllPresets();
    final List<Map<String, dynamic>> maps = [];
    
    for (final p in presets) {
      final map = p.toMap();
      if (p.profileImagePath != null) {
        final file = File(p.profileImagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          map['profileImageBase64'] = base64Encode(bytes);
          map['profileImageExt'] = p.profileImagePath!.split('.').last;
        }
      }
      maps.add(map);
    }
    return jsonEncode(maps);
  }

  static Future<int> importPresetsJson(String jsonStr) async {
    try {
      print('[WatermarkService] Importing presets from JSON of length: ${jsonStr.length}');
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) {
        print('[WatermarkService] Error: Decoded JSON is not a List, but ${decoded.runtimeType}');
        return 0;
      }
      
      final List<dynamic> list = decoded;
      final directory = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${directory.path}/watermark_icons');
      if (!await iconDir.exists()) {
        await iconDir.create(recursive: true);
      }

      int imported = 0;
      for (final item in list) {
        if (item is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          final preset = WatermarkPreset.fromMap(map);
          
          if (map['profileImageBase64'] != null) {
            final String base64Str = map['profileImageBase64'];
            final String ext = map['profileImageExt'] ?? 'png';
            final bytes = base64Decode(base64Str);
            final fileName = 'icon_${preset.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            final file = File('${iconDir.path}/$fileName');
            await file.writeAsBytes(bytes);
            preset.profileImagePath = file.path;
          }
          
          await savePreset(preset);
          imported++;
        } else {
           print('[WatermarkService] Row skipped - not a Map: $item');
        }
      }
      print('[WatermarkService] Successfully imported $imported presets.');
      return imported;
    } catch (e) {
      print('[WatermarkService] Critical import error: $e');
      return 0;
    }
  }

  static WatermarkPreset? getLatestPreset() {
    if (_box.isEmpty) return null;
    return _box.values.last;
  }

  static Future<void> savePreset(WatermarkPreset preset) async {
    await _box.put(preset.id, preset);
  }

  static Future<void> deletePreset(String id) async {
    await _box.delete(id);
  }
}
