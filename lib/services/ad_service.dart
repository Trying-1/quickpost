import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ad_config.dart';
import 'subscription_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static const String _keyLastAppOpenShownTime = 'last_app_open_shown_ms';

  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  bool _isInterstitialAdLoading = false;
  bool _isAppOpenAdLoading = false;
  DateTime? _appOpenLoadTime;
  DateTime? _lastInterstitialShownTime;
  DateTime? _lastAppOpenShownTime;
  
  // Track if any ad is currently showing to prevent overlaps/multiple ads showing
  bool isShowingAd = false;
  
  // Flag to automatically show the App Open ad on cold start once it's loaded
  bool _showAdOnLoad = false;
  final DateTime _appStartupTime = DateTime.now();
  
  // Cooldown tracker to prevent displaying another ad too soon after dismissal
  DateTime? _lastAdDismissedTime;
  DateTime? _lastPausedTime;

  void setLastPausedTime(DateTime time) {
    _lastPausedTime = time;
  }

  String get _interstitialAdUnitId => AdConfig.interstitialAdUnitId;
  String get _appOpenAdUnitId => AdConfig.appOpenAdUnitId;

  /// Checks if the 10-minute cooldown interval for App Open ads is active
  bool get _isAppOpenCooldownActive {
    if (_lastAppOpenShownTime == null) return false;
    final elapsed = DateTime.now().difference(_lastAppOpenShownTime!);
    if (elapsed.isNegative) return false;
    return elapsed < AdConfig.appOpenCooldown;
  }

  /// Persists and updates the last App Open ad shown timestamp
  void _recordAppOpenAdShown() {
    final now = DateTime.now();
    _lastAppOpenShownTime = now;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_keyLastAppOpenShownTime, now.millisecondsSinceEpoch);
    }).catchError((e) {
      debugPrint('AdService: Failed to persist $_keyLastAppOpenShownTime: $e');
    });
  }

  Future<void> initialize() async {
    // Load persisted last App Open ad timestamp to enforce 10-minute limit across app restarts
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_keyLastAppOpenShownTime);
      if (lastMs != null) {
        _lastAppOpenShownTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
    } catch (e) {
      debugPrint('AdService: Error reading last app open ad time: $e');
    }

    if (!AdConfig.adsEnabled || SubscriptionService.isProActive) {
      debugPrint('AdService: Ads are globally disabled or Pro subscription is active.');
      return;
    }
    debugPrint('Initializing MobileAds...');
    await MobileAds.instance.initialize();
    loadInterstitialAd();
    loadAppOpenAd();
  }

  // Interstitial Ad
  void loadInterstitialAd() {
    if (!AdConfig.adsEnabled || SubscriptionService.isProActive) return;
    if (_isInterstitialAdLoading || _interstitialAd != null) return;
    _isInterstitialAdLoading = true;
    debugPrint('Loading InterstitialAd: $_interstitialAdUnitId');

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          debugPrint('InterstitialAd loaded successfully');
          
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              isShowingAd = true;
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('InterstitialAd dismissed');
              isShowingAd = false;
              _lastAdDismissedTime = DateTime.now();
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('InterstitialAd failed to show: $error');
              isShowingAd = false;
              _lastAdDismissedTime = DateTime.now();
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (!AdConfig.adsEnabled || SubscriptionService.isProActive) return;
    if (isShowingAd) {
      debugPrint('InterstitialAd skipped: Another ad is currently showing.');
      return;
    }

    if (_lastInterstitialShownTime != null) {
      final difference = DateTime.now().difference(_lastInterstitialShownTime!);
      if (difference < AdConfig.interstitialCooldown) {
        debugPrint('InterstitialAd skipped due to cooldown: ${difference.inSeconds}s elapsed');
        return;
      }
    }

    if (_interstitialAd != null) {
      debugPrint('Showing InterstitialAd...');
      _interstitialAd!.show();
      _lastInterstitialShownTime = DateTime.now();
    } else {
      debugPrint('InterstitialAd not ready yet, current state: isLoading=$_isInterstitialAdLoading');
      loadInterstitialAd();
    }
  }

  // App Open Ad
  void loadAppOpenAd() {
    if (!AdConfig.adsEnabled || !AdConfig.appOpenAdsEnabled || SubscriptionService.isProActive) return;
    if (_isAppOpenAdLoading || _appOpenAd != null) return;
    _isAppOpenAdLoading = true;
    debugPrint('Loading AppOpenAd: $_appOpenAdUnitId');

    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoading = false;
          _appOpenLoadTime = DateTime.now();
          debugPrint('AppOpenAd loaded successfully');
          
          // On cold startup, show as soon as loaded (if requested & startup window is still fresh)
          if (_showAdOnLoad) {
            _showAdOnLoad = false;
            if (_isAppOpenCooldownActive) {
              debugPrint('AppOpenAd loaded, but 10-minute cooldown limit active. Skipping display.');
              return;
            }
            final elapsed = DateTime.now().difference(_appStartupTime);
            if (AdConfig.showAppOpenOnColdStart && elapsed < AdConfig.coldStartAdTimeout) {
              debugPrint('Showing AppOpenAd on cold launch (${elapsed.inSeconds}s since startup)...');
              showAppOpenAdIfAvailable(isColdStart: true);
            } else {
              debugPrint('AppOpenAd loaded, but cold launch window expired (${elapsed.inSeconds}s since startup).');
            }
          }
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
          _showAdOnLoad = false;
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null) return false;
    if (_appOpenLoadTime == null) return false;
    // App Open ads are valid for 4 hours
    return DateTime.now().difference(_appOpenLoadTime!).inHours < 4;
  }

  /// Triggers App Open ad specifically for fresh app launch (cold start)
  void showAppOpenAdOnColdStart() {
    if (!AdConfig.adsEnabled || !AdConfig.appOpenAdsEnabled || !AdConfig.showAppOpenOnColdStart || SubscriptionService.isProActive) {
      debugPrint('AppOpenAd on cold start skipped: disabled in AdConfig or Pro active.');
      return;
    }

    if (_isAppOpenCooldownActive) {
      final elapsed = DateTime.now().difference(_lastAppOpenShownTime!);
      final remaining = AdConfig.appOpenCooldown - elapsed;
      debugPrint('AppOpenAd on cold start skipped: 10-minute limit active (${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed, ${remaining.inMinutes}m ${remaining.inSeconds % 60}s remaining).');
      return;
    }

    if (_isAppOpenAdAvailable) {
      showAppOpenAdIfAvailable(isColdStart: true);
    } else {
      debugPrint('AppOpenAd not loaded yet on cold start. Requesting show on load.');
      _showAdOnLoad = true;
      loadAppOpenAd();
    }
  }

  /// Triggers App Open ad when resuming from background
  void showAppOpenAdOnResume() {
    if (!AdConfig.adsEnabled || !AdConfig.appOpenAdsEnabled || !AdConfig.showAppOpenOnResume || SubscriptionService.isProActive) {
      debugPrint('AppOpenAd on resume skipped: disabled in AdConfig or Pro active.');
      return;
    }

    if (_isAppOpenCooldownActive) {
      final elapsed = DateTime.now().difference(_lastAppOpenShownTime!);
      final remaining = AdConfig.appOpenCooldown - elapsed;
      debugPrint('AppOpenAd on resume skipped: 10-minute limit active (${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed, ${remaining.inMinutes}m ${remaining.inSeconds % 60}s remaining).');
      return;
    }

    showAppOpenAdIfAvailable(isColdStart: false);
  }

  void showAppOpenAdIfAvailable({bool isColdStart = false}) {
    if (!AdConfig.adsEnabled || !AdConfig.appOpenAdsEnabled || SubscriptionService.isProActive) return;
    if (isColdStart && !AdConfig.showAppOpenOnColdStart) return;
    if (!isColdStart && !AdConfig.showAppOpenOnResume) return;

    if (isShowingAd) {
      debugPrint('AppOpenAd skipped: Another ad is currently showing.');
      return;
    }

    // 10-minute frequency limit check
    if (_isAppOpenCooldownActive) {
      final elapsed = DateTime.now().difference(_lastAppOpenShownTime!);
      final remaining = AdConfig.appOpenCooldown - elapsed;
      debugPrint('AppOpenAd skipped: 10-minute limit active (${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed, ${remaining.inMinutes}m ${remaining.inSeconds % 60}s remaining).');
      return;
    }
    
    // Cooldown check: prevent immediately showing an App Open ad right after dismissing one
    if (_lastAdDismissedTime != null) {
      final timeSinceDismissal = DateTime.now().difference(_lastAdDismissedTime!);
      if (timeSinceDismissal < const Duration(seconds: 15)) {
        debugPrint('AppOpenAd skipped: Too close to previous ad dismissal (${timeSinceDismissal.inSeconds}s)');
        return;
      }
    }

    // App Pause Duration Check (only relevant for resume, not cold start)
    if (!isColdStart && _lastPausedTime != null) {
      final timePaused = DateTime.now().difference(_lastPausedTime!);
      _lastPausedTime = null; // Clear to prevent double triggering
      if (timePaused < const Duration(seconds: 10)) {
        debugPrint('AppOpenAd skipped: App was only minimized/paused for ${timePaused.inSeconds}s (likely returning from file picker, camera, or short interrupt)');
        return;
      }
    }

    if (!_isAppOpenAdAvailable) {
      debugPrint('AppOpenAd not available (null or expired). Requesting show on load.');
      if (isColdStart) {
        _showAdOnLoad = true;
      }
      loadAppOpenAd();
      return;
    }

    debugPrint('Showing AppOpenAd (coldStart: $isColdStart)...');
    _recordAppOpenAdShown();
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        isShowingAd = true;
        _recordAppOpenAdShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAd dismissed');
        isShowingAd = false;
        _lastAdDismissedTime = DateTime.now();
        _recordAppOpenAdShown();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        isShowingAd = false;
        _lastAdDismissedTime = DateTime.now();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }
}
