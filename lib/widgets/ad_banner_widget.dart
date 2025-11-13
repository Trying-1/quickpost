import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// Reusable Banner Ad Widget
/// 
/// Usage: AdBannerWidget(screenName: 'post_maker')

class AdBannerWidget extends StatefulWidget {
  final String screenName;
  
  const AdBannerWidget({
    Key? key,
    required this.screenName,
  }) : super(key: key);
  
  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadAd();
  }
  
  void _loadAd() {
    final adService = AdService();
    
    if (!adService.isEnabled) {
      return;
    }
    
    _bannerAd = adService.createBannerAd(
      widget.screenName,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
        ad.dispose();
      },
    );
    
    if (_bannerAd == null) {
      return;
    }
    
    // Load the ad
    _bannerAd!.load();
  }
  
  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_bannerAd == null || !_isAdLoaded) {
      return const SizedBox.shrink(); // Return empty widget if no ad
    }
    
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
