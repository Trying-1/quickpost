class AnimePostPreset {
  final String id;
  final String name;

  // Watermark parameters
  final String watermarkType;
  final bool fullScreen;
  final String bgColor;
  final bool showBox;
  final String boxColor;
  final double boxOpacity;
  final double boxRadius;
  final double watermarkX;
  final double watermarkY;
  final double fontSize;
  final double iconSize;
  final String textColor;
  final String accentColor;
  final String username;
  final String handle;
  final String fontFamily;
  final String? handleFontFamily;
  String? profileImagePath;
  String? bgImagePath;
  String? selectedImagePath;
  final bool showStoryRing;
  final bool isCustomRingColor;
  final String storyRingColor;
  final double storyRingWidth;
  final bool isVerified;
  final String verifiedBadgeColor;
  final String verifiedBadgeAttachTo;
  final double watermarkScale;
  final double usernameSize;
  final double handleSize;
  final double bgBrightness;
  final double bgSaturation;
  final double bgBlur;
  final double videoRadius;
  final double videoBorderWidth;
  final String videoBorderColor;
  final double videoScale;
  final double videoX;
  final double videoY;
  final double usernameOpacity;
  final double handleOpacity;
  final bool showUsernameShadow;
  final String usernameShadowColor;
  final double usernameShadowBlur;
  final double usernameShadowOffsetX;
  final double usernameShadowOffsetY;
  final bool showHandleShadow;
  final String handleShadowColor;
  final double handleShadowBlur;
  final double handleShadowOffsetX;
  final double handleShadowOffsetY;
  final bool showIconShadow;
  final String iconShadowColor;
  final double iconShadowBlur;
  final double iconShadowOffsetX;
  final double iconShadowOffsetY;
  final bool showVideoShadow;
  final String videoShadowColor;
  final double videoShadowBlur;
  final double videoShadowSpread;
  final double videoShadowOffsetX;
  final double videoShadowOffsetY;

  // Wire Watermark Specifics
  final double wireRadius;
  final double wireWidth;
  final String wireColor;
  final bool wireCutout;
  final bool wireCutoutDots;
  final double wireInset;
  final String wireTextPosition;
  final double wireGap;

  // Mask Settings
  final int maskType;
  final double maskOpacity;
  final double maskStart;
  final double maskEnd;
  final String maskColor;

  // Overlays & Patches
  final List<Map<String, dynamic>> patches;
  final List<Map<String, dynamic>> textOverlays;
  final List<Map<String, dynamic>> imageOverlays;
  final List<Map<String, dynamic>> customFonts;

  AnimePostPreset({
    required this.id,
    required this.name,
    this.watermarkType = 'profile_vertical',
    this.fullScreen = true,
    this.bgColor = '#FFFFFF',
    this.showBox = false,
    this.boxColor = '#000000',
    this.boxOpacity = 0.3,
    this.boxRadius = 12.0,
    this.watermarkX = 0.5,
    this.watermarkY = 0.85,
    this.fontSize = 30.0,
    this.iconSize = 80.0,
    this.textColor = '#000000',
    this.accentColor = '#888888',
    this.username = 'Anime Recs',
    this.handle = '@app.quickpost',
    this.fontFamily = 'Metrophobic',
    this.handleFontFamily,
    this.profileImagePath,
    this.bgImagePath,
    this.selectedImagePath,
    this.showStoryRing = true,
    this.isCustomRingColor = false,
    this.storyRingColor = '#FF4081',
    this.storyRingWidth = 5.0,
    this.isVerified = true,
    this.verifiedBadgeColor = '#1DA1F2',
    this.verifiedBadgeAttachTo = 'handle',
    this.watermarkScale = 1.0,
    this.usernameSize = 36.0,
    this.handleSize = 30.0,
    this.bgBrightness = 1.0,
    this.bgSaturation = 1.0,
    this.bgBlur = 0.0,
    this.videoRadius = 0.0,
    this.videoBorderWidth = 0.0,
    this.videoBorderColor = '#000000',
    this.videoScale = 1.0,
    this.videoX = 0.5,
    this.videoY = 0.5,
    this.usernameOpacity = 1.0,
    this.handleOpacity = 1.0,
    this.showUsernameShadow = false,
    this.usernameShadowColor = '#000000',
    this.usernameShadowBlur = 4.0,
    this.usernameShadowOffsetX = 1.0,
    this.usernameShadowOffsetY = 1.0,
    this.showHandleShadow = false,
    this.handleShadowColor = '#000000',
    this.handleShadowBlur = 4.0,
    this.handleShadowOffsetX = 1.0,
    this.handleShadowOffsetY = 1.0,
    this.showIconShadow = false,
    this.iconShadowColor = '#000000',
    this.iconShadowBlur = 4.0,
    this.iconShadowOffsetX = 1.0,
    this.iconShadowOffsetY = 1.0,
    this.showVideoShadow = false,
    this.videoShadowColor = '#000000',
    this.videoShadowBlur = 10.0,
    this.videoShadowSpread = 0.0,
    this.videoShadowOffsetX = 0.0,
    this.videoShadowOffsetY = 0.0,
    this.wireRadius = 12.0,
    this.wireWidth = 1.5,
    this.wireColor = '#FFFFFF',
    this.wireCutout = true,
    this.wireCutoutDots = true,
    this.wireInset = 40.0,
    this.wireTextPosition = 'bottom',
    this.wireGap = 16.0,
    this.maskType = 0,
    this.maskOpacity = 0.5,
    this.maskStart = 0.0,
    this.maskEnd = 1.0,
    this.maskColor = '#000000',
    this.patches = const [],
    this.textOverlays = const [],
    this.imageOverlays = const [],
    this.customFonts = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'watermarkType': watermarkType,
      'fullScreen': fullScreen,
      'bgColor': bgColor,
      'showBox': showBox,
      'boxColor': boxColor,
      'boxOpacity': boxOpacity,
      'boxRadius': boxRadius,
      'watermarkX': watermarkX,
      'watermarkY': watermarkY,
      'fontSize': fontSize,
      'iconSize': iconSize,
      'textColor': textColor,
      'accentColor': accentColor,
      'username': username,
      'handle': handle,
      'fontFamily': fontFamily,
      'handleFontFamily': handleFontFamily,
      'profileImagePath': profileImagePath,
      'bgImagePath': bgImagePath,
      'selectedImagePath': selectedImagePath,
      'showStoryRing': showStoryRing,
      'isCustomRingColor': isCustomRingColor,
      'storyRingColor': storyRingColor,
      'storyRingWidth': storyRingWidth,
      'isVerified': isVerified,
      'verifiedBadgeColor': verifiedBadgeColor,
      'verifiedBadgeAttachTo': verifiedBadgeAttachTo,
      'watermarkScale': watermarkScale,
      'usernameSize': usernameSize,
      'handleSize': handleSize,
      'bgBrightness': bgBrightness,
      'bgSaturation': bgSaturation,
      'bgBlur': bgBlur,
      'videoRadius': videoRadius,
      'videoBorderWidth': videoBorderWidth,
      'videoBorderColor': videoBorderColor,
      'videoScale': videoScale,
      'videoX': videoX,
      'videoY': videoY,
      'usernameOpacity': usernameOpacity,
      'handleOpacity': handleOpacity,
      'showUsernameShadow': showUsernameShadow,
      'usernameShadowColor': usernameShadowColor,
      'usernameShadowBlur': usernameShadowBlur,
      'usernameShadowOffsetX': usernameShadowOffsetX,
      'usernameShadowOffsetY': usernameShadowOffsetY,
      'showHandleShadow': showHandleShadow,
      'handleShadowColor': handleShadowColor,
      'handleShadowBlur': handleShadowBlur,
      'handleShadowOffsetX': handleShadowOffsetX,
      'handleShadowOffsetY': handleShadowOffsetY,
      'showIconShadow': showIconShadow,
      'iconShadowColor': iconShadowColor,
      'iconShadowBlur': iconShadowBlur,
      'iconShadowOffsetX': iconShadowOffsetX,
      'iconShadowOffsetY': iconShadowOffsetY,
      'showVideoShadow': showVideoShadow,
      'videoShadowColor': videoShadowColor,
      'videoShadowBlur': videoShadowBlur,
      'videoShadowSpread': videoShadowSpread,
      'videoShadowOffsetX': videoShadowOffsetX,
      'videoShadowOffsetY': videoShadowOffsetY,
      'wireRadius': wireRadius,
      'wireWidth': wireWidth,
      'wireColor': wireColor,
      'wireCutout': wireCutout,
      'wireCutoutDots': wireCutoutDots,
      'wireInset': wireInset,
      'wireTextPosition': wireTextPosition,
      'wireGap': wireGap,
      'maskType': maskType,
      'maskOpacity': maskOpacity,
      'maskStart': maskStart,
      'maskEnd': maskEnd,
      'maskColor': maskColor,
      'patches': patches,
      'textOverlays': textOverlays,
      'imageOverlays': imageOverlays,
      'customFonts': customFonts,
    };
  }

  factory AnimePostPreset.fromMap(Map<String, dynamic> map) {
    return AnimePostPreset(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      watermarkType: map['watermarkType'] ?? 'profile_vertical',
      fullScreen: map['fullScreen'] ?? true,
      bgColor: map['bgColor'] ?? '#FFFFFF',
      showBox: map['showBox'] ?? false,
      boxColor: map['boxColor'] ?? '#000000',
      boxOpacity: (map['boxOpacity'] as num?)?.toDouble() ?? 0.3,
      boxRadius: (map['boxRadius'] as num?)?.toDouble() ?? 12.0,
      watermarkX: (map['watermarkX'] as num?)?.toDouble() ?? 0.5,
      watermarkY: (map['watermarkY'] as num?)?.toDouble() ?? 0.85,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 30.0,
      iconSize: (map['iconSize'] as num?)?.toDouble() ?? 80.0,
      textColor: map['textColor'] ?? '#000000',
      accentColor: map['accentColor'] ?? '#888888',
      username: map['username'] ?? 'Anime Recs',
      handle: map['handle'] ?? '@app.quickpost',
      fontFamily: map['fontFamily'] ?? 'Metrophobic',
      handleFontFamily: map['handleFontFamily'],
      profileImagePath: map['profileImagePath'],
      bgImagePath: map['bgImagePath'],
      selectedImagePath: map['selectedImagePath'],
      showStoryRing: map['showStoryRing'] ?? true,
      isCustomRingColor: map['isCustomRingColor'] ?? false,
      storyRingColor: map['storyRingColor'] ?? '#FF4081',
      storyRingWidth: (map['storyRingWidth'] as num?)?.toDouble() ?? 5.0,
      isVerified: map['isVerified'] ?? true,
      verifiedBadgeColor: map['verifiedBadgeColor'] ?? '#1DA1F2',
      verifiedBadgeAttachTo: map['verifiedBadgeAttachTo'] ?? 'handle',
      watermarkScale: (map['watermarkScale'] as num?)?.toDouble() ?? 1.0,
      usernameSize: (map['usernameSize'] as num?)?.toDouble() ?? 36.0,
      handleSize: (map['handleSize'] as num?)?.toDouble() ?? 30.0,
      bgBrightness: (map['bgBrightness'] as num?)?.toDouble() ?? 1.0,
      bgSaturation: (map['bgSaturation'] as num?)?.toDouble() ?? 1.0,
      bgBlur: (map['bgBlur'] as num?)?.toDouble() ?? 0.0,
      videoRadius: (map['videoRadius'] as num?)?.toDouble() ?? 0.0,
      videoBorderWidth: (map['videoBorderWidth'] as num?)?.toDouble() ?? 0.0,
      videoBorderColor: map['videoBorderColor'] ?? '#000000',
      videoScale: (map['videoScale'] as num?)?.toDouble() ?? 1.0,
      videoX: (map['videoX'] as num?)?.toDouble() ?? 0.5,
      videoY: (map['videoY'] as num?)?.toDouble() ?? 0.5,
      usernameOpacity: (map['usernameOpacity'] as num?)?.toDouble() ?? 1.0,
      handleOpacity: (map['handleOpacity'] as num?)?.toDouble() ?? 1.0,
      showUsernameShadow: map['showUsernameShadow'] ?? false,
      usernameShadowColor: map['usernameShadowColor'] ?? '#000000',
      usernameShadowBlur: (map['usernameShadowBlur'] as num?)?.toDouble() ?? 4.0,
      usernameShadowOffsetX: (map['usernameShadowOffsetX'] as num?)?.toDouble() ?? 1.0,
      usernameShadowOffsetY: (map['usernameShadowOffsetY'] as num?)?.toDouble() ?? 1.0,
      showHandleShadow: map['showHandleShadow'] ?? false,
      handleShadowColor: map['handleShadowColor'] ?? '#000000',
      handleShadowBlur: (map['handleShadowBlur'] as num?)?.toDouble() ?? 4.0,
      handleShadowOffsetX: (map['handleShadowOffsetX'] as num?)?.toDouble() ?? 1.0,
      handleShadowOffsetY: (map['handleShadowOffsetY'] as num?)?.toDouble() ?? 1.0,
      showIconShadow: map['showIconShadow'] ?? false,
      iconShadowColor: map['iconShadowColor'] ?? '#000000',
      iconShadowBlur: (map['iconShadowBlur'] as num?)?.toDouble() ?? 4.0,
      iconShadowOffsetX: (map['iconShadowOffsetX'] as num?)?.toDouble() ?? 1.0,
      iconShadowOffsetY: (map['iconShadowOffsetY'] as num?)?.toDouble() ?? 1.0,
      showVideoShadow: map['showVideoShadow'] ?? false,
      videoShadowColor: map['videoShadowColor'] ?? '#000000',
      videoShadowBlur: (map['videoShadowBlur'] as num?)?.toDouble() ?? 10.0,
      videoShadowSpread: (map['videoShadowSpread'] as num?)?.toDouble() ?? 0.0,
      videoShadowOffsetX: (map['videoShadowOffsetX'] as num?)?.toDouble() ?? 0.0,
      videoShadowOffsetY: (map['videoShadowOffsetY'] as num?)?.toDouble() ?? 0.0,
      wireRadius: (map['wireRadius'] as num?)?.toDouble() ?? 12.0,
      wireWidth: (map['wireWidth'] as num?)?.toDouble() ?? 1.5,
      wireColor: map['wireColor'] ?? '#FFFFFF',
      wireCutout: map['wireCutout'] ?? true,
      wireCutoutDots: map['wireCutoutDots'] ?? true,
      wireInset: (map['wireInset'] as num?)?.toDouble() ?? 40.0,
      wireTextPosition: map['wireTextPosition'] ?? 'bottom',
      wireGap: (map['wireGap'] as num?)?.toDouble() ?? 16.0,
      maskType: map['maskType'] as int? ?? 0,
      maskOpacity: (map['maskOpacity'] as num?)?.toDouble() ?? 0.5,
      maskStart: (map['maskStart'] as num?)?.toDouble() ?? 0.0,
      maskEnd: (map['maskEnd'] as num?)?.toDouble() ?? 1.0,
      maskColor: map['maskColor'] ?? '#000000',
      patches: map['patches'] != null
          ? List<Map<String, dynamic>>.from(
              (map['patches'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
          : const [],
      textOverlays: map['textOverlays'] != null
          ? List<Map<String, dynamic>>.from(
              (map['textOverlays'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
          : const [],
      imageOverlays: map['imageOverlays'] != null
          ? List<Map<String, dynamic>>.from(
              (map['imageOverlays'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
          : const [],
      customFonts: map['customFonts'] != null
          ? List<Map<String, dynamic>>.from(
              (map['customFonts'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
          : const [],
    );
  }
}
