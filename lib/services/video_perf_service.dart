import 'package:hive_flutter/hive_flutter.dart';

class VideoPerfService {
  static const String _boxName = 'video_perf';
  static const String _avgRatioKey = 'avg_ratio';
  static const String _countKey = 'process_count';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static double getAvgRatio() {
    try {
      final box = Hive.box(_boxName);
      return box.get(_avgRatioKey, defaultValue: 0.8) as double;
    } catch (_) {
      return 0.8;
    }
  }

  static Future<void> updateRatio(double newRatio) async {
    try {
      final box = Hive.box(_boxName);
      final currentAvg = getAvgRatio();
      final count = box.get(_countKey, defaultValue: 0) as int;
      
      // Moving average: (old_avg * count + new_ratio) / (count + 1)
      final newAvg = (currentAvg * count + newRatio) / (count + 1);
      
      await box.put(_avgRatioKey, newAvg);
      await box.put(_countKey, count + 1);
    } catch (e) {
      print("VideoPerfService update failed: $e");
    }
  }
}
