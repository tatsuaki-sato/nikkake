import 'package:flutter/material.dart';

class AppColors {
  static const darkBackground = Color(0xFF0F0F14);
  static const darkSurface = Color(0xFF1A1A24);
  static const darkSurfaceElevated = Color(0xFF24243A);
  static const darkPrimary = Color(0xFF6C5CE7);
  static const darkPrimaryLight = Color(0xFFA29BFE);
  static const darkSecondary = Color(0xFF00B894);
  static const darkSecondaryLight = Color(0xFF55EFC4);
  static const darkAccent = Color(0xFFFDCB6E);
  static const darkAccentLight = Color(0xFFFFEAA7);
  static const darkTextPrimary = Color(0xFFF0F0F0);
  static const darkTextSecondary = Color(0xFFA0A0B0);
  static const darkSuccess = Color(0xFF55EFC4);
  static const darkWarning = Color(0xFFFFEAA7);
  static const darkError = Color(0xFFFF8A8A);
  static const darkBorder = Color(0x1AFFFFFF);

  static const lightBackground = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFF5F5F5);
  static const lightPrimary = Color(0xFF6C5CE7);
  static const lightPrimaryLight = Color(0xFFA29BFE);
  static const lightSecondary = Color(0xFF00B894);
  static const lightSecondaryLight = Color(0xFF55EFC4);
  static const lightAccent = Color(0xFFFDCB6E);
  static const lightAccentLight = Color(0xFFFFEAA7);
  static const lightTextPrimary = Color(0xFF2D3436);
  static const lightTextSecondary = Color(0xFF636E72);
  static const lightSuccess = Color(0xFF00B894);
  static const lightWarning = Color(0xFFFDCB6E);
  static const lightError = Color(0xFFD63031);
  static const lightBorder = Color(0x1A000000);
}

ThemeData getAppTheme(bool isDark) {
  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
    primaryColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onPrimary: Colors.white,
      secondary: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
      onSecondary: Colors.white,
      error: isDark ? AppColors.darkError : AppColors.lightError,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
