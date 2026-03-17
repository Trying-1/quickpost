class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  Future<void> initialize() async {
    return;
  }

  bool get isEnabled => false;

  void showInterstitialAfterExport() {
    return;
  }

  void dispose() {
    return;
  }
}
