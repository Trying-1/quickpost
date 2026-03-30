import 'package:flutter/foundation.dart';

/// Global toggle for showing or hiding watermarks in generated posts.
class WatermarkSettings {
  /// Whether the app should render the built-in watermark on templates.
  static bool showWatermark = false;

  /// Optional notifier if any screen wants to listen reactively.
  static final ValueNotifier<bool> notifier =
      ValueNotifier<bool>(showWatermark);

  static void setShowWatermark(bool value) {
    showWatermark = value;
    notifier.value = value;
  }
}
