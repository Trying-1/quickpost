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
      videoY: fields[37] == null ? 0.5 : fields[37] as double,
      storyRingWidth: fields[38] == null ? 5.0 : fields[38] as double,
      storyRingColor: fields[39] == null ? '#FF4081' : fields[39] as String,
      isCustomRingColor: fields[40] == null ? false : fields[40] as bool,
      verifiedBadgeColor: fields[41] == null ? '#1DA1F2' : fields[41] as String,
      verifiedBadgeAttachTo:
          fields[42] == null ? 'handle' : fields[42] as String,
      watermarkScale: fields[43] == null ? 1.0 : fields[43] as double,
      usernameSize: fields[44] == null ? 36.0 : fields[44] as double,
      handleSize: fields[45] == null ? 30.0 : fields[45] as double,
      bgBrightness: fields[46] == null ? 1.0 : fields[46] as double,
      bgSaturation: fields[47] == null ? 1.0 : fields[47] as double,
      bgBlur: fields[48] == null ? 0.0 : fields[48] as double,
      videoRadius: fields[49] == null ? 0.0 : fields[49] as double,
      videoBorderWidth: fields[50] == null ? 0.0 : fields[50] as double,
      videoBorderColor: fields[51] == null ? '#000000' : fields[51] as String,
      videoScale: fields[52] == null ? 1.0 : fields[52] as double,
      usernameOpacity: fields[53] == null ? 1.0 : fields[53] as double,
      handleOpacity: fields[54] == null ? 1.0 : fields[54] as double,
      wireRadius: fields[55] == null ? 12.0 : fields[55] as double,
      wireWidth: fields[56] == null ? 1.5 : fields[56] as double,
      wireColor: fields[57] == null ? '#FFFFFF' : fields[57] as String,
      wireCutout: fields[58] == null ? true : fields[58] as bool,
      wireCutoutDots: fields[59] == null ? true : fields[59] as bool,
      wireInset: fields[60] == null ? 40.0 : fields[60] as double,
      wireTextPosition: fields[61] == null ? 'bottom' : fields[61] as String,
      wireGap: fields[62] == null ? 16.0 : fields[62] as double,
      videoX: fields[63] == null ? 0.5 : fields[63] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WatermarkPreset obj) {
    writer
      ..writeByte(64)
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
      ..write(obj.iconShadowOffsetY)
      ..writeByte(37)
      ..write(obj.videoY)
      ..writeByte(38)
      ..write(obj.storyRingWidth)
      ..writeByte(39)
      ..write(obj.storyRingColor)
      ..writeByte(40)
      ..write(obj.isCustomRingColor)
      ..writeByte(41)
      ..write(obj.verifiedBadgeColor)
      ..writeByte(42)
      ..write(obj.verifiedBadgeAttachTo)
      ..writeByte(43)
      ..write(obj.watermarkScale)
      ..writeByte(44)
      ..write(obj.usernameSize)
      ..writeByte(45)
      ..write(obj.handleSize)
      ..writeByte(46)
      ..write(obj.bgBrightness)
      ..writeByte(47)
      ..write(obj.bgSaturation)
      ..writeByte(48)
      ..write(obj.bgBlur)
      ..writeByte(49)
      ..write(obj.videoRadius)
      ..writeByte(50)
      ..write(obj.videoBorderWidth)
      ..writeByte(51)
      ..write(obj.videoBorderColor)
      ..writeByte(52)
      ..write(obj.videoScale)
      ..writeByte(53)
      ..write(obj.usernameOpacity)
      ..writeByte(54)
      ..write(obj.handleOpacity)
      ..writeByte(55)
      ..write(obj.wireRadius)
      ..writeByte(56)
      ..write(obj.wireWidth)
      ..writeByte(57)
      ..write(obj.wireColor)
      ..writeByte(58)
      ..write(obj.wireCutout)
      ..writeByte(59)
      ..write(obj.wireCutoutDots)
      ..writeByte(60)
      ..write(obj.wireInset)
      ..writeByte(61)
      ..write(obj.wireTextPosition)
      ..writeByte(62)
      ..write(obj.wireGap)
      ..writeByte(63)
      ..write(obj.videoX);
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
