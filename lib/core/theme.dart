import 'package:flutter/material.dart';

abstract final class Palette {
  static const teal = Color(0xFF006151),
      ink = Color(0xFF172B29),
      muted = Color(0xFF526560),
      canvas = Color(0xFFF5F7F8),
      line = Color(0xFFD9E2DF),
      tint = Color(0xFFE8F4F0),
      danger = Color(0xFFA12B2B),
      amber = Color(0xFF805400);
}

ThemeData appTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.teal,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'KantumruyPro',
    scaffoldBackgroundColor: dark ? scheme.surface : Palette.canvas,
  );
  final text = base.textTheme.copyWith(
    headlineLarge: const TextStyle(
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: const TextStyle(
      fontSize: 24,
      height: 1.33,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: const TextStyle(
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: const TextStyle(
      fontSize: 18,
      height: 1.44,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: const TextStyle(fontSize: 14, height: 1.57),
    labelLarge: const TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
    ),
    bodySmall: const TextStyle(fontSize: 12, height: 1.5),
  );
  return base.copyWith(
    textTheme: text.apply(
      fontFamily: 'KantumruyPro',
      bodyColor: dark ? scheme.onSurface : Palette.ink,
      displayColor: dark ? scheme.onSurface : Palette.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? scheme.surface : Palette.canvas,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        color: dark ? scheme.onSurface : Palette.ink,
        fontFamily: 'KantumruyPro',
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? scheme.surfaceContainer : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? scheme.outlineVariant : Palette.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainer : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF71857F)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'KantumruyPro',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? scheme.surface : Colors.white,
      indicatorColor: Palette.tint,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'KantumruyPro',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.teal,
    ),
  );
}
