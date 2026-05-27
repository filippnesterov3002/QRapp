import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Сервис авторизации — синглтон.
/// Хранит сессию в SharedPreferences, пользователей в Hive box «users_box».
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _sessionKey = 'current_user_id';
  String? _currentUserId;

  Box<User> get _usersBox => Hive.box<User>('users_box');

  // ── Инициализация ──────────────────────────────────────────────────────────

  /// Вызывать при старте — загружает сохранённую сессию из SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_sessionKey);
    if (savedId != null) {
      final exists = _usersBox.values.any((u) => u.userId == savedId);
      _currentUserId = exists ? savedId : null;
    }
  }

  // ── Состояние ──────────────────────────────────────────────────────────────

  bool get hasUsers => _usersBox.isNotEmpty;
  bool get isLoggedIn => currentUser != null;

  User? get currentUser {
    if (_currentUserId == null) return null;
    for (final u in _usersBox.values) {
      if (u.userId == _currentUserId) return u;
    }
    return null;
  }

  // ── Хеширование SHA-256 ────────────────────────────────────────────────────

  static String hashPassword(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  // ── Создание пользователя ─────────────────────────────────────────────────

  Future<User> createUser({
    required String login,
    required String password,
    required String resetCode,
    required String name,
    required String company,
    String position = '',
    bool isAdmin = false,
  }) async {
    final userId = 'u_${DateTime.now().millisecondsSinceEpoch}';
    final user = User(
      userId: userId,
      login: login.trim().toLowerCase(),
      passwordHash: hashPassword(password),
      resetCodeHash: hashPassword(resetCode),
      name: name.trim(),
      company: company.trim(),
      position: position.trim(),
      isAdmin: isAdmin,
      createdAt: DateTime.now(),
    );
    await _usersBox.add(user);
    return user;
  }

  // ── Вход ──────────────────────────────────────────────────────────────────

  Future<bool> login(String login, String password) async {
    final hash = hashPassword(password);
    User? found;
    for (final u in _usersBox.values) {
      if (u.login == login.trim().toLowerCase() && u.passwordHash == hash) {
        found = u;
        break;
      }
    }
    if (found == null) return false;
    _currentUserId = found.userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, found.userId);
    return true;
  }

  // ── Выход ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // ── Сброс пароля ──────────────────────────────────────────────────────────

  /// Возвращает true если логин и код сброса верны и пароль обновлён.
  Future<bool> resetPassword({
    required String login,
    required String resetCode,
    required String newPassword,
  }) async {
    final codeHash = hashPassword(resetCode);
    for (final u in _usersBox.values) {
      if (u.login == login.trim().toLowerCase() &&
          u.resetCodeHash == codeHash) {
        u.passwordHash = hashPassword(newPassword);
        await u.save();
        return true;
      }
    }
    return false;
  }

  // ── Смена пароля (из профиля) ─────────────────────────────────────────────

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    if (user.passwordHash != hashPassword(currentPassword)) return false;
    user.passwordHash = hashPassword(newPassword);
    await user.save();
    return true;
  }

  // ── Обновление профиля текущего пользователя ──────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? position,
    String? company,
    String? imagePath,
    bool clearImage = false,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (name != null) user.name = name;
    if (position != null) user.position = position;
    if (company != null) user.company = company;
    if (clearImage) {
      user.imagePath = null;
    } else if (imagePath != null) {
      user.imagePath = imagePath;
    }
    await user.save();
  }

  // ── Управление пользователями (только администратор) ──────────────────────

  bool isLoginTaken(String login) {
    final l = login.trim().toLowerCase();
    return _usersBox.values.any((u) => u.login == l);
  }

  List<User> get allUsers => _usersBox.values.toList();

  int get adminCount => _usersBox.values.where((u) => u.isAdmin).length;

  Future<void> deleteUser(User user) async => user.delete();

  Future<void> updateUser(
    User user, {
    String? name,
    String? newPassword,
    String? newResetCode,
  }) async {
    if (name != null) user.name = name.trim();
    if (newPassword != null) user.passwordHash = hashPassword(newPassword);
    if (newResetCode != null) user.resetCodeHash = hashPassword(newResetCode);
    await user.save();
  }
}
