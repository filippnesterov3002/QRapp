// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changelog.dart';

class ChangeLogAdapter extends TypeAdapter<ChangeLog> {
  @override
  final int typeId = 5;

  @override
  ChangeLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChangeLog(
      logId: fields[0] as String,
      itemId: fields[1] as String,
      itemName: fields[2] as String,
      userId: fields[3] as String,
      userName: fields[4] as String,
      changeType: fields[5] as String,
      changedField: fields[6] as String?,
      oldValue: fields[7] as String?,
      newValue: fields[8] as String?,
      source: fields[9] as String,
      changedAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChangeLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.logId)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.itemName)
      ..writeByte(3)
      ..write(obj.userId)
      ..writeByte(4)
      ..write(obj.userName)
      ..writeByte(5)
      ..write(obj.changeType)
      ..writeByte(6)
      ..write(obj.changedField)
      ..writeByte(7)
      ..write(obj.oldValue)
      ..writeByte(8)
      ..write(obj.newValue)
      ..writeByte(9)
      ..write(obj.source)
      ..writeByte(10)
      ..write(obj.changedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
