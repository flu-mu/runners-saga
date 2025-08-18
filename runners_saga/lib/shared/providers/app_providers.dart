import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firebase_service.dart';
import '../../core/constants/app_theme.dart';

/// Provider for app theme management
class AppTheme {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;
  
  const AppTheme({
    required this.lightTheme,
    required this.darkTheme,
    this.themeMode = ThemeMode.system,
  });
  
  AppTheme copyWith({
    ThemeData? lightTheme,
    ThemeData? darkTheme,
    ThemeMode? themeMode,
  }) {
    return AppTheme(
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// Provider for app theme
final appThemeProvider = StateNotifierProvider<AppThemeNotifier, AppTheme>((ref) {
  return AppThemeNotifier();
});

/// Notifier for app theme changes
class AppThemeNotifier extends StateNotifier<AppTheme> {
  AppThemeNotifier() : super(_createDefaultTheme());
  
  static AppTheme _createDefaultTheme() {
    return AppTheme(
      lightTheme: _createLightTheme(),
      darkTheme: _createDarkTheme(),
      themeMode: ThemeMode.system,
    );
  }
  
  static ThemeData _createLightTheme() {
    return createLightTheme();
  }
  
  static ThemeData _createDarkTheme() {
    return createDarkTheme();
  }
  
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }
  
  void toggleTheme() {
    final newMode = state.themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    state = state.copyWith(themeMode: newMode);
  }
}

/// Provider for app state
final appStateProvider = StateProvider<AppState>((ref) {
  return AppState.initial;
});

/// App state enum
enum AppState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Provider for dark mode state
final isDarkModeProvider = StateProvider<bool>((ref) {
  return false; // Default to light mode
});
