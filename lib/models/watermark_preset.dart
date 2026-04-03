import 'package:hive/hive.dart';

part 'watermark_preset.g.dart';

@HiveType(typeId: 20)
class WatermarkPreset extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String watermarkType;

  @HiveField(3)
  bool fullScreen;

  @HiveField(4)
  String bgColor;

  @HiveField(5)
  bool showBox;

  @HiveField(6)
  String boxColor;

  @HiveField(7)
  double boxOpacity;

  @HiveField(8)
  double boxRadius;

  @HiveField(9)
  double watermarkX;

  @HiveField(10)
  double watermarkY;

  @HiveField(11)
  double fontSize;

  @HiveField(12)
  double iconSize;

  @HiveField(13)
  String textColor;

  @HiveField(14)
  String accentColor;

  @HiveField(15)
  String username;

  @HiveField(16)
  String handle;

  @HiveField(17)
  String fontFamily;

  @HiveField(36)
  String? handleFontFamily;

  @HiveField(18)
  String? profileImagePath;

  @HiveField(19)
  bool showStoryRing;

  @HiveField(20)
  bool isVerified;

  @HiveField(21)
  bool showUsernameShadow;
  @HiveField(22)
  String usernameShadowColor;
  @HiveField(23)
  double usernameShadowBlur;

  @HiveField(24)
  bool showHandleShadow;
  @HiveField(25)
  String handleShadowColor;
  @HiveField(26)
  double handleShadowBlur;

  @HiveField(27)
  bool showIconShadow;
  @HiveField(28)
  String iconShadowColor;
  @HiveField(29)
  double iconShadowBlur;

  @HiveField(30)
  double usernameShadowOffsetX;
  @HiveField(31)
  double usernameShadowOffsetY;

  @HiveField(32)
  double handleShadowOffsetX;
  @HiveField(33)
  double handleShadowOffsetY;

  @HiveField(34)
  double iconShadowOffsetX;
  @HiveField(35)
  double iconShadowOffsetY;

  @HiveField(37)
  double videoY;

  WatermarkPreset({
    required this.id,
    required this.name,
    this.watermarkType = 'profile',
    this.fullScreen = false,
    this.bgColor = '#000000',
    this.showBox = true,
    this.boxColor = '#000000',
    this.boxOpacity = 0.3,
    this.boxRadius = 12.0,
    this.watermarkX = 0.5,
    this.watermarkY = 0.8,
    this.fontSize = 36.0,
    this.iconSize = 80.0,
    this.textColor = '#FFFFFF',
    this.accentColor = '#AAAAAA',
    this.username = 'John Doe',
    this.handle = '@johndoe_arise',
    this.fontFamily = 'Metrophobic',
    this.handleFontFamily,
    this.profileImagePath,
    this.showStoryRing = false,
    this.isVerified = false,
    this.showUsernameShadow = false,
    this.usernameShadowColor = '#000000',
    this.usernameShadowBlur = 4.0,
    this.showHandleShadow = false,
    this.handleShadowColor = '#000000',
    this.handleShadowBlur = 4.0,
    this.showIconShadow = false,
    this.iconShadowColor = '#000000',
    this.iconShadowBlur = 4.0,
    this.usernameShadowOffsetX = 1.0,
    this.usernameShadowOffsetY = 1.0,
    this.handleShadowOffsetX = 1.0,
    this.handleShadowOffsetY = 1.0,
    this.iconShadowOffsetX = 1.0,
    this.iconShadowOffsetY = 1.0,
    this.videoY = 0.5,
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
      'showStoryRing': showStoryRing,
      'isVerified': isVerified,
      'showUsernameShadow': showUsernameShadow,
      'usernameShadowColor': usernameShadowColor,
      'usernameShadowBlur': usernameShadowBlur,
      'showHandleShadow': showHandleShadow,
      'handleShadowColor': handleShadowColor,
      'handleShadowBlur': handleShadowBlur,
      'showIconShadow': showIconShadow,
      'iconShadowColor': iconShadowColor,
      'iconShadowBlur': iconShadowBlur,
      'usernameShadowOffsetX': usernameShadowOffsetX,
      'usernameShadowOffsetY': usernameShadowOffsetY,
      'handleShadowOffsetX': handleShadowOffsetX,
      'handleShadowOffsetY': handleShadowOffsetY,
      'iconShadowOffsetX': iconShadowOffsetX,
      'iconShadowOffsetY': iconShadowOffsetY,
      'videoY': videoY,
    };
  }

  factory WatermarkPreset.fromMap(Map<String, dynamic> map) {
    return WatermarkPreset(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      watermarkType: map['watermarkType'] ?? 'profile',
      fullScreen: map['fullScreen'] ?? false,
      bgColor: map['bgColor'] ?? '#000000',
      showBox: map['showBox'] ?? true,
      boxColor: map['boxColor'] ?? '#000000',
      boxOpacity: (map['boxOpacity'] as num?)?.toDouble() ?? 0.3,
      boxRadius: (map['boxRadius'] as num?)?.toDouble() ?? 12.0,
      watermarkX: (map['watermarkX'] as num?)?.toDouble() ?? 0.5,
      watermarkY: (map['watermarkY'] as num?)?.toDouble() ?? 0.8,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 36.0,
      iconSize: (map['iconSize'] as num?)?.toDouble() ?? 80.0,
      textColor: map['textColor'] ?? '#FFFFFF',
      accentColor: map['accentColor'] ?? '#AAAAAA',
      username: map['username'] ?? '',
      handle: map['handle'] ?? '',
      fontFamily: map['fontFamily'] ?? 'Metrophobic',
      handleFontFamily: map['handleFontFamily'],
      profileImagePath: map['profileImagePath'],
      showStoryRing: map['showStoryRing'] ?? false,
      isVerified: map['isVerified'] ?? false,
      showUsernameShadow: map['showUsernameShadow'] ?? false,
      usernameShadowColor: map['usernameShadowColor'] ?? '#000000',
      usernameShadowBlur: (map['usernameShadowBlur'] as num?)?.toDouble() ?? 4.0,
      showHandleShadow: map['showHandleShadow'] ?? false,
      handleShadowColor: map['handleShadowColor'] ?? '#000000',
      handleShadowBlur: (map['handleShadowBlur'] as num?)?.toDouble() ?? 4.0,
      showIconShadow: map['showIconShadow'] ?? false,
      iconShadowColor: map['iconShadowColor'] ?? '#000000',
      iconShadowBlur: (map['iconShadowBlur'] as num?)?.toDouble() ?? 4.0,
      usernameShadowOffsetX: (map['usernameShadowOffsetX'] as num?)?.toDouble() ?? 1.0,
      usernameShadowOffsetY: (map['usernameShadowOffsetY'] as num?)?.toDouble() ?? 1.0,
      handleShadowOffsetX: (map['handleShadowOffsetX'] as num?)?.toDouble() ?? 1.0,
      handleShadowOffsetY: (map['handleShadowOffsetY'] as num?)?.toDouble() ?? 1.0,
      iconShadowOffsetX: (map['iconShadowOffsetX'] as num?)?.toDouble() ?? 1.0,
      iconShadowOffsetY: (map['iconShadowOffsetY'] as num?)?.toDouble() ?? 1.0,
      videoY: (map['videoY'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
