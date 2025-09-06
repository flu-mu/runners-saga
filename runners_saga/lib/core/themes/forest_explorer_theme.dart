import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Forest Explorer Theme - Natural, earthy theme with green and brown tones
class ForestExplorerTheme {
  // Color Palette
  static const Color primary = Color(0xFF00B894); // Emerald Green
  static const Color secondary = Color(0xFF6C5CE7); // Purple
  static const Color accent = Color(0xFFFDCB6E); // Golden Yellow
  static const Color success = Color(0xFF00B894); // Emerald Green
  
  // Background Colors
  static const Color background = Color(0xFF1A2E1A); // Dark Forest Green
  static const Color surface = Color(0xFF2D4A2D); // Surface Base
  static const Color surfaceElevated = Color(0xFF3A5A3A); // Surface Elevated
  static const Color card = Color(0xFF3A5A3A); // Surface Elevated
  
  // Text Colors
  static const Color textHigh = Color(0xFFF0FFF0); // Light Green-White
  static const Color textMedium = Color(0xFFC8E6C8); // Medium contrast text
  static const Color textLow = Color(0xFFA0C0A0); // Low contrast text
  
  // Additional Colors
  static const Color deepGreen = Color(0xFF2D5016);
  static const Color divider = Color(0xFF4A6A4A);
  static const Color error = Color(0xFFE17055); // Orange Red
  
  // Fonts
  static const String primaryFont = 'Inter';
  static const String headingFont = 'Poppins';
  
  /// Create the theme data
  static ThemeData createTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    
    final colorScheme = const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surfaceElevated,
      background: background,
      error: error,
      onPrimary: background,
      onSecondary: textHigh,
      onSurface: textHigh,
      onBackground: textHigh,
      onError: textHigh,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        color: textHigh,
        fontSize: 32,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: textHigh,
        fontSize: 28,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: textHigh,
        fontSize: 24,
      ),
      titleLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: textHigh,
        fontSize: 22,
      ),
      titleMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w500,
        color: textHigh,
        fontSize: 16,
      ),
      titleSmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w500,
        color: textMedium,
        fontSize: 14,
      ),
      bodyLarge: GoogleFonts.inter(
        color: textHigh,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.inter(
        color: textMedium,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodySmall: GoogleFonts.inter(
        color: textLow,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: textHigh,
        fontSize: 14,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        color: textMedium,
        fontSize: 12,
      ),
      labelSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        color: textLow,
        fontSize: 11,
      ),
    );

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textHigh,
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        margin: const EdgeInsets.all(8),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: textMedium),
        hintStyle: GoogleFonts.inter(color: textLow),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: textMedium,
        size: 24,
      ),
      
      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        textColor: textHigh,
        iconColor: textMedium,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      useMaterial3: true,
    );
  }
}











