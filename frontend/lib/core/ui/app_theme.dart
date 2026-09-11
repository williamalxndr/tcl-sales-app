import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF16202A);
  static const muted = Color(0xFF5C6771);
  static const faint = Color(0xFF7C8791);
  static const navy = Color(0xFF1F5876);
  static const navyDark = Color(0xFF143D52);
  static const canvas = Color(0xFFF4F6F8);
  static const line = Color(0xFFDFE4E9);
  static const inputLine = Color(0xFFD6DCE2);
  static const softNavy = Color(0xFFEEF3F6);
}

ThemeData buildAppTheme() {
  final outlined = OutlineInputBorder(
    borderRadius: BorderRadius.circular(7),
    borderSide: const BorderSide(color: AppColors.inputLine),
  );
  return ThemeData(
    useMaterial3: true,
    focusColor: const Color(0x331F5876),
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      outline: AppColors.inputLine,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -.35,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
      hintStyle: const TextStyle(color: Color(0xFFA4ADB5)),
      enabledBorder: outlined,
      focusedBorder: outlined.copyWith(
        borderSide: const BorderSide(color: AppColors.navy),
      ),
      errorBorder: outlined.copyWith(
        borderSide: const BorderSide(color: Color(0xFFB64A3B)),
      ),
      focusedErrorBorder: outlined.copyWith(
        borderSide: const BorderSide(color: Color(0xFFB64A3B)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2B3640),
        minimumSize: const Size(0, 38),
        side: const BorderSide(color: AppColors.inputLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        focusColor: const Color(0x331F5876),
        minimumSize: const Size(44, 44),
      ),
    ),
  );
}
