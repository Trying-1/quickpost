import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// In-App Update Service
/// 
/// Handles checking and installing app updates from Play Store

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();
  
  /// Check if update is available
  Future<bool> checkForUpdate() async {
    if (kDebugMode) {
      print('🔄 Checking for app updates...');
    }
    
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (kDebugMode) {
          print('✅ Update available!');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('✅ App is up to date');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking for updates: $e');
      }
      return false;
    }
  }
  
  /// Perform flexible update (user can continue using app while downloading)
  Future<void> performFlexibleUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          
          // Listen for download completion
          InAppUpdate.completeFlexibleUpdate().then((_) {
            if (kDebugMode) {
              print('✅ Update installed successfully');
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error performing flexible update: $e');
      }
    }
  }
  
  /// Perform immediate update (blocks app until update is installed)
  /// Use for critical updates only
  Future<void> performImmediateUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error performing immediate update: $e');
      }
    }
  }
}
