import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';

/// AdMob Service
/// 
/// Manages ad loading, showing, and lifecycle

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();
  
  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  
  /// Initialize AdMob
  Future<void> initialize() async {
    if (!AdConfig.areAdsEnabled) {
      return;
    }
    
    if (_isInitialized) {
      return;
    }
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      
      // Log ad mode for debugging
      if (AdConfig.isDebugMode) {
        print('🧪 AdMob: Running in DEBUG mode - Using TEST ads');
        print('📱 Test Banner ID: ${AdConfig.getBannerAdUnitId()}');
        print('📱 Test Interstitial ID: ${AdConfig.getInterstitialAdUnitId()}');
      } else {
        print('💰 AdMob: Running in RELEASE mode - Using REAL ads');
      }
      
      // Pre-load first interstitial
      _loadInterstitialAd();
    } catch (e) {
      // Silent fail - ads not critical
    }
  }
  
  /// Check if ads are enabled
  bool get isEnabled => AdConfig.areAdsEnabled && _isInitialized;
  
  /// Create a banner ad (don't load it yet - let widget handle loading)
  BannerAd? createBannerAd(String screenName, {
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    if (!AdConfig.shouldShowBannerIn(screenName)) {
      return null;
    }
    
    final BannerAd bannerAd = BannerAd(
      adUnitId: AdConfig.getBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
    
    return bannerAd;
  }
  
  /// Load interstitial ad
  void _loadInterstitialAd() {
    if (!AdConfig.areAdsEnabled || !AdConfig.showInterstitialAfterExport) {
      return;
    }
    
    InterstitialAd.load(
      adUnitId: AdConfig.getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              
              // Load next ad immediately
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          // Retry immediately
          _loadInterstitialAd();
        },
      ),
    );
  }
  
  /// Show interstitial ad after export
  /// Frequency capping is handled by AdMob dashboard
  void showInterstitialAfterExport() {
    if (!AdConfig.areAdsEnabled || !AdConfig.showInterstitialAfterExport) {
      return;
    }
    
    // Show ad if ready (AdMob handles frequency capping)
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
      _isInterstitialAdReady = false;
    }
  }
  
  /// Dispose all ads
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
}
