import 'video_template_base.dart';
import 'fade_in_template.dart';
import 'plain_template.dart';
import 'zoom_in_template.dart';
import 'zoom_out_template.dart';
import 'image_sequence_template.dart';

/// Central registry for all video templates
class VideoTemplateRegistry {
  static final VideoTemplateRegistry _instance = VideoTemplateRegistry._internal();
  factory VideoTemplateRegistry() => _instance;
  VideoTemplateRegistry._internal();
  
  final Map<String, VideoTemplateBase> _templates = {
    'fade_in': FadeInTemplate(),
    'plain': PlainTemplate(),
    'zoom_in': ZoomInTemplate(),
    'zoom_out': ZoomOutTemplate(),
    'image_sequence': ImageSequenceTemplate(),
  };
  
  /// Get template by ID
  VideoTemplateBase? getTemplate(String id) {
    return _templates[id];
  }
  
  /// Get all templates
  List<VideoTemplateBase> getAllTemplates() {
    return _templates.values.toList();
  }
  
  /// Get all template IDs
  List<String> getAllTemplateIds() {
    return _templates.keys.toList();
  }
  
  /// Check if template exists
  bool hasTemplate(String id) {
    return _templates.containsKey(id);
  }
}
