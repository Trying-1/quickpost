import 'package:flutter/foundation.dart';
import 'dart:io';

/// AdMob Configuration
/// 
/// Central place to manage all ad settings.
/// Uses official Google Test IDs in Debug mode and Production IDs in Release mode.
class AdConfig {
  // Global switch to enable/disable all ads in the app
  static const bool adsEnabled = true;

  // --- Production Ad Unit IDs ---
  // Managed in AdMob Console: https://apps.admob.com/
  static const String _androidAppId = 'ca-app-pub-5829296907403264~3334590442';
  static const String _androidInterstitialProdId = 'ca-app-pub-5829296907403264/3245469845';
  static const String _androidAppOpenProdId = 'ca-app-pub-5829296907403264/4919134858';

  // --- Official Google Test Ad Unit IDs ---
  // These are safe to use during development to avoid policy violations.
  static const String _androidInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _androidAppOpenTestId = 'ca-app-pub-3940256099942544/9257395915';

  /// Returns the Interstitial Ad Unit ID based on the build mode (Debug/Release)
  static String get interstitialAdUnitId {
    if (!adsEnabled) return '';
    if (kDebugMode) {
      return _androidInterstitialTestId;
    }
    return _androidInterstitialProdId;
  }

  /// Returns the App Open Ad Unit ID based on the build mode (Debug/Release)
  static String get appOpenAdUnitId {
    if (!adsEnabled) return '';
    if (kDebugMode) {
      return _androidAppOpenTestId;
    }
    return _androidAppOpenProdId;
  }

  /// Logic to decide if an interstitial should be shown after a specific action
  static bool get shouldShowInterstitialAfterExport => adsEnabled;

  /// Cooldown duration between interstitial ads to prevent annoying users
  static const Duration interstitialCooldown = Duration.zero;

  /// Helper to check if ads should be shown at all
  static bool get areAdsEnabled => adsEnabled && (Platform.isAndroid || Platform.isIOS);
}
