import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'controller.dart';
import 'home.dart';
import 'theme_controller.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = defaultTargetPlatform == TargetPlatform.macOS;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(create: (_) => AppThemeController()),
      ],
      child: Consumer<AppThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'PICKit2',
            themeMode: themeController.mode,
            theme: _buildTheme(Brightness.light, desktop),
            darkTheme: _buildTheme(Brightness.dark, desktop),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, bool desktop) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF277FE2), brightness: brightness);
    return ThemeData(
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: brightness == Brightness.dark ? const Color(0xFF0B1018) : const Color(0xFFF3F5F8),
      visualDensity: desktop ? VisualDensity.compact : VisualDensity.standard,
      dividerColor: colors.outlineVariant,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
      useMaterial3: true,
    );
  }
}
