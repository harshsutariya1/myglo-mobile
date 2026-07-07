import 'package:flutter/material.dart';

class AppTheme {
  // Core colors mapped to ColorScheme
  static const Color primaryPink = Color(0xFFFC69C3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color burntOrange = Color(0xFFE06052);
  static const Color peach = Color(0xFFFFB6A3);
  static const Color darkRed = Color(0xFF140000);
  static const Color lightPeach = Color(0xFFF6B7A6);

  static final ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryPink,
    onPrimary: white,
    secondary: burntOrange,
    onSecondary: white,
    tertiary: peach,
    onTertiary: darkRed,
    error: burntOrange,
    onError: white,
    surface: white,
    onSurface: darkRed,
    primaryContainer: lightPeach,
    onPrimaryContainer: darkRed,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: lightColorScheme.surface,
      fontFamily: 'Muli',
      appBarTheme: AppBarTheme(
        backgroundColor: lightColorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: lightColorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: lightColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Muli',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightColorScheme.primaryContainer,
          foregroundColor: lightColorScheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      iconTheme: IconThemeData(color: lightColorScheme.onSurface),
    );
  }
}

extension ThemeExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
