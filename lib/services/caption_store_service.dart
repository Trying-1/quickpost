import 'package:hive_flutter/hive_flutter.dart';
import '../models/caption_group.dart';

class CaptionStoreService {
  static const String _boxName = 'caption_groups';
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    // We don't use TypeAdapters here to keep it simple and avoid build_runner for this new model
    // Instead we store as Map and convert
    await Hive.openBox(_boxName);
    _isInitialized = true;
  }

  static Box get _box => Hive.box(_boxName);

  static List<CaptionGroup> getAllCaptions() {
    return _box.values.map((item) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(item);
      return CaptionGroup.fromMap(map);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveCaptionGroup(CaptionGroup group) async {
    await _box.put(group.id, group.toMap());
  }

  static Future<void> deleteCaptionGroup(String id) async {
    await _box.delete(id);
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }

  static List<String> getAllCategories() {
    final captions = getAllCaptions();
    final categories = captions
        .map((e) => e.category)
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }
}
