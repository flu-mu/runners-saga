import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/themes/theme_config.dart';

/// Provider for the current theme
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeType>((ref) {
  return ThemeNotifier();
});

/// Theme notifier that manages theme state
class ThemeNotifier extends StateNotifier<ThemeType> {
  ThemeNotifier() : super(ThemeConfig.activeTheme);

  /// Change the current theme
  void setTheme(ThemeType theme) {
    state = theme;
  }

  /// Get the current theme
  ThemeType get currentTheme => state;
}

/// Global theme provider for static access
class GlobalThemeProvider {
  static ThemeType _currentTheme = ThemeConfig.activeTheme;
  
  static ThemeType get currentTheme => _currentTheme;
  
  static void setTheme(ThemeType theme) {
    _currentTheme = theme;
  }
}
