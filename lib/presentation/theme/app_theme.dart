import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color midnightBlue = Color(0xFF001F3F);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color ivoryWhite = Color(0xFFFFFFF0);
  static const Color errorRed = Color(0xFFB00020);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: midnightBlue,
        primary: midnightBlue,
        secondary: goldAccent,
        surface: Colors.white,
        error: errorRed,
      ),
      scaffoldBackgroundColor: ivoryWhite,
      textTheme: GoogleFonts.merriweatherTextTheme().copyWith(
        displayLarge: GoogleFonts.merriweather(
          color: midnightBlue,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        bodyLarge: GoogleFonts.openSans(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: midnightBlue,
        foregroundColor: ivoryWhite,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: midnightBlue,
          foregroundColor: goldAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
