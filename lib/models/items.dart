import 'package:hive/hive.dart';

part 'items.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final Location location;
  @HiveField(4)
  final int? quantity;
  @HiveField(5)
  final String? imagePath;
  @HiveField(6)
  final String? inventoryNumber;
  @HiveField(7)
  final String? responsiblePerson;
  @HiveField(8)
  final String? itemId; // Уникальный артикул в формате ITEM-001
  @HiveField(9)
  final String? category; // Ключ категории (furniture, tech, ...)
  @HiveField(10)
  final DateTime? createdAt; // Дата создания предмета
  @HiveField(11)
  final DateTime? updatedAt; // Дата последнего изменения
  Item({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    this.quantity,
    this.imagePath,
    this.inventoryNumber,
    this.responsiblePerson,
    this.itemId,
    this.category,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location.toJson(),
        'description': description,
        'quantity': quantity,
        'imagePath': imagePath,
        'inventoryNumber': inventoryNumber,
        'responsiblePerson': responsiblePerson,
        'itemId': itemId,
        'category': category,
      };
}

@HiveType(typeId: 1)
class Location extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String floor;

  @HiveField(2)
  final String room;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final String? description;

  Location({
    required this.id,
    required this.floor,
    required this.room,
    required this.type,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor': floor,
        'room': room,
        'type': type,
        'description': description,
      };
}
