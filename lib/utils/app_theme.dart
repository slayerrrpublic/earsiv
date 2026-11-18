import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFE31E24);
  static const Color accent = Color(0xFF2E7D52);
  static const Color error = Color(0xFFB00020);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textMain = Color(0xFF1C1C1E);
  static const Color textSub = Color(0xFF6E6E73);
  static const Color border = Color(0xFFE0E0E0);
  static const Color success = Color(0xFF2E7D52);
  static const Color warning = Color(0xFFF57C00);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          error: error,
          surface: surface,
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: error),
          ),
          labelStyle: const TextStyle(color: textSub, fontSize: 14),
          hintStyle: TextStyle(color: textSub.withOpacity(0.6), fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 1),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      );
}
