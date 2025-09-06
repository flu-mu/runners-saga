/// Theme configuration for the app
/// Change this value to switch between different themes
/// 
/// Available themes:
/// - ThemeType.midnightTrail (default)
/// - ThemeType.sunsetRunner
/// - ThemeType.forestExplorer
/// - ThemeType.oceanBreeze
enum ThemeType {
  midnightTrail,
  sunsetRunner,
  forestExplorer,
  oceanBreeze,
}

/// Current active theme - change this to switch themes
/// 
/// Available options:
/// - ThemeType.midnightTrail (default - dark with electric aqua)
/// - ThemeType.sunsetRunner (warm orange and red tones)
/// - ThemeType.forestExplorer (natural green and brown tones)
/// - ThemeType.oceanBreeze (cool blue and teal tones)
const ThemeType currentTheme = ThemeType.midnightTrail;

/// Theme configuration class
class ThemeConfig {
  static ThemeType get activeTheme => currentTheme;
  
  /// Get theme name for display
  static String get themeName {
    switch (currentTheme) {
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
  
  /// Get theme description
  static String get themeDescription {
    switch (currentTheme) {
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
}
