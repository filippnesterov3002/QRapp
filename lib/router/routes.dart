import 'package:flutter/material.dart';
import '../features/auth/login_screen.dart';
import '../features/history/global_history_screen.dart';
import '../features/auth/setup_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/change_password_screen.dart';
import '../features/home/home_screen.dart';
import '../features/inventory/new_item_screen.dart';
import '../features/inventory/new_location_screen.dart';
import '../features/inventory/choose_location_screen.dart';
import '../features/inventory/add_item_screen.dart';
import '../features/scanner/qr_scanner_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/export/data_export_screen.dart';
import '../features/export/data_exchange_screen.dart';
import '../features/users/users_screen.dart';

final routes = <String, WidgetBuilder>{
  '/setup':          (context) => const SetupScreen(),
  '/login':          (context) => const LoginScreen(),
  '/main_screen':    (context) => const HomePage(),
  '/inventory':      (context) => const HomePage(),
  '/profile':        (context) => const ProfileScreen(),
  '/new_pos':        (context) => const NewLocationScreen(),
  '/new_thing':      (context) => const NewItemScreen(),
  '/uploading_thing':(context) => const DataExportScreen(),
  '/data_exchange':  (context) => const DataExchangeScreen(),
  '/choose':         (context) => const ChooseLocationScreen(),
  '/qr_scanner':     (context) => const QrScannerScreen(),
  '/add_item':       (context) => const AddItemScreen(),
  '/change_password':(context) => const ChangePasswordScreen(),
  '/reset_password': (context) => const ResetPasswordScreen(),
  '/users':          (context) => const UsersScreen(),
  '/history':        (context) => const GlobalHistoryScreen(),
};
