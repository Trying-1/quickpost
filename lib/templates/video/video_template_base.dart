import 'package:flutter/material.dart';
import 'dart:io';

/// Base class for all video templates
/// Each template defines its own UI and settings
abstract class VideoTemplateBase {
  /// Template identifier
  String get id;
  
  /// Display name
  String get name;
  
  /// Icon for template selection
  IconData get icon;
  
  /// Color for template
  Color get color;
  
  /// Build template-specific settings UI
  Widget buildSettingsUI({
    required BuildContext context,
    required Map<String, dynamic> settings,
    required Function(Map<String, dynamic>) onSettingsChanged,
    required bool isProcessing,
  });
  
  /// Get default settings for this template
  Map<String, dynamic> getDefaultSettings();
  
  /// Validate settings before creating video
  bool validateSettings(Map<String, dynamic> settings);
  
  /// Get settings to pass to native code
  Map<String, dynamic> getNativeSettings(Map<String, dynamic> settings, {Map<String, dynamic>? automationSettings});
}

/// Template settings state
class TemplateSettings {
  final String templateId;
  final Map<String, dynamic> settings;
  
  TemplateSettings({
    required this.templateId,
    required this.settings,
  });
  
  TemplateSettings copyWith({
    String? templateId,
    Map<String, dynamic>? settings,
  }) {
    return TemplateSettings(
      templateId: templateId ?? this.templateId,
      settings: settings ?? Map.from(this.settings),
    );
  }
}
