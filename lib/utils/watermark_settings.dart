import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global toggle for showing or hiding watermarks and outro in generated media.
class WatermarkSettings {
  /// Whether the app should render the built-in watermark on templates.
  static bool showWatermark = false;

  /// Whether the app should append a 1.5s branded outro logo at the end of videos.
  static bool enableOutro = true;

  /// Optional notifier if any screen wants to listen reactively.
  static final ValueNotifier<bool> notifier =
      ValueNotifier<bool>(showWatermark);

  static final ValueNotifier<bool> outroNotifier =
      ValueNotifier<bool>(enableOutro);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      showWatermark = prefs.getBool('show_watermark') ?? false;
      enableOutro = prefs.getBool('enable_outro') ?? true;
      notifier.value = showWatermark;
      outroNotifier.value = enableOutro;
    } catch (_) {}
  }

  static Future<void> setShowWatermark(bool value) async {
    showWatermark = value;
    notifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_watermark', value);
    } catch (_) {}
  }

  static Future<void> setEnableOutro(bool value) async {
    enableOutro = value;
    outroNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_outro', value);
    } catch (_) {}
  }
}

