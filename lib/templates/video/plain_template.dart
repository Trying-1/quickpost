import 'package:flutter/material.dart';
import 'video_template_base.dart';

class PlainTemplate extends VideoTemplateBase {
  @override
  String get id => 'plain';
  
  @override
  String get name => 'Plain';
  
  @override
  IconData get icon => Icons.image;
  
  @override
  Color get color => Colors.grey;
  
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {};
  }
  
  @override
  Widget buildSettingsUI({
    required BuildContext context,
    required Map<String, dynamic> settings,
    required Function(Map<String, dynamic>) onSettingsChanged,
    required bool isProcessing,
  }) {
    return const SizedBox.shrink(); // No settings for plain template
  }
  
  @override
  bool validateSettings(Map<String, dynamic> settings) {
    return true; // No validation needed
  }
  
  @override
  Map<String, dynamic> getNativeSettings(Map<String, dynamic> settings, {Map<String, dynamic>? automationSettings}) {
    final Map<String, dynamic> native = {
      'fadeInDuration': 1.0,
      'zoomScale': 1.2,
      'zoomDuration': 2.0,
    };
    if (automationSettings != null) {
      native['automationSettings'] = automationSettings;
    }
    return native;
  }
}
