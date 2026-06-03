import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPink = Color(0xFFFC69C3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color burntOrange = Color(0xFFE06052);
  static const Color peach = Color(0xFFFFB6A3);
  static const Color darkRed = Color(0xFF140000);

  static const Color lightPeach = Color(
    0xFFF6B7A6,
  ); // approx from splash button

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryPink,
      scaffoldBackgroundColor: white,
      colorScheme: const ColorScheme.light(
        primary: primaryPink,
        secondary: burntOrange,
        surface: white,
        onSurface: darkRed,
        error: burntOrange,
      ),
      fontFamily:
          'Muli', // Generic fallback, you should add a real font via pubspec
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkRed),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPeach,
          foregroundColor: darkRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
