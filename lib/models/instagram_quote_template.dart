import 'package:hive/hive.dart';

part 'instagram_quote_template.g.dart';

@HiveType(typeId: 2)
class InstagramQuoteTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  // Identity
  @HiveField(2)
  String displayName;

  @HiveField(3)
  String username;

  // Fonts (store family + optional weight/style keys)
  @HiveField(4)
  String? quoteFontFamily;

  @HiveField(5)
  String? authorFontFamily;

  @HiveField(6)
  String? displayNameFontFamily;

  @HiveField(7)
  String? handleFontFamily;

  // Colors
  @HiveField(8)
  int backgroundColorValue;

  @HiveField(9)
  int quoteColorValue;

  @HiveField(10)
  int authorColorValue;

  @HiveField(11)
  int displayNameColorValue;

  @HiveField(12)
  int usernameColorValue;

  // Effects
  @HiveField(13)
  bool enableQuoteShadow;

  @HiveField(14)
  bool enableAuthorShadow;

  @HiveField(15)
  bool enableQuoteGlow;

  @HiveField(16)
  bool enableAuthorGlow;

  @HiveField(17)
  int quoteShadowColorValue;

  @HiveField(18)
  int authorShadowColorValue;

  @HiveField(19)
  int quoteGlowColorValue;

  @HiveField(20)
  int authorGlowColorValue;

  @HiveField(21)
  double quoteGlowRadius;

  @HiveField(22)
  double authorGlowRadius;

  // Layout / positions
  @HiveField(23)
  int textAlignIndex; // 0:left,1:center,2:right

  @HiveField(24)
  double textPosX;

  @HiveField(25)
  double textPosY;

  @HiveField(26)
  double identityPosX;

  @HiveField(27)
  double identityPosY;

  // Typography tweaks
  @HiveField(28)
  double letterSpacing;

  @HiveField(29)
  double fontSizeMultiplier;

  // Aspect ratio preset index (0:4:5,1:1:1,2:9:16,3:16:9)
  @HiveField(30)
  int aspectIndex;

  InstagramQuoteTemplate({
    required this.id,
    required this.name,
    required this.displayName,
    required this.username,
    required this.quoteFontFamily,
    required this.authorFontFamily,
    required this.displayNameFontFamily,
    required this.handleFontFamily,
    required this.backgroundColorValue,
    required this.quoteColorValue,
    required this.authorColorValue,
    required this.displayNameColorValue,
    required this.usernameColorValue,
    required this.enableQuoteShadow,
    required this.enableAuthorShadow,
    required this.enableQuoteGlow,
    required this.enableAuthorGlow,
    required this.quoteShadowColorValue,
    required this.authorShadowColorValue,
    required this.quoteGlowColorValue,
    required this.authorGlowColorValue,
    required this.quoteGlowRadius,
    required this.authorGlowRadius,
    required this.textAlignIndex,
    required this.textPosX,
    required this.textPosY,
    required this.identityPosX,
    required this.identityPosY,
    required this.letterSpacing,
    required this.fontSizeMultiplier,
    required this.aspectIndex,
  });
}
