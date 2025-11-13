// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_folder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioFolderAdapter extends TypeAdapter<AudioFolder> {
  @override
  final int typeId = 1;

  @override
  AudioFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioFolder(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      dateCreated: fields[3] as DateTime,
      colorValue: fields[4] as int,
      iconName: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AudioFolder obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.dateCreated)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.iconName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioFolderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
