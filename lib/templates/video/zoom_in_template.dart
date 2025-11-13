import 'package:flutter/material.dart';
import 'video_template_base.dart';

class ZoomInTemplate extends VideoTemplateBase {
  @override
  String get id => 'zoom_in';
  
  @override
  String get name => 'Zoom In';
  
  @override
  IconData get icon => Icons.zoom_in;
  
  @override
  Color get color => Colors.purple;
  
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'zoomScale': 1.2,
      'zoomDuration': 2.0,
    };
  }
  
  @override
  Widget buildSettingsUI({
    required BuildContext context,
    required Map<String, dynamic> settings,
    required Function(Map<String, dynamic>) onSettingsChanged,
    required bool isProcessing,
  }) {
    final zoomScale = settings['zoomScale'] ?? 1.2;
    final zoomDuration = settings['zoomDuration'] ?? 2.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('zoomScale'),
          initialValue: zoomScale.toStringAsFixed(1),
          decoration: const InputDecoration(
            labelText: 'Zoom Scale (x)',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            helperText: 'Range: 1.1 - 2.0',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !isProcessing,
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed >= 1.1 && parsed <= 2.0) {
              onSettingsChanged({'zoomScale': parsed, 'zoomDuration': zoomDuration});
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('zoomDuration'),
          initialValue: zoomDuration.toStringAsFixed(1),
          decoration: const InputDecoration(
            labelText: 'Zoom Duration (seconds)',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            helperText: 'Range: 0.5 - 5.0 seconds',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !isProcessing,
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed >= 0.5 && parsed <= 5.0) {
              onSettingsChanged({'zoomScale': zoomScale, 'zoomDuration': parsed});
            }
          },
        ),
      ],
    );
  }
  
  @override
  bool validateSettings(Map<String, dynamic> settings) {
    return settings.containsKey('zoomScale') && settings.containsKey('zoomDuration');
  }
  
  @override
  Map<String, dynamic> getNativeSettings(Map<String, dynamic> settings) {
    return {
      'fadeInDuration': 1.0,
      'zoomScale': settings['zoomScale'] ?? 1.2,
      'zoomDuration': settings['zoomDuration'] ?? 2.0,
    };
  }
}
