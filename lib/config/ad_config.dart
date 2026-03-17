/// AdMob Configuration
/// 
/// Central place to manage all ad settings
/// Easy enable/disable ads from here

class AdConfig {
  static const bool adsEnabled = false;

  static bool get areAdsEnabled => false;

  static bool shouldShowBannerIn(String screenName) {
    return false;
  }

  static String getBannerAdUnitId() {
    return '';
  }

  static String getInterstitialAdUnitId() {
    return '';
  }

  static bool get showInterstitialAfterExport => false;
}
