import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kidColors = [
  Color(0xFF7C4DFF), // purple
  Color(0xFF00BFA5), // teal
  Color(0xFFFF6D00), // orange
  Color(0xFFD500F9), // magenta
  Color(0xFF2979FF), // blue
  Color(0xFF00C853), // green
];

ThemeData buildBankTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF5252),
      secondary: const Color(0xFF7C4DFF),
      surface: const Color(0xFFFFFDF7),
    ),
  );
  final textTheme = GoogleFonts.fredokaTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.fredoka(
        textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w700),
  );
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: const Color(0xFFFFFDF7),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFD50000),
      foregroundColor: Colors.white,
    ),
  );
}
