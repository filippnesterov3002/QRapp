import 'package:hive/hive.dart';

part 'inventory_session.g.dart';

/// Результат инвентаризации для одного предмета в сессии
@HiveType(typeId: 3)
class InventoryResult {
  @HiveField(0)
  final String itemId;

  @HiveField(1)
  final String itemName;

  @HiveField(2)
  final String room; // Ожидаемое помещение

  @HiveField(3)
  final int expectedQty;

  @HiveField(4)
  int? actualQty;

  @HiveField(5)
  String status; // 'pending' | 'found' | 'missing' | 'wrong_room'

  InventoryResult({
    required this.itemId,
    required this.itemName,
    required this.room,
    required this.expectedQty,
    this.actualQty,
    this.status = 'pending',
  });
}

/// Сессия инвентаризации
@HiveType(typeId: 2)
class InventorySession extends HiveObject {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final List<String> rooms; // Выбранные помещения

  @HiveField(3)
  final List<InventoryResult> results; // Результаты по каждому предмету

  @HiveField(4)
  String status; // 'in_progress' | 'completed'

  InventorySession({
    required this.sessionId,
    required this.date,
    required this.rooms,
    required this.results,
    this.status = 'in_progress',
  });
}
