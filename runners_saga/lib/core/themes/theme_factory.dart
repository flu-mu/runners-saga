import 'package:flutter/material.dart';
import 'theme_config.dart';
import 'midnight_trail_theme.dart';
import 'sunset_runner_theme.dart';
import 'forest_explorer_theme.dart';
import 'ocean_breeze_theme.dart';
import '../../shared/providers/theme_providers.dart';

/// Theme factory that creates the appropriate theme based on configuration
class ThemeFactory {
  /// Get the current theme based on the active theme configuration
  static ThemeData getCurrentTheme() {
    return getTheme(GlobalThemeProvider.currentTheme);
  }
  
  /// Get theme data for a specific theme type
  static ThemeData getTheme(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return MidnightTrailTheme.createTheme();
      case ThemeType.sunsetRunner:
        return SunsetRunnerTheme.createTheme();
      case ThemeType.forestExplorer:
        return ForestExplorerTheme.createTheme();
      case ThemeType.oceanBreeze:
        return OceanBreezeTheme.createTheme();
    }
  }
  
  /// Get all available themes for theme selection
  static List<ThemeType> getAvailableThemes() {
    return ThemeType.values;
  }
  
  /// Get theme name for a specific theme type
  static String getThemeName(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return 'Midnight Trail';
      case ThemeType.sunsetRunner:
        return 'Sunset Runner';
      case ThemeType.forestExplorer:
        return 'Forest Explorer';
      case ThemeType.oceanBreeze:
        return 'Ocean Breeze';
    }
  }
  
  /// Get theme description for a specific theme type
  static String getThemeDescription(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return 'Dark, mysterious theme with electric aqua accents';
      case ThemeType.sunsetRunner:
        return 'Warm, energetic theme with orange and red tones';
      case ThemeType.forestExplorer:
        return 'Natural, earthy theme with green and brown tones';
      case ThemeType.oceanBreeze:
        return 'Cool, refreshing theme with blue and teal tones';
    }
  }
  
  /// Get theme colors for a specific theme type (for preview purposes)
  static Map<String, Color> getThemeColors(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return {
          'primary': MidnightTrailTheme.primary,
          'secondary': MidnightTrailTheme.secondary,
          'accent': MidnightTrailTheme.accent,
          'background': MidnightTrailTheme.background,
          'surface': MidnightTrailTheme.surface,
          'success': MidnightTrailTheme.success,
          'error': MidnightTrailTheme.error,
          'textHigh': MidnightTrailTheme.textHigh,
          'textMedium': MidnightTrailTheme.textMedium,
          'textLow': MidnightTrailTheme.textLow,
        };
      case ThemeType.sunsetRunner:
        return {
          'primary': SunsetRunnerTheme.primary,
          'secondary': SunsetRunnerTheme.secondary,
          'accent': SunsetRunnerTheme.accent,
          'background': SunsetRunnerTheme.background,
          'surface': SunsetRunnerTheme.surface,
          'success': SunsetRunnerTheme.success,
          'error': SunsetRunnerTheme.error,
          'textHigh': SunsetRunnerTheme.textHigh,
          'textMedium': SunsetRunnerTheme.textMedium,
          'textLow': SunsetRunnerTheme.textLow,
        };
      case ThemeType.forestExplorer:
        return {
          'primary': ForestExplorerTheme.primary,
          'secondary': ForestExplorerTheme.secondary,
          'accent': ForestExplorerTheme.accent,
          'background': ForestExplorerTheme.background,
          'surface': ForestExplorerTheme.surface,
          'success': ForestExplorerTheme.success,
          'error': ForestExplorerTheme.error,
          'textHigh': ForestExplorerTheme.textHigh,
          'textMedium': ForestExplorerTheme.textMedium,
          'textLow': ForestExplorerTheme.textLow,
        };
      case ThemeType.oceanBreeze:
        return {
          'primary': OceanBreezeTheme.primary,
          'secondary': OceanBreezeTheme.secondary,
          'accent': OceanBreezeTheme.accent,
          'background': OceanBreezeTheme.background,
          'surface': OceanBreezeTheme.surface,
          'success': OceanBreezeTheme.success,
          'error': OceanBreezeTheme.error,
          'textHigh': OceanBreezeTheme.textHigh,
          'textMedium': OceanBreezeTheme.textMedium,
          'textLow': OceanBreezeTheme.textLow,
        };
    }
  }
  
  /// Get seasonal mapping for theme
  static String getSeasonalName(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return 'Winter';
      case ThemeType.sunsetRunner:
        return 'Autumn';
      case ThemeType.forestExplorer:
        return 'Spring';
      case ThemeType.oceanBreeze:
        return 'Summer';
    }
  }
  
  /// Get seasonal description
  static String getSeasonalDescription(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return 'Silent Nights - Cool blues and mysterious depths';
      case ThemeType.sunsetRunner:
        return 'Harvest Moon - Warm oranges and golden sunsets';
      case ThemeType.forestExplorer:
        return 'Hope Blooms - Fresh greens and new beginnings';
      case ThemeType.oceanBreeze:
        return 'Heat Wave - Bright teals and sunny skies';
    }
  }
}


