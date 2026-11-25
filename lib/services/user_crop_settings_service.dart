import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_crop_setting.dart';

/// Lightweight singleton service managing user-created crop presets.
class UserCropSettingsService {
  static final UserCropSettingsService instance = UserCropSettingsService._internal();

  UserCropSettingsService._internal();

  static const String _prefsKey = 'user_custom_crop_settings_v2';
  bool _isInitialized = false;

  final ValueNotifier<List<UserCropSetting>> presetsNotifier =
      ValueNotifier<List<UserCropSetting>>([]);

  List<UserCropSetting> get presets => presetsNotifier.value;

  /// Initialize and load user-saved presets
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final loaded = decoded
            .map((item) => UserCropSetting.fromMap(item as Map<String, dynamic>))
            .where((item) => !item.isBuiltIn)
            .toList();
        presetsNotifier.value = loaded;
      } else {
        presetsNotifier.value = [];
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[UserCropSettingsService] Init error: $e');
      presetsNotifier.value = [];
      _isInitialized = true;
    }
  }

  /// Add or replace a user crop preset
  Future<void> addPreset(UserCropSetting setting) async {
    await init();
    final updated = List<UserCropSetting>.from(presetsNotifier.value);
    
    final existingIdx = updated.indexWhere((p) => p.id == setting.id);
    if (existingIdx >= 0) {
      updated[existingIdx] = setting;
    } else {
      updated.add(setting);
    }

    presetsNotifier.value = updated;
    await _persistPresets();
  }

  /// Delete a preset by id
  Future<void> deletePreset(String id) async {
    await init();
    final updated = List<UserCropSetting>.from(presetsNotifier.value);
    updated.removeWhere((p) => p.id == id);
    presetsNotifier.value = updated;
    await _persistPresets();
  }

  Future<void> _persistPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = presetsNotifier.value.map((e) => e.toMap()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[UserCropSettingsService] Persist error: $e');
    }
  }

  /// Create a preset from current crop state
  UserCropSetting createFromCrop({
    required String name,
    required NormalizedCropRect rect,
    bool isExactFraming = true,
  }) {
    final clamped = rect.clamp();
    final double ratio = clamped.aspectRatio;
    final String label = formatRatioLabel(ratio);

    return UserCropSetting(
      id: 'custom_crop_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Crop ($label)' : name.trim(),
      aspectRatio: ratio,
      ratioLabel: label,
      isExactFraming: isExactFraming,
      normalizedX: clamped.x,
      normalizedY: clamped.y,
      normalizedWidth: clamped.width,
      normalizedHeight: clamped.height,
      isBuiltIn: false,
      createdAt: DateTime.now(),
    );
  }

  static String formatRatioLabel(double ratio) {
    if ((ratio - 1.0).abs() < 0.02) return '1:1';
    if ((ratio - (4 / 5)).abs() < 0.02) return '4:5';
    if ((ratio - (9 / 16)).abs() < 0.02) return '9:16';
    if ((ratio - (16 / 9)).abs() < 0.02) return '16:9';
    if ((ratio - (4 / 3)).abs() < 0.02) return '4:3';
    if ((ratio - (3 / 4)).abs() < 0.02) return '3:4';
    if ((ratio - (21 / 9)).abs() < 0.03) return '21:9';
    if ((ratio - 3.0).abs() < 0.05) return '3:1';
    return ratio.toStringAsFixed(2);
  }
}
