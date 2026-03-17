import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/instagram_quote_template.dart';

class InstagramQuoteTemplateService {
  // Separate boxes for full vs handle-only templates
  static const String _fullBoxName = 'instagram_quote_templates_full';
  static const String _handleBoxName = 'instagram_quote_templates_handle';

  static Box<InstagramQuoteTemplate>? _fullBox;
  static Box<InstagramQuoteTemplate>? _handleBox;
  static const _uuid = Uuid();

  static Future<Box<InstagramQuoteTemplate>> _getBox({required bool handleOnly}) async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(InstagramQuoteTemplateAdapter());
    }

    if (handleOnly) {
      _handleBox ??= await Hive.openBox<InstagramQuoteTemplate>(_handleBoxName);
      return _handleBox!;
    } else {
      _fullBox ??= await Hive.openBox<InstagramQuoteTemplate>(_fullBoxName);
      return _fullBox!;
    }
  }

  static Future<List<InstagramQuoteTemplate>> getTemplates({required bool handleOnly}) async {
    final box = await _getBox(handleOnly: handleOnly);
    return box.values.toList();
  }

  static Future<InstagramQuoteTemplate> saveTemplate(
    InstagramQuoteTemplate template, {
    required bool handleOnly,
  }) async {
    final box = await _getBox(handleOnly: handleOnly);
    if (template.id.isEmpty) {
      template.id = _uuid.v4();
    }
    await box.put(template.id, template);
    return template;
  }

  static Future<void> deleteTemplate(String id, {required bool handleOnly}) async {
    final box = await _getBox(handleOnly: handleOnly);
    await box.delete(id);
  }
}
