# Theme System Documentation

## Overview

The Runner's Saga app now includes a comprehensive theme system that allows you to easily switch between different visual themes. Each theme includes its own color palette, typography, and styling.

## Available Themes

### 1. Midnight Trail (Default)
- **Colors**: Dark navy background with electric aqua accents
- **Mood**: Dark, mysterious, futuristic
- **Primary**: Electric Aqua (#18D2C4)
- **Secondary**: Royal Plum (#2A1E5C)
- **Accent**: Ember Coral (#FF6B57)

### 2. Sunset Runner
- **Colors**: Warm red-brown background with vibrant orange accents
- **Mood**: Energetic, warm, sunset-inspired
- **Primary**: Vibrant Orange (#FF6B35)
- **Secondary**: Deep Red (#D63031)
- **Accent**: Golden Yellow (#FFD93D)

### 3. Forest Explorer
- **Colors**: Dark forest green background with emerald accents
- **Mood**: Natural, earthy, outdoor adventure
- **Primary**: Emerald Green (#00B894)
- **Secondary**: Purple (#6C5CE7)
- **Accent**: Golden Yellow (#FDCB6E)

### 4. Ocean Breeze
- **Colors**: Deep ocean blue background with bright teal accents
- **Mood**: Cool, refreshing, oceanic
- **Primary**: Bright Teal (#00CEC9)
- **Secondary**: Purple (#6C5CE7)
- **Accent**: Sky Blue (#74B9FF)

## How to Switch Themes

### Method 1: Edit Configuration File (Recommended)

1. Open `lib/core/themes/theme_config.dart`
2. Find the line: `const ThemeType currentTheme = ThemeType.midnightTrail;`
3. Change it to your desired theme:
   ```dart
   const ThemeType currentTheme = ThemeType.sunsetRunner; // or any other theme
   ```
4. Save the file and rebuild the app

### Method 2: View Theme Preview in Settings

1. Open the app and go to Settings
2. Scroll down to the "APP THEME" section
3. View all available themes with color previews
4. Note the theme name you want to use
5. Follow Method 1 to switch to that theme

## File Structure

```
lib/core/themes/
├── README.md                    # This documentation
├── theme_config.dart           # Theme configuration and selection
├── theme_factory.dart          # Theme factory for creating themes
├── theme_selector_widget.dart  # UI widget for theme selection
├── midnight_trail_theme.dart   # Midnight Trail theme
├── sunset_runner_theme.dart    # Sunset Runner theme
├── forest_explorer_theme.dart  # Forest Explorer theme
└── ocean_breeze_theme.dart     # Ocean Breeze theme
```

## Creating a New Theme

To create a new theme:

1. **Create a new theme file** (e.g., `my_custom_theme.dart`):
   ```dart
   import 'package:flutter/material.dart';
   import 'package:google_fonts/google_fonts.dart';

   class MyCustomTheme {
     // Define your color palette
     static const Color primary = Color(0xFF123456);
     static const Color secondary = Color(0xFF789ABC);
     // ... other colors

     static ThemeData createTheme() {
       // Create and return your theme
       // Follow the pattern from existing themes
     }
   }
   ```

2. **Add the theme to the enum** in `theme_config.dart`:
   ```dart
   enum ThemeType {
     midnightTrail,
     sunsetRunner,
     forestExplorer,
     oceanBreeze,
     myCustomTheme, // Add your new theme
   }
   ```

3. **Update the theme factory** in `theme_factory.dart`:
   ```dart
   static ThemeData getCurrentTheme() {
     switch (ThemeConfig.activeTheme) {
       // ... existing cases
       case ThemeType.myCustomTheme:
         return MyCustomTheme.createTheme();
     }
   }
   ```

4. **Add theme information** in `theme_factory.dart`:
   ```dart
   static String getThemeName(ThemeType themeType) {
     switch (themeType) {
       // ... existing cases
       case ThemeType.myCustomTheme:
         return 'My Custom Theme';
     }
   }
   ```

## Theme Components

Each theme includes:

- **Color Palette**: Primary, secondary, accent, background, surface colors
- **Typography**: Font families, weights, and sizes
- **Component Styling**: Buttons, cards, inputs, dividers, etc.
- **Material 3**: Full Material 3 design system support

## Best Practices

1. **Consistent Naming**: Use descriptive names for themes that reflect their mood/purpose
2. **Color Accessibility**: Ensure sufficient contrast ratios for text readability
3. **Component Consistency**: All themes should have the same component structure
4. **Testing**: Test each theme across different screens and components
5. **Documentation**: Document the mood and inspiration for each theme

## Future Enhancements

- **Runtime Theme Switching**: Allow users to switch themes without rebuilding
- **Custom Theme Creator**: UI for users to create their own themes
- **Theme Presets**: Seasonal or special event themes
- **Light Theme Variants**: Light versions of existing dark themes
- **Image Assets**: Theme-specific images and icons

## Troubleshooting

### Theme Not Applying
- Ensure you've rebuilt the app after changing `theme_config.dart`
- Check that the theme is properly imported in `theme_factory.dart`
- Verify the theme enum includes your new theme

### Colors Not Showing Correctly
- Check that all color constants are properly defined
- Ensure the theme's `createTheme()` method is called correctly
- Verify Material 3 compatibility

### Build Errors
- Make sure all theme files are properly imported
- Check for syntax errors in theme definitions
- Ensure all required dependencies are available

## Support

For questions or issues with the theme system, refer to the Flutter documentation on theming or create an issue in the project repository.











