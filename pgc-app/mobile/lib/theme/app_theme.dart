import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFF0B0C10);
  static const Color background = bg;

  static const Color surface = Color(0xFF15161B);
  static const Color surface2 = Color(0xFF20222A);
  static const Color border = Color(0xFF30323D);

  static const Color gold = Color(0xFFD8B56D);
  static const Color darkGreen = Color(0xFF0B5D3B);
  static const Color green = Color(0xFF00D09C);

  static const Color text = Color(0xFFF7F4EA);
  static const Color muted = Color(0xFF8D92A0);
  static const Color danger = Color(0xFFFF5A5F);
}

class PgcTheme {
  static ThemeData dark() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.darkGreen,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
    );
  }
}