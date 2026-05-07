import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import '../config/ad_config.dart';

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

  String get _interstitialAdUnitId => AdConfig.interstitialAdUnitId;
  String get _appOpenAdUnitId => AdConfig.appOpenAdUnitId;

  Future<void> initialize() async {
    if (!AdConfig.adsEnabled) {
      debugPrint('AdService: Ads are globally disabled in AdConfig.');
      return;
    }
    debugPrint('Initializing MobileAds...');
    await MobileAds.instance.initialize();
    loadInterstitialAd();
    loadAppOpenAd();
  }

  // Interstitial Ad
  void loadInterstitialAd() {
    if (!AdConfig.adsEnabled) return;
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
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('InterstitialAd dismissed');
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('InterstitialAd failed to show: $error');
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
    if (!AdConfig.adsEnabled) return;

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
    if (!AdConfig.adsEnabled) return;
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
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
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
    if (!AdConfig.adsEnabled) return;
    if (!_isAppOpenAdAvailable) {
      debugPrint('AppOpenAd not available (null or expired)');
      loadAppOpenAd();
      return;
    }

    debugPrint('Showing AppOpenAd...');
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAd dismissed');
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }
}
