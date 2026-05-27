import 'package:hive/hive.dart';

part 'user.g.dart';

/// Модель пользователя приложения
@HiveType(typeId: 4)
class User extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String login;

  @HiveField(2)
  String passwordHash;

  @HiveField(3)
  String resetCodeHash;

  @HiveField(4)
  String name;

  @HiveField(5)
  String company;

  @HiveField(6)
  String? imagePath;

  @HiveField(7)
  bool isAdmin;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  String position;

  User({
    required this.userId,
    required this.login,
    required this.passwordHash,
    required this.resetCodeHash,
    required this.name,
    required this.company,
    this.imagePath,
    required this.isAdmin,
    required this.createdAt,
    this.position = '',
  });
}
