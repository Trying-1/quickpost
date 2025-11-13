/// AdMob Configuration
/// 
/// Central place to manage all ad settings
/// Easy enable/disable ads from here

import 'package:flutter/foundation.dart';

class AdConfig {
  // MASTER AD CONTROL - Change this to enable/disable ALL ads
  // ============================================
  static const bool adsEnabled = false; // Set to false to disable all ads
  
  // ============================================
  // AD UNIT IDS
  // ============================================
  // Your AdMob Ad Unit IDs
  
  // Production Android Ad Unit IDs
  static const String _prodAndroidAppId = 'ca-app-pub-5829296907403264~3334590442';
  static const String _prodAndroidBannerAdUnitId = 'ca-app-pub-5829296907403264/7317233331';
  static const String _prodAndroidInterstitialAdUnitId = 'ca-app-pub-5829296907403264/3245469845';
  static const String _prodAndroidAppOpenAdUnitId = 'ca-app-pub-5829296907403264/4919134858';
  
  // Test Android Ad Unit IDs (for debug mode)
  static const String _testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String _testAndroidBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  
  // iOS Ad Unit IDs (for future)
  static const String iosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716'; // Test ID
  static const String iosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910'; // Test ID
  static const String iosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313'; // Test ID
  // ============================================
  // AD PLACEMENT CONTROLS
  // ============================================
  // Enable/disable ads in specific screens
  static const bool showBannerInPostMaker = true;
  static const bool showBannerInImageCropper = true;
  static const bool showBannerInVideoCreator = true;
  static const bool showBannerInAudioLibrary = false; 
  
  // Interstitial ad controls
  static const bool showInterstitialAfterExport = true;
  
  // ============================================
  // DEBUG MODE DETECTION
  // ============================================
  // Automatically uses test ads in debug mode, real ads in release mode
  static bool get isDebugMode => kDebugMode;
  
  // Get current App ID based on mode
  static String get androidAppId => isDebugMode ? _testAndroidAppId : _prodAndroidAppId;
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Check if ads are enabled globally
  static bool get areAdsEnabled => adsEnabled;
  
  /// Check if banner should show in specific screen
  static bool shouldShowBannerIn(String screenName) {
    if (!adsEnabled) return false;
    
    switch (screenName) {
      case 'post_maker':
        return showBannerInPostMaker;
      case 'image_cropper':
        return showBannerInImageCropper;
      case 'video_creator':
        return showBannerInVideoCreator;
      case 'audio_library':
        return showBannerInAudioLibrary;
      default:
        return false;
    }
  }
  
  /// Get banner ad unit ID for current platform
  static String getBannerAdUnitId() {
    if (isDebugMode) {
      return _testAndroidBannerAdUnitId; // Test ads in debug
    }
    return _prodAndroidBannerAdUnitId; // Real ads in release
  }
  
  /// Get interstitial ad unit ID for current platform
  static String getInterstitialAdUnitId() {
    if (isDebugMode) {
      return _testAndroidInterstitialAdUnitId; // Test ads in debug
    }
    return _prodAndroidInterstitialAdUnitId; // Real ads in release
  }
  
  /// Get rewarded ad unit ID for current platform
  static String getRewardedAdUnitId() {
    return _testAndroidRewardedAdUnitId; // Always test (not implemented)
  }
  
  /// Get app open ad unit ID for current platform
  static String getAppOpenAdUnitId() {
    if (isDebugMode) {
      return _testAndroidBannerAdUnitId; // Use banner test ID for app open in debug
    }
    return _prodAndroidAppOpenAdUnitId; // Real ads in release
  }
}
