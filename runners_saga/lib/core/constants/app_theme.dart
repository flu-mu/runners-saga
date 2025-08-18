import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Midnight Trail palette
const Color kMidnightNavy = Color(0xFF0B1B2B);
const Color kRoyalPlum = Color(0xFF2A1E5C);
const Color kDeepTeal = Color(0xFF0E4C63);
const Color kElectricAqua = Color(0xFF18D2C4);
const Color kEmberCoral = Color(0xFFFF6B57);
const Color kMeadowGreen = Color(0xFF30C474);
const Color kTextHigh = Color(0xFFEAF2F6);
const Color kTextMid = Color(0xFFD1D5DB);
const Color kTextLow = Color(0xFF9CA3AF);
const Color kSurfaceBase = Color(0xFF101826);
const Color kSurfaceElev = Color(0xFF0E1420);

ThemeData createDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colorScheme = const ColorScheme.dark(
    primary: kElectricAqua,
    secondary: kRoyalPlum,
    surface: kSurfaceElev,
    background: kSurfaceBase,
    error: kEmberCoral,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.poppins(
      fontWeight: FontWeight.w700,
      color: kTextHigh,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      color: kTextHigh,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      color: kTextHigh,
    ),
    bodyLarge: GoogleFonts.inter(
      color: kTextHigh,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: GoogleFonts.inter(
      color: kTextMid,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextHigh),
  );

  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kSurfaceBase,
    colorScheme: colorScheme,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kElectricAqua,
        foregroundColor: kMidnightNavy,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kElectricAqua,
        side: const BorderSide(color: kElectricAqua, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurfaceElev,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    dividerColor: const Color(0xFF1C2433),
    useMaterial3: true,
  );
}

ThemeData createLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final colorScheme = const ColorScheme.light(
    primary: kDeepTeal,
    secondary: kRoyalPlum,
    surface: Colors.white,
    background: Color(0xFFF6F8FA),
    error: kEmberCoral,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.black),
    headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
    bodyLarge: GoogleFonts.inter(color: Colors.black87),
    bodyMedium: GoogleFonts.inter(color: Colors.black54),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
  );

  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: colorScheme,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kDeepTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kDeepTeal,
        side: const BorderSide(color: kDeepTeal, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    useMaterial3: true,
  );
}


