// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const AuditApp());
}

class AuditApp extends StatelessWidget {
  const AuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audit Commercial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C1917)),
        scaffoldBackgroundColor: const Color(0xFFF8F7F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1917),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1917),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
