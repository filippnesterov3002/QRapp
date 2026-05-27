import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '/router/routes.dart';
import '/theme/theme.dart';

class QR_Code_App extends StatelessWidget {
  final Widget home;
  const QR_Code_App({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(keys: ['isDarkMode']),
      builder: (context, box, _) {
        final isDark = box.get('isDarkMode', defaultValue: false) as bool;
        return MaterialApp(
          title: 'Inventory App',
          theme: getLightTheme(),
          darkTheme: getDarkTheme(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: home,
          routes: routes,
        );
      },
    );
  }
}
