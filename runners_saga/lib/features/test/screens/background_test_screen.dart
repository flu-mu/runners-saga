import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../../../shared/providers/theme_providers.dart';
import '../../../core/themes/theme_config.dart';

class BackgroundTestScreen extends ConsumerWidget {
  const BackgroundTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    
    return Scaffold(
      body: CustomPaint(
        painter: SimpleBackgroundPainter(currentTheme),
        size: Size.infinite,
      ),
    );
  }
}

/// Simple background painter with just sky contours and one hill
class SimpleBackgroundPainter extends CustomPainter {
  final ThemeType themeType;

  SimpleBackgroundPainter(this.themeType);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Get base colors for the theme
    final skyColor = _getSkyBaseColor(themeType);
    final hillColor = _getHillBaseColor(themeType);

    // First, fill the entire screen with the darkest sky color to prevent any dark background
    paint.color = Color.fromARGB(
      255,
      (skyColor.red * 0.2).round().clamp(0, 255),
      (skyColor.green * 0.2).round().clamp(0, 255),
      (skyColor.blue * 0.2).round().clamp(0, 255),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw sky with 5 wavy contours - ONE color getting lighter going UP
    for (int i = 0; i < 5; i++) {
      final lightness = 0.2 + (i * 0.2); // Start at 20% lightness, increase by 20% each going UP
      final baseHeight = size.height * (0.8 - i * 0.15); // Start from bottom, go UP
      final amplitude = 30 + (i * 10);
      
      // Create lighter version of the SAME base color
      paint.color = Color.fromARGB(
        255,
        (skyColor.red * lightness).round().clamp(0, 255),
        (skyColor.green * lightness).round().clamp(0, 255),
        (skyColor.blue * lightness).round().clamp(0, 255),
      );
      
      final path = Path();
      path.moveTo(0, baseHeight);
      
      // Create smooth wavy contours
      for (double x = 0; x <= size.width; x += 1) {
        final progress = x / size.width;
        final wave = amplitude * sin(progress * 3.14159 * 1.2 + i * 0.4);
        final y = baseHeight + wave;
        path.lineTo(x, y);
      }
      
      // Cover full screen height
      path.lineTo(size.width, size.height); // Go to bottom of screen
      path.lineTo(0, size.height);
      path.close();
      
      canvas.drawPath(path, paint);
    }

    // Draw one organic hill in the foreground using the better method
    _drawOrganicHill(canvas, size, paint, hillColor);
  }

  /// Get base sky color for the theme
  Color _getSkyBaseColor(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return const Color(0xFFE6F3FF); // Light blue
      case ThemeType.sunsetRunner:
        return const Color(0xFFFFD700); // Gold
      case ThemeType.forestExplorer:
        return const Color(0xFF87CEEB); // Sky blue
      case ThemeType.oceanBreeze:
        return const Color(0xFFF9C846); // Golden yellow
    }
  }
  
  /// Get base hill color for the theme
  Color _getHillBaseColor(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return const Color(0xFF708090); // Slate gray
      case ThemeType.sunsetRunner:
        return const Color(0xFF8B4513); // Saddle brown
      case ThemeType.forestExplorer:
        return const Color(0xFF32CD32); // Lime green
      case ThemeType.oceanBreeze:
        return const Color(0xFF228B22); // Forest green
    }
  }

  /// Draw one organic hill using the better method from seasonal_background.dart
  void _drawOrganicHill(Canvas canvas, Size size, Paint paint, Color baseColor) {
    final baseHeight = size.height * 0.8; // Position hill lower for full-screen sky
    
    final path = Path();
    path.moveTo(0, baseHeight);
    
    // Define organic hill features
    final peaks = [0.2, 0.5, 0.8]; // Peak positions across the width
    final peakHeights = [60.0, 80.0, 50.0]; // Peak heights
    final valleys = [0.1, 0.4, 0.7]; // Valley positions
    final valleyDepths = [20.0, 30.0, 25.0]; // Valley depths
    
    for (double x = 0; x <= size.width; x += 2) {
      final progress = x / size.width;
      double y = baseHeight;
      
      // Add peaks
      for (int j = 0; j < peaks.length; j++) {
        final peakPos = peaks[j];
        final peakHeight = peakHeights[j];
        final distance = (progress - peakPos).abs();
        if (distance < 0.3) {
          final influence = (1 - (distance / 0.3)) * (1 - (distance / 0.3));
          y -= peakHeight * influence;
        }
      }
      
      // Add valleys
      for (int j = 0; j < valleys.length; j++) {
        final valleyPos = valleys[j];
        final valleyDepth = valleyDepths[j];
        final distance = (progress - valleyPos).abs();
        if (distance < 0.2) {
          final influence = (1 - (distance / 0.2)) * (1 - (distance / 0.2));
          y += valleyDepth * influence;
        }
      }
      
      // Add natural irregularity
      final irregularity = sin(progress * 3.14159 * 12) * 3;
      y += irregularity;
      
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    // Use solid color - no gradients
    paint.color = baseColor;
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! SimpleBackgroundPainter ||
        oldDelegate.themeType != themeType;
  }
}
