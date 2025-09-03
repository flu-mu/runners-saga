import 'package:flutter/material.dart';
import '../themes/theme_factory.dart';

// Legacy color constants for backward compatibility
// These will be replaced by the theme system
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

/// Create the dark theme using the theme factory
ThemeData createDarkTheme() {
  return ThemeFactory.getCurrentTheme();
}

/// Create the light theme using the theme factory
/// Note: Currently all themes are dark themes, but this can be extended
ThemeData createLightTheme() {
  return ThemeFactory.getCurrentTheme();
}


