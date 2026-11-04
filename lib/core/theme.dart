import 'package:flutter/material.dart';

/// Palette et thème centralisés.
///
/// Objectif : supprimer les dizaines de couleurs codées en dur dans les
/// écrans, et garantir des contrastes lisibles (texte foncé sur fond clair).
class AppColors {
  const AppColors._();

  static const Color vert = Color(0xFF2E7D32);
  static const Color vertFonce = Color(0xFF1B5E20);
  static const Color vertSurface = Color(0xFFE8F5E9);
  static const Color rouge = Color(0xFFC62828);
  static const Color rougeSurface = Color(0xFFFFEBEE);
  static const Color orange = Color(0xFFEF6C00);
  static const Color bleu = Color(0xFF1565C0);
  static const Color gris = Color(0xFF5F6368);
}

ThemeData construireTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.vert),
    useMaterial3: true,
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF7F9F7),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.vert,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFBFC8BF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.vert, width: 2),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.vert,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.vert,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.vert,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
