class AppConfig {
  /// Toggle to enable or disable overall app advertisements
  static const bool adsEnabled = false;

  /// Global switch to enable premium features or bypass paywalls for development
  static const bool premiumFeaturesEnabled = true;

  /// Show the onboarding flow even if it was previously seen
  static const bool alwaysShowOnboarding = false;

  /// Enable or disable in-app reviews and update prompts
  static const bool enableAppLifecycleServices = true;

  /// Force a specific background color as the default for new watermark canvases
  static const bool forceWhiteCanvasByDefault = true;

  /// Debug mode for extra logging and development tools
  static const bool debugMode = false;
  
  /// Global toggle for native watermark processing engine selection
  static const bool useModernVideoProcessor = true;

  /// Show the backup and restore (JSON import/export) buttons in the watermark presets tab
  static const bool showWatermarkBackupButtons = true;
}
