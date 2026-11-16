import 'package:flutter/material.dart';

class SalusColors {
  static const background = Color(0xFF070D18);
  static const surface = Color(0xFF0F1729);
  static const surfaceAlt = Color(0xFF152038);
  static const border = Color(0xFF223150);
  static const mint = Color(0xFF35D6A4);
  static const amber = Color(0xFFF4B860);
  static const red = Color(0xFFF87171);
  static const blue = Color(0xFF60A5FA);
  static const violet = Color(0xFFA78BFA);
  static const text = Color(0xFFE8F0FB);
  static const muted = Color(0xFF91A4C0);

  static Color band(String band) {
    switch (band.toUpperCase()) {
      case 'CRITICAL':
        return red;
      case 'HIGH':
        return amber;
      case 'MEDIUM':
        return blue;
      default:
        return mint;
    }
  }

  static Color sensitivity(String label) {
    switch (label.toUpperCase()) {
      case 'CRITICAL':
        return red;
      case 'HIGH':
        return amber;
      case 'MEDIUM':
        return blue;
      default:
        return mint;
    }
  }

  static Color action(String action) {
    switch (action) {
      case 'EXTERNAL_SHARE':
        return red;
      case 'FILE_DOWNLOADED':
      case 'FILE_COPIED':
        return amber;
      case 'SUSPECT_UPLOAD':
        return violet;
      default:
        return blue;
    }
  }
}

ThemeData buildSalusTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: SalusColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: SalusColors.mint,
      secondary: SalusColors.amber,
      surface: SalusColors.surface,
      error: SalusColors.red,
      onPrimary: SalusColors.background,
      onSurface: SalusColors.text,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: SalusColors.text, displayColor: SalusColors.text)
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          bodySmall: const TextStyle(fontSize: 12.5, height: 1.4),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
    cardTheme: const CardThemeData(
      color: SalusColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: SalusColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SalusColors.surfaceAlt,
      hintStyle: const TextStyle(color: SalusColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SalusColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SalusColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SalusColors.mint),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SalusColors.mint,
        foregroundColor: SalusColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SalusColors.text,
        side: const BorderSide(color: SalusColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: SalusColors.mint),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: SalusColors.surfaceAlt,
      side: const BorderSide(color: SalusColors.border),
      labelStyle: const TextStyle(color: SalusColors.text, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SalusColors.surfaceAlt,
      contentTextStyle: TextStyle(color: SalusColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: SalusColors.mint),
  );
}
