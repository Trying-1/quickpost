/// Domain model for standard platform video/image aspect ratio resolutions.
class AspectRatioPreset {
  final String title;
  final String platform;
  final String ratio;
  final int width;
  final int height;
  final String badge;

  const AspectRatioPreset({
    required this.title,
    required this.platform,
    required this.ratio,
    required this.width,
    required this.height,
    required this.badge,
  });

  String get resolutionLabel => '$width × $height';
  double get aspectRatioValue => width / height;

  static const List<AspectRatioPreset> defaultPresets = [
    AspectRatioPreset(
      title: 'Vertical Reels & Shorts',
      platform: 'Reels / Short Video Feeds',
      ratio: '9:16',
      width: 1080,
      height: 1920,
      badge: 'Most Popular',
    ),
    AspectRatioPreset(
      title: 'Social Portrait Feed',
      platform: 'Portrait Feed Posts',
      ratio: '4:5',
      width: 1080,
      height: 1350,
      badge: 'Feeds',
    ),
    AspectRatioPreset(
      title: 'Square Canvas',
      platform: 'Social / Carousel Square',
      ratio: '1:1',
      width: 1080,
      height: 1080,
      badge: 'Classic',
    ),
    AspectRatioPreset(
      title: 'Horizontal YouTube Master',
      platform: 'YouTube / Widescreen TV',
      ratio: '16:9',
      width: 1920,
      height: 1080,
      badge: 'Landscape',
    ),
    AspectRatioPreset(
      title: '2K QHD Vertical Master',
      platform: 'High-Res Vertical 1440p',
      ratio: '9:16 (2K)',
      width: 1440,
      height: 2560,
      badge: 'Ultra HD',
    ),
    AspectRatioPreset(
      title: '4K UHD Vertical Master',
      platform: 'Ultra 4K Studio Quality',
      ratio: '9:16 (4K)',
      width: 2160,
      height: 3840,
      badge: 'Pro 4K',
    ),
  ];
}

