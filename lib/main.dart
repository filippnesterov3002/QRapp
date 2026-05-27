import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/items.dart';
import 'models/inventory_session.dart';
import 'models/user.dart';
import 'models/changelog.dart';
import 'services/auth_service.dart';
import 'QR_Code_App.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/setup_screen.dart';
import 'features/home/home_screen.dart';
void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Инициализация русской локали для форматирования дат
  await initializeDateFormatting('ru', null);

  // Инициализация Hive
  await Hive.initFlutter();

  // Регистрация адаптеров
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(LocationAdapter());
  Hive.registerAdapter(InventoryResultAdapter());
  Hive.registerAdapter(InventorySessionAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(ChangeLogAdapter());

  // Открываем ящики
  await Hive.openBox<Item>('items');
  await Hive.openBox<InventorySession>('sessions');
  await Hive.openBox('settings');
  await Hive.openBox<User>('users_box');
  await Hive.openBox<ChangeLog>('changelog_box');

  // Загружаем сессию текущего пользователя
  await AuthService.instance.init();

  // Определяем стартовый экран
  final Widget home;
  final auth = AuthService.instance;
  if (!auth.hasUsers) {
    home = const SetupScreen();
  } else if (auth.isLoggedIn) {
    home = const HomePage();
  } else {
    home = const LoginScreen();
  }

  FlutterNativeSplash.remove();
  runApp(QR_Code_App(home: home));
}
