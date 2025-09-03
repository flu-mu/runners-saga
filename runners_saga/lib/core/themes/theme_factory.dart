import 'package:flutter/material.dart';
import 'theme_config.dart';
import 'midnight_trail_theme.dart';
import 'sunset_runner_theme.dart';
import 'forest_explorer_theme.dart';
import 'ocean_breeze_theme.dart';

/// Theme factory that creates the appropriate theme based on configuration
class ThemeFactory {
  /// Get the current theme based on the active theme configuration
  static ThemeData getCurrentTheme() {
    switch (ThemeConfig.activeTheme) {
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
        };
      case ThemeType.sunsetRunner:
        return {
          'primary': SunsetRunnerTheme.primary,
          'secondary': SunsetRunnerTheme.secondary,
          'accent': SunsetRunnerTheme.accent,
          'background': SunsetRunnerTheme.background,
          'surface': SunsetRunnerTheme.surface,
        };
      case ThemeType.forestExplorer:
        return {
          'primary': ForestExplorerTheme.primary,
          'secondary': ForestExplorerTheme.secondary,
          'accent': ForestExplorerTheme.accent,
          'background': ForestExplorerTheme.background,
          'surface': ForestExplorerTheme.surface,
        };
      case ThemeType.oceanBreeze:
        return {
          'primary': OceanBreezeTheme.primary,
          'secondary': OceanBreezeTheme.secondary,
          'accent': OceanBreezeTheme.accent,
          'background': OceanBreezeTheme.background,
          'surface': OceanBreezeTheme.surface,
        };
    }
  }
}

