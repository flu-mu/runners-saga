import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_factory.dart';
import '../../shared/providers/theme_providers.dart';

/// Widget for selecting themes in the settings
class ThemeSelectorWidget extends ConsumerWidget {
  const ThemeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APP THEME',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Current Theme: ${ThemeFactory.getThemeName(currentTheme)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                ThemeFactory.getSeasonalName(currentTheme),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ThemeFactory.getSeasonalDescription(currentTheme),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Available Themes:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              ...ThemeFactory.getAvailableThemes().map((themeType) {
                final isCurrentTheme = themeType == currentTheme;
                final themeColors = ThemeFactory.getThemeColors(themeType);
                
                return GestureDetector(
                  onTap: () {
                    themeNotifier.setTheme(themeType);
                    GlobalThemeProvider.setTheme(themeType);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentTheme 
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentTheme 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: isCurrentTheme ? 2 : 1,
                      ),
                    ),
                    child: Row(
                    children: [
                      // Color preview
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: themeColors['primary'],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeColors['secondary']!,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: themeColors['accent'],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ThemeFactory.getThemeName(themeType),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: isCurrentTheme ? FontWeight.w600 : FontWeight.w500,
                                color: isCurrentTheme 
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            Text(
                              ThemeFactory.getSeasonalName(themeType),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: themeColors['primary'],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              ThemeFactory.getSeasonalDescription(themeType),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (isCurrentTheme)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }
}

