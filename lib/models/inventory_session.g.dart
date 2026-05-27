// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryResultAdapter extends TypeAdapter<InventoryResult> {
  @override
  final int typeId = 3;

  @override
  InventoryResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryResult(
      itemId: fields[0] as String,
      itemName: fields[1] as String,
      room: fields[2] as String,
      expectedQty: fields[3] as int,
      actualQty: fields[4] as int?,
      status: (fields[5] as String?) ?? 'pending',
    );
  }

  @override
  void write(BinaryWriter writer, InventoryResult obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.itemId)
      ..writeByte(1)
      ..write(obj.itemName)
      ..writeByte(2)
      ..write(obj.room)
      ..writeByte(3)
      ..write(obj.expectedQty)
      ..writeByte(4)
      ..write(obj.actualQty)
      ..writeByte(5)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InventorySessionAdapter extends TypeAdapter<InventorySession> {
  @override
  final int typeId = 2;

  @override
  InventorySession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventorySession(
      sessionId: fields[0] as String,
      date: fields[1] as DateTime,
      rooms: (fields[2] as List).cast<String>(),
      results: (fields[3] as List).cast<InventoryResult>(),
      status: (fields[4] as String?) ?? 'in_progress',
    );
  }

  @override
  void write(BinaryWriter writer, InventorySession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.rooms)
      ..writeByte(3)
      ..write(obj.results)
      ..writeByte(4)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventorySessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
