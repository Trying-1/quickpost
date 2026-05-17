import 'package:hive/hive.dart';

class OnboardingService {
  static const String _boxName = 'onboarding';
  static const String _completedKey = 'completed';

  static const String _goalKey = 'selected_goal';
  static const String _platformKey = 'selected_platform';
  static const String _experienceKey = 'selected_experience';
  static const String _styleKey = 'selected_style';

  static Box? _box;

  static Future<Box> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  static Future<bool> isCompleted() async {
    final box = await _getBox();
    return (box.get(_completedKey) as bool?) ?? false;
  }

  static Future<void> setCompleted(bool value) async {
    final box = await _getBox();
    await box.put(_completedKey, value);
  }

  static Future<String?> getGoal() async {
    final box = await _getBox();
    return box.get(_goalKey) as String?;
  }

  static Future<void> setGoal(String value) async {
    final box = await _getBox();
    await box.put(_goalKey, value);
  }

  static Future<String?> getPlatform() async {
    final box = await _getBox();
    return box.get(_platformKey) as String?;
  }

  static Future<void> setPlatform(String value) async {
    final box = await _getBox();
    await box.put(_platformKey, value);
  }

  static Future<String?> getExperience() async {
    final box = await _getBox();
    return box.get(_experienceKey) as String?;
  }

  static Future<void> setExperience(String value) async {
    final box = await _getBox();
    await box.put(_experienceKey, value);
  }

  static Future<String?> getStyle() async {
    final box = await _getBox();
    return box.get(_styleKey) as String?;
  }

  static Future<void> setStyle(String value) async {
    final box = await _getBox();
    await box.put(_styleKey, value);
  }
}
