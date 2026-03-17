import 'package:hive/hive.dart';

class OnboardingService {
  static const String _boxName = 'onboarding';
  static const String _completedKey = 'completed';

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
}
