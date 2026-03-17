// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instagram_quote_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstagramQuoteTemplateAdapter
    extends TypeAdapter<InstagramQuoteTemplate> {
  @override
  final int typeId = 2;

  @override
  InstagramQuoteTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InstagramQuoteTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      displayName: fields[2] as String,
      username: fields[3] as String,
      quoteFontFamily: fields[4] as String?,
      authorFontFamily: fields[5] as String?,
      displayNameFontFamily: fields[6] as String?,
      handleFontFamily: fields[7] as String?,
      backgroundColorValue: fields[8] as int,
      quoteColorValue: fields[9] as int,
      authorColorValue: fields[10] as int,
      displayNameColorValue: fields[11] as int,
      usernameColorValue: fields[12] as int,
      enableQuoteShadow: fields[13] as bool,
      enableAuthorShadow: fields[14] as bool,
      enableQuoteGlow: fields[15] as bool,
      enableAuthorGlow: fields[16] as bool,
      quoteShadowColorValue: fields[17] as int,
      authorShadowColorValue: fields[18] as int,
      quoteGlowColorValue: fields[19] as int,
      authorGlowColorValue: fields[20] as int,
      quoteGlowRadius: fields[21] as double,
      authorGlowRadius: fields[22] as double,
      textAlignIndex: fields[23] as int,
      textPosX: fields[24] as double,
      textPosY: fields[25] as double,
      identityPosX: fields[26] as double,
      identityPosY: fields[27] as double,
      letterSpacing: fields[28] as double,
      fontSizeMultiplier: fields[29] as double,
      aspectIndex: fields[30] as int,
    );
  }

  @override
  void write(BinaryWriter writer, InstagramQuoteTemplate obj) {
    writer
      ..writeByte(31)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.username)
      ..writeByte(4)
      ..write(obj.quoteFontFamily)
      ..writeByte(5)
      ..write(obj.authorFontFamily)
      ..writeByte(6)
      ..write(obj.displayNameFontFamily)
      ..writeByte(7)
      ..write(obj.handleFontFamily)
      ..writeByte(8)
      ..write(obj.backgroundColorValue)
      ..writeByte(9)
      ..write(obj.quoteColorValue)
      ..writeByte(10)
      ..write(obj.authorColorValue)
      ..writeByte(11)
      ..write(obj.displayNameColorValue)
      ..writeByte(12)
      ..write(obj.usernameColorValue)
      ..writeByte(13)
      ..write(obj.enableQuoteShadow)
      ..writeByte(14)
      ..write(obj.enableAuthorShadow)
      ..writeByte(15)
      ..write(obj.enableQuoteGlow)
      ..writeByte(16)
      ..write(obj.enableAuthorGlow)
      ..writeByte(17)
      ..write(obj.quoteShadowColorValue)
      ..writeByte(18)
      ..write(obj.authorShadowColorValue)
      ..writeByte(19)
      ..write(obj.quoteGlowColorValue)
      ..writeByte(20)
      ..write(obj.authorGlowColorValue)
      ..writeByte(21)
      ..write(obj.quoteGlowRadius)
      ..writeByte(22)
      ..write(obj.authorGlowRadius)
      ..writeByte(23)
      ..write(obj.textAlignIndex)
      ..writeByte(24)
      ..write(obj.textPosX)
      ..writeByte(25)
      ..write(obj.textPosY)
      ..writeByte(26)
      ..write(obj.identityPosX)
      ..writeByte(27)
      ..write(obj.identityPosY)
      ..writeByte(28)
      ..write(obj.letterSpacing)
      ..writeByte(29)
      ..write(obj.fontSizeMultiplier)
      ..writeByte(30)
      ..write(obj.aspectIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstagramQuoteTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
