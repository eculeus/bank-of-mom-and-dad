import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand palette — bright, airy, modern.
const kBrandIndigo = Color(0xFF6366F1);
const kBrandViolet = Color(0xFF8B5CF6);
const kBrandInk = Color(0xFF1E1B39); // near-black indigo for text
const kBrandBg = Color(0xFFF6F7FD); // airy cool near-white
const kMoneyUp = Color(0xFF12B76A); // deposits
const kMoneyDown = Color(0xFFF04438); // deductions

const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kBrandIndigo, kBrandViolet],
);

const kidColors = [
  Color(0xFF7C4DFF), // purple
  Color(0xFF00BFA5), // teal
  Color(0xFFFF6D00), // orange
  Color(0xFFEC4899), // pink
  Color(0xFF2979FF), // blue
  Color(0xFF00C853), // green
];

ThemeData buildBankTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandIndigo,
    brightness: Brightness.light,
  ).copyWith(
    primary: kBrandIndigo,
    secondary: kBrandViolet,
    surface: Colors.white,
    onSurface: kBrandInk,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: kBrandInk,
    displayColor: kBrandInk,
  );
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: kBrandBg,
    appBarTheme: AppBarTheme(
      backgroundColor: kBrandBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kBrandInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
          color: kBrandInk, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: kBrandIndigo.withValues(alpha: 0.22),
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE9EBF6), thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEEF0FB),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kBrandIndigo, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrandIndigo,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        elevation: 2,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14))),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kBrandIndigo,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
