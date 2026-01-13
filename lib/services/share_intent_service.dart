import 'package:flutter/services.dart';

/// Service to handle share intents from other apps
class ShareIntentService {
  static const platform = MethodChannel('com.quickpost.app/processor');
  
  static Function(List<String> imagePaths, String? purpose)? _onImagesShared;

  /// Initialize the share intent listener
  static void init({
    required Function(List<String> imagePaths, String? purpose) onImagesShared,
  }) {
    _onImagesShared = onImagesShared;
    
    // Listen for method calls from native side
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onImagesShared') {
        final paths = List<String>.from(call.arguments['paths'] as List);
        final count = call.arguments['count'] as int;
        final purpose = call.arguments['purpose'] as String?;
        print('[ShareIntentService] Received $count shared images with purpose: $purpose');
        _onImagesShared?.call(paths, purpose);
      }
    });
  }

  /// Get shared images (called on app startup)
  static Future<(List<String>, String?)> getSharedImages() async {
    try {
      final result = await platform.invokeMethod<Map>('getSharedImages');
      if (result != null) {
        final paths = List<String>.from(result['paths'] as List);
        final count = result['count'] as int;
        final purpose = result['purpose'] as String?;
        if (count > 0) {
          print('[ShareIntentService] Retrieved $count shared images with purpose: $purpose');
        }
        return (paths, purpose);
      }
      return (<String>[], null);
    } catch (e) {
      print('[ShareIntentService] Error getting shared images: $e');
      return (<String>[], null);
    }
  }
}
