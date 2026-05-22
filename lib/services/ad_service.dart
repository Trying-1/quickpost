import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import '../config/ad_config.dart';
import 'subscription_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  bool _isInterstitialAdLoading = false;
  bool _isAppOpenAdLoading = false;
  DateTime? _appOpenLoadTime;
  DateTime? _lastInterstitialShownTime;
  
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

  Future<void> initialize() async {
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
    if (!AdConfig.adsEnabled || SubscriptionService.isProActive) return;
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
            final timeSinceStartup = DateTime.now().difference(_appStartupTime).inSeconds;
            if (timeSinceStartup < 7) {
              debugPrint('Showing AppOpenAd on cold launch ($timeSinceStartup seconds since startup)...');
              showAppOpenAdIfAvailable();
            } else {
              debugPrint('AppOpenAd loaded, but cold launch window expired ($timeSinceStartup seconds since startup).');
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

  void showAppOpenAdIfAvailable() {
    if (!AdConfig.adsEnabled || SubscriptionService.isProActive) return;
    if (isShowingAd) {
      debugPrint('AppOpenAd skipped: Another ad is currently showing.');
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

    // App Pause Duration Check: Only show App Open if the app was actually in the background for a substantial time (e.g. at least 10 seconds)
    // This perfectly prevents showing App Open ads when returning from choosing videos/images or simple overlay permissions dialogs!
    if (_lastPausedTime != null) {
      final timePaused = DateTime.now().difference(_lastPausedTime!);
      _lastPausedTime = null; // Clear to prevent double triggering
      if (timePaused < const Duration(seconds: 10)) {
        debugPrint('AppOpenAd skipped: App was only minimized/paused for ${timePaused.inSeconds}s (likely returning from file picker, camera, or short interrupt)');
        return;
      }
    }

    if (!_isAppOpenAdAvailable) {
      debugPrint('AppOpenAd not available (null or expired). Requesting show on load.');
      _showAdOnLoad = true;
      loadAppOpenAd();
      return;
    }

    debugPrint('Showing AppOpenAd...');
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        isShowingAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAd dismissed');
        isShowingAd = false;
        _lastAdDismissedTime = DateTime.now();
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
