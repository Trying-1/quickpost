import 'package:flutter/material.dart';
import 'video_template_base.dart';

class FadeInTemplate extends VideoTemplateBase {
  @override
  String get id => 'fade_in';
  
  @override
  String get name => 'Fade In';
  
  @override
  IconData get icon => Icons.blur_on;
  
  @override
  Color get color => Colors.purple;
  
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'fadeInDuration': 1.0,
    };
  }
  
  @override
  Widget buildSettingsUI({
    required BuildContext context,
    required Map<String, dynamic> settings,
    required Function(Map<String, dynamic>) onSettingsChanged,
    required bool isProcessing,
  }) {
    final fadeInDuration = settings['fadeInDuration'] ?? 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('fadeInDuration'),
          initialValue: fadeInDuration.toStringAsFixed(1),
          decoration: const InputDecoration(
            labelText: 'Fade In Duration (seconds)',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            helperText: 'Range: 0 - 10 seconds (decimals allowed)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !isProcessing,
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed >= 0 && parsed <= 10) {
              onSettingsChanged({'fadeInDuration': parsed});
            }
          },
        ),
      ],
    );
  }
  
  @override
  bool validateSettings(Map<String, dynamic> settings) {
    return settings.containsKey('fadeInDuration');
  }
  
  @override
  Map<String, dynamic> getNativeSettings(Map<String, dynamic> settings) {
    return {
      'fadeInDuration': settings['fadeInDuration'] ?? 1.0,
      'zoomScale': 1.2,
      'zoomDuration': 2.0,
    };
  }
}
