import 'package:hive_flutter/hive_flutter.dart';
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
