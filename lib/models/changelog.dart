import 'package:hive/hive.dart';

part 'changelog.g.dart';

@HiveType(typeId: 5)
class ChangeLog extends HiveObject {
  @HiveField(0)
  final String logId;

  @HiveField(1)
  final String itemId;

  @HiveField(2)
  final String itemName;

  @HiveField(3)
  final String userId;

  @HiveField(4)
  final String userName;

  @HiveField(5)
  final String changeType;

  @HiveField(6)
  final String? changedField;

  @HiveField(7)
  final String? oldValue;

  @HiveField(8)
  final String? newValue;

  @HiveField(9)
  final String source;

  @HiveField(10)
  final DateTime changedAt;

  ChangeLog({
    required this.logId,
    required this.itemId,
    required this.itemName,
    required this.userId,
    required this.userName,
    required this.changeType,
    this.changedField,
    this.oldValue,
    this.newValue,
    required this.source,
    required this.changedAt,
  });
}
