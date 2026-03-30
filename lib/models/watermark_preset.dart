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
  });
}
