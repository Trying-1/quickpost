// Import all individual template files
import '../../models/template_config.dart';
import 'single_image_template.dart';
import 'grid_template.dart';

/// Central registry of all available templates
/// Each template is defined in its own file for better organization
class TemplateDefinitions {
  /// Map of all available templates
  /// Key: template ID, Value: template configuration
  static const Map<String, TemplateConfig> templates = {
    'single_image_post': singleImageTemplate,
    'grid_post': gridTemplate,
  };

  static TemplateConfig? getTemplate(String id) {
    return templates[id];
  }

  static List<String> getAllTemplateIds() {
    return templates.keys.toList();
  }

  static List<TemplateConfig> getAllTemplates() {
    return templates.values.toList();
  }
}
