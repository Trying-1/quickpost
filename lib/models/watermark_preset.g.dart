// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watermark_preset.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatermarkPresetAdapter extends TypeAdapter<WatermarkPreset> {
  @override
  final int typeId = 20;

  @override
  WatermarkPreset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatermarkPreset(
      id: fields[0] as String,
      name: fields[1] as String,
      watermarkType: fields[2] as String,
      fullScreen: fields[3] as bool,
      bgColor: fields[4] as String,
      showBox: fields[5] as bool,
      boxColor: fields[6] as String,
      boxOpacity: fields[7] as double,
      boxRadius: fields[8] as double,
      watermarkX: fields[9] as double,
      watermarkY: fields[10] as double,
      fontSize: fields[11] as double,
      iconSize: fields[12] as double,
      textColor: fields[13] as String,
      accentColor: fields[14] as String,
      username: fields[15] as String,
      handle: fields[16] as String,
      fontFamily: fields[17] as String,
      handleFontFamily: fields[36] as String?,
      profileImagePath: fields[18] as String?,
      showStoryRing: fields[19] as bool,
      isVerified: fields[20] as bool,
      showUsernameShadow: fields[21] as bool,
      usernameShadowColor: fields[22] as String,
      usernameShadowBlur: fields[23] as double,
      showHandleShadow: fields[24] as bool,
      handleShadowColor: fields[25] as String,
      handleShadowBlur: fields[26] as double,
      showIconShadow: fields[27] as bool,
      iconShadowColor: fields[28] as String,
      iconShadowBlur: fields[29] as double,
      usernameShadowOffsetX: fields[30] as double,
      usernameShadowOffsetY: fields[31] as double,
      handleShadowOffsetX: fields[32] as double,
      handleShadowOffsetY: fields[33] as double,
      iconShadowOffsetX: fields[34] as double,
      iconShadowOffsetY: fields[35] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WatermarkPreset obj) {
    writer
      ..writeByte(37)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.watermarkType)
      ..writeByte(3)
      ..write(obj.fullScreen)
      ..writeByte(4)
      ..write(obj.bgColor)
      ..writeByte(5)
      ..write(obj.showBox)
      ..writeByte(6)
      ..write(obj.boxColor)
      ..writeByte(7)
      ..write(obj.boxOpacity)
      ..writeByte(8)
      ..write(obj.boxRadius)
      ..writeByte(9)
      ..write(obj.watermarkX)
      ..writeByte(10)
      ..write(obj.watermarkY)
      ..writeByte(11)
      ..write(obj.fontSize)
      ..writeByte(12)
      ..write(obj.iconSize)
      ..writeByte(13)
      ..write(obj.textColor)
      ..writeByte(14)
      ..write(obj.accentColor)
      ..writeByte(15)
      ..write(obj.username)
      ..writeByte(16)
      ..write(obj.handle)
      ..writeByte(17)
      ..write(obj.fontFamily)
      ..writeByte(36)
      ..write(obj.handleFontFamily)
      ..writeByte(18)
      ..write(obj.profileImagePath)
      ..writeByte(19)
      ..write(obj.showStoryRing)
      ..writeByte(20)
      ..write(obj.isVerified)
      ..writeByte(21)
      ..write(obj.showUsernameShadow)
      ..writeByte(22)
      ..write(obj.usernameShadowColor)
      ..writeByte(23)
      ..write(obj.usernameShadowBlur)
      ..writeByte(24)
      ..write(obj.showHandleShadow)
      ..writeByte(25)
      ..write(obj.handleShadowColor)
      ..writeByte(26)
      ..write(obj.handleShadowBlur)
      ..writeByte(27)
      ..write(obj.showIconShadow)
      ..writeByte(28)
      ..write(obj.iconShadowColor)
      ..writeByte(29)
      ..write(obj.iconShadowBlur)
      ..writeByte(30)
      ..write(obj.usernameShadowOffsetX)
      ..writeByte(31)
      ..write(obj.usernameShadowOffsetY)
      ..writeByte(32)
      ..write(obj.handleShadowOffsetX)
      ..writeByte(33)
      ..write(obj.handleShadowOffsetY)
      ..writeByte(34)
      ..write(obj.iconShadowOffsetX)
      ..writeByte(35)
      ..write(obj.iconShadowOffsetY);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatermarkPresetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
