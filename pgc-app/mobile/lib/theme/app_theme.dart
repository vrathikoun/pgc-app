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

  // ── Couleurs par type de cours ─────────────────────────────────────────────
  // Ajouter un nouveau type ici suffit — tout le reste s'adapte automatiquement
  static const Map<String, Color> courseColors = {
    'grappling':  Color(0xFF1A6B4A),  // vert forêt
    'bjj':        Color(0xFF1A4A6B),  // bleu acier
    'wrestling':  Color(0xFF6B3A1A),  // orange brûlé
    'mma':        Color(0xFF6B1A1A),  // rouge sang
    'boxing':     Color(0xFF4A1A6B),  // violet
    'kickboxing': Color(0xFF6B5A1A),  // or foncé
    'muay_thai':  Color(0xFF1A5A6B),  // bleu-vert
    'other':      Color(0xFF2A2A3A),  // gris neutre
  };

  static Color forCourseType(String type) =>
      courseColors[type] ?? courseColors['other']!;

  // ── Couleurs de ceinture BJJ ───────────────────────────────────────────────
  static const Map<String, Color> beltColors = {
    'white':        Color(0xFFEEEEEE),
    'blue':         Color(0xFF1565C0),
    'purple':       Color(0xFF7B1FA2),
    'brown':        Color(0xFF5D4037),
    'black':        Color(0xFF212121),
    'beginner':     Color(0xFF9E9E9E),
    'intermediate': Color(0xFF1976D2),
    'advanced':     Color(0xFFD32F2F),
    'elite':        Color(0xFFFFD700),
  };

  static Color forBelt(String? belt) =>
      beltColors[belt] ?? beltColors['white']!;
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