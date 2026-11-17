import 'package:flutter/material.dart';

class SalusColors {
  static const canvas = Color(0xFFF7F4EE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEFEBE3);
  static const surfaceSoft = Color(0xFFE8E3DA);

  static const ink = Color(0xFF332F2A);
  static const muted = Color(0xFF6B645B);
  static const mutedSoft = Color(0xFF8C857A);

  static const border = Color(0xFFD8D2C7);
  static const borderStrong = Color(0xFFBFB7A9);

  static const primary = Color(0xFFF5FF00);
  static const onPrimary = Color(0xFF332F2A);
  static const secondary = Color(0xFF0864E8);
  static const secondarySoft = Color(0xFFE7F0FF);
  static const onSecondary = Color(0xFFFFFFFF);
  static const selected = Color(0xFFFFFDE0);
  static const white = Color(0xFFFFFFFF);

  // Semantic aliases used across the app.
  static const background = canvas;
  static const text = ink;
  static const cobalt = secondary;
  static const cobaltSoft = secondarySoft;
  static const yellow = primary;
  static const onAccent = onPrimary;

  // Compatibility aliases.
  static const mint = secondary;
  static const blue = secondary;
  static const amber = primary;
  static const red = primary;
  static const violet = muted;

  static Color band(String band) {
    switch (band.toUpperCase()) {
      case 'CRITICAL':
        return primary;
      case 'HIGH':
        return primary;
      case 'MEDIUM':
        return secondary;
      default:
        return muted;
    }
  }

  static Color sensitivity(String label) {
    switch (label.toUpperCase()) {
      case 'CRITICAL':
        return primary;
      case 'HIGH':
        return primary;
      case 'MEDIUM':
        return secondary;
      default:
        return muted;
    }
  }

  static Color action(String action) {
    switch (action) {
      case 'EXTERNAL_SHARE':
        return ink;
      case 'FILE_DOWNLOADED':
      case 'FILE_COPIED':
      case 'SUSPECT_UPLOAD':
        return secondary;
      default:
        return muted;
    }
  }
}

ThemeData buildSalusTheme() {
  final base = ThemeData.light(useMaterial3: true);
  const family = 'Manrope';

  final textTheme = base.textTheme
      .apply(
        bodyColor: SalusColors.ink,
        displayColor: SalusColors.ink,
        fontFamily: family,
      )
      .copyWith(
        headlineMedium: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 30,
          height: 36 / 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineSmall: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 14,
          height: 22 / 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          color: SalusColors.muted,
          fontFamily: family,
          fontSize: 12,
          height: 18 / 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: const TextStyle(
          color: SalusColors.ink,
          fontFamily: family,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: const TextStyle(
          color: SalusColors.muted,
          fontFamily: family,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        labelSmall: const TextStyle(
          color: SalusColors.muted,
          fontFamily: family,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: SalusColors.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: SalusColors.primary,
      onPrimary: SalusColors.onPrimary,
      secondary: SalusColors.secondary,
      onSecondary: SalusColors.onSecondary,
      surface: SalusColors.surface,
      onSurface: SalusColors.ink,
      error: SalusColors.primary,
      onError: SalusColors.onPrimary,
      outline: SalusColors.border,
      outlineVariant: SalusColors.borderStrong,
    ),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    cardTheme: const CardThemeData(
      color: SalusColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: SalusColors.border,
    dividerTheme: const DividerThemeData(
      color: SalusColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SalusColors.surface,
      hintStyle: const TextStyle(color: SalusColors.mutedSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SalusColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SalusColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SalusColors.secondary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SalusColors.primary,
        foregroundColor: SalusColors.onPrimary,
        disabledBackgroundColor: SalusColors.surfaceSoft,
        disabledForegroundColor: SalusColors.mutedSoft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: SalusColors.ink.withValues(alpha: 0.18)),
        ),
        textStyle: const TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SalusColors.ink,
        backgroundColor: SalusColors.surface,
        side: const BorderSide(color: SalusColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SalusColors.secondary,
        textStyle: const TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: SalusColors.surfaceAlt,
      side: const BorderSide(color: SalusColors.border),
      labelStyle: const TextStyle(color: SalusColors.ink, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SalusColors.secondary,
      contentTextStyle: TextStyle(
        color: SalusColors.onSecondary,
        fontFamily: family,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SalusColors.secondary,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: SalusColors.ink,
      unselectedLabelColor: SalusColors.muted,
      indicatorColor: SalusColors.primary,
      dividerColor: SalusColors.border,
      labelStyle: TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: const WidgetStatePropertyAll(SalusColors.borderStrong),
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}
