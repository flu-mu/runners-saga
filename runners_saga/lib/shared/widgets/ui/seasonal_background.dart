import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/themes/theme_factory.dart';
import '../../../core/themes/theme_config.dart';
import '../../providers/theme_providers.dart';

/// Widget that provides seasonal background patterns based on the current theme
/// Maps themes to seasons: Midnight Trail = Winter, Sunset Runner = Autumn, 
/// Forest Explorer = Spring, Ocean Breeze = Summer
class SeasonalBackground extends ConsumerWidget {
  final Widget child;
  final bool showHeaderPattern;
  final double headerHeight;
  final EdgeInsets padding;

  const SeasonalBackground({
    super.key,
    required this.child,
    this.showHeaderPattern = true,
    this.headerHeight = 120.0,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final theme = ThemeFactory.getTheme(currentTheme);
    final season = _getSeasonFromTheme(currentTheme);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent, // Let our custom sky patterns show through
      ),
      child: Stack(
        children: [
          // Full-screen custom painted background
          Positioned.fill(
            child: CustomPaint(
              painter: SeasonalHeaderPainter(theme, season),
              size: Size.infinite,
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  /// Maps theme types to seasons
  Season _getSeasonFromTheme(ThemeType themeType) {
    switch (themeType) {
      case ThemeType.midnightTrail:
        return Season.winter;
      case ThemeType.sunsetRunner:
        return Season.autumn;
      case ThemeType.forestExplorer:
        return Season.spring;
      case ThemeType.oceanBreeze:
        return Season.summer;
    }
  }

  /// Creates background gradient based on season
  LinearGradient _getBackgroundGradient(ThemeData theme, Season season) {
    switch (season) {
      case Season.spring:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.3),
            theme.colorScheme.secondary.withValues(alpha: 0.2),
            theme.scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.4, 1.0],
        );
      case Season.summer:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.4),
            theme.colorScheme.primary.withValues(alpha: 0.3),
            theme.scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case Season.autumn:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.secondary.withValues(alpha: 0.4),
            theme.colorScheme.primary.withValues(alpha: 0.3),
            theme.scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.6, 1.0],
        );
      case Season.winter:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.2),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
            theme.scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.3, 1.0],
        );
    }
  }

}

/// Custom painter for seasonal header patterns
class SeasonalHeaderPainter extends CustomPainter {
  final ThemeData theme;
  final Season season;

  SeasonalHeaderPainter(this.theme, this.season);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Create layered contour patterns based on season
   //  JM removed for now _drawContourLayers(canvas, size, paint);
   // JM removed for now _drawSeasonalElements(canvas, size, paint);
  }

  void _drawContourLayers(Canvas canvas, Size size, Paint paint) {
    // Draw sky with 5 wavy contours (same color getting lighter)
    _drawSkyContours(canvas, size, paint);
    
    // Draw one simple hill in foreground
    _drawSimpleHill(canvas, size, paint);
  }
  
  /// Draw sky with 5 wavy contours - ONE color getting lighter going UP
  void _drawSkyContours(Canvas canvas, Size size, Paint paint) {
    // Use ONE base sky color and make it lighter for each contour (going UP)
    final baseColor = _getSkyBaseColor(season);
    
    // First fill the entire sky area with the darkest shade to prevent dark background
    paint.color = Color.fromARGB(
      255,
      (baseColor.red * 0.2).round().clamp(0, 255),
      (baseColor.green * 0.2).round().clamp(0, 255),
      (baseColor.blue * 0.2).round().clamp(0, 255),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.8), paint);
    
    // Draw 5 wavy contours, each getting lighter as we go UP
    for (int i = 0; i < 5; i++) {
      final lightness = 0.2 + (i * 0.2); // Start at 20% lightness, increase by 20% each going UP
      final baseHeight = size.height * (0.8 - i * 0.15); // Start from bottom, go UP
      final amplitude = 20 + (i * 8);
      
      // Create lighter version of the SAME base color
      paint.color = Color.fromARGB(
        255,
        (baseColor.red * lightness).round().clamp(0, 255),
        (baseColor.green * lightness).round().clamp(0, 255),
        (baseColor.blue * lightness).round().clamp(0, 255),
      );
      
      final path = Path();
      path.moveTo(0, baseHeight);
      
      // Create smooth wavy contours
      for (double x = 0; x <= size.width; x += 1) {
        final progress = x / size.width;
        final wave = amplitude * sin(progress * 3.14159 * 1.0 + i * 0.3);
        final y = baseHeight + wave;
        path.lineTo(x, y);
      }
      
      // Cover full screen height
      path.lineTo(size.width, size.height); // Go to bottom of screen
      path.lineTo(0, size.height);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }
  
  /// Draw one simple hill in the foreground
  void _drawSimpleHill(Canvas canvas, Size size, Paint paint) {
    final hillColor = _getHillBaseColor(season);
    final baseHeight = size.height * 0.8; // Position hill lower for full-screen sky
    final amplitude = 40;
    
    paint.color = hillColor;
    
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);
    
    // Create simple smooth hill curve
    for (double x = 0; x <= size.width; x += 1) {
      final progress = x / size.width;
      final wave = amplitude * sin(progress * 3.14159 * 0.8);
      final y = baseHeight - wave;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  /// Get base sky color for the season
  Color _getSkyBaseColor(Season season) {
    switch (season) {
      case Season.spring:
        return const Color(0xFF87CEEB); // Sky blue
      case Season.summer:
        return const Color(0xFFF9C846); // Golden yellow
      case Season.autumn:
        return const Color(0xFFFFD700); // Gold
      case Season.winter:
        return const Color(0xFFE6F3FF); // Light blue
    }
  }
  
  /// Get base hill color for the season
  Color _getHillBaseColor(Season season) {
    switch (season) {
      case Season.spring:
        return const Color(0xFF32CD32); // Lime green
      case Season.summer:
        return const Color(0xFF228B22); // Forest green
      case Season.autumn:
        return const Color(0xFF8B4513); // Saddle brown
      case Season.winter:
        return const Color(0xFF708090); // Slate gray
    }
  }
  
  /// Draw hill contours - 4 background hills + 1 foreground hill with criss-crossing perspective
  void _drawHillContours(Canvas canvas, Size size, Paint paint) {
    final hillColors = _getHillColors(season);
    
    // Draw hills from back to front to create proper overlapping with dramatic variation
    // 4 background hills (farthest to closest) with dramatic criss-crossing directions
    for (int i = 0; i < 4; i++) {
      final baseHeight = size.height * (0.5 + i * 0.08); // Full screen positioning
      final amplitude = 35 + (i * 12); // Full dramatic amplitude
      
      paint.color = hillColors[i % hillColors.length];
      
      final path = Path();
      path.moveTo(0, size.height); // Start from bottom
      path.lineTo(0, baseHeight); // Go up to hill base
      
      // Create smooth, curved hills with DIFFERENT rising and falling patterns
      if (i == 0) {
        // Hill 1: Peak on LEFT side, valley on right
        path.moveTo(0, baseHeight);
        path.quadraticBezierTo(
          size.width * 0.2, baseHeight - amplitude * 0.9,  // Peak on left
          size.width * 0.5, baseHeight - amplitude * 0.2,  // Valley in middle
        );
        path.quadraticBezierTo(
          size.width * 0.8, baseHeight - amplitude * 0.1,  // Low on right
          size.width, baseHeight,
        );
      } else if (i == 1) {
        // Hill 2: Valley on left, peak in MIDDLE, valley on right
        path.moveTo(0, baseHeight);
        path.quadraticBezierTo(
          size.width * 0.15, baseHeight - amplitude * 0.1,  // Low on left
          size.width * 0.4, baseHeight - amplitude * 0.8,   // Peak in middle
        );
        path.quadraticBezierTo(
          size.width * 0.7, baseHeight - amplitude * 0.2,  // Valley on right
          size.width, baseHeight - amplitude * 0.1,
        );
      } else if (i == 2) {
        // Hill 3: Peak on RIGHT side, valley on left
        path.moveTo(0, baseHeight);
        path.quadraticBezierTo(
          size.width * 0.1, baseHeight - amplitude * 0.1,  // Low on left
          size.width * 0.3, baseHeight - amplitude * 0.3,  // Rising
        );
        path.quadraticBezierTo(
          size.width * 0.6, baseHeight - amplitude * 0.4,  // Still rising
          size.width * 0.85, baseHeight - amplitude * 0.9, // Peak on right
        );
        path.quadraticBezierTo(
          size.width * 0.95, baseHeight - amplitude * 0.2,
          size.width, baseHeight - amplitude * 0.1,
        );
      } else if (i == 3) {
        // Hill 4: Multiple peaks and valleys - most complex pattern
        path.moveTo(0, baseHeight);
        path.quadraticBezierTo(
          size.width * 0.05, baseHeight - amplitude * 0.2,  // Small rise
          size.width * 0.2, baseHeight - amplitude * 0.6,   // First peak
        );
        path.quadraticBezierTo(
          size.width * 0.4, baseHeight - amplitude * 0.2,   // Valley
          size.width * 0.6, baseHeight - amplitude * 0.7,   // Second peak
        );
        path.quadraticBezierTo(
          size.width * 0.8, baseHeight - amplitude * 0.3,   // Another valley
          size.width, baseHeight - amplitude * 0.5,         // Final rise
        );
      }
      
      path.lineTo(size.width, size.height);
      path.close();
      
      canvas.drawPath(path, paint);
    }
    
    // 1 foreground hill (most prominent, covers parts of background hills)
    final foregroundHeight = size.height * 0.75;
    final foregroundAmplitude = 55; // Full dramatic amplitude
    
    paint.color = hillColors[hillColors.length - 1];
    
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, foregroundHeight);
    
    // Foreground hill: Completely different pattern - peaks and valleys in different places
    path.moveTo(0, foregroundHeight);
    path.quadraticBezierTo(
      size.width * 0.1, foregroundHeight - foregroundAmplitude * 0.3,  // Small rise
      size.width * 0.25, foregroundHeight - foregroundAmplitude * 0.1, // Valley
    );
    path.quadraticBezierTo(
      size.width * 0.4, foregroundHeight - foregroundAmplitude * 0.7,  // Major peak
      size.width * 0.6, foregroundHeight - foregroundAmplitude * 0.2,  // Valley
    );
    path.quadraticBezierTo(
      size.width * 0.75, foregroundHeight - foregroundAmplitude * 0.8, // Another peak
      size.width * 0.9, foregroundHeight - foregroundAmplitude * 0.3,  // Final valley
    );
    path.quadraticBezierTo(
      size.width * 0.95, foregroundHeight - foregroundAmplitude * 0.1,
      size.width, foregroundHeight - foregroundAmplitude * 0.2,
    );
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  
  
  
  /// Helper method to draw organic hills/mountains with gradients
  void _drawOrganicHills(Canvas canvas, Size size, Paint paint, Color baseColor, List<Map<String, dynamic>> hills) {
    for (int i = 0; i < hills.length; i++) {
      final hill = hills[i];
      final baseHeight = hill['baseHeight'] as double;
      final lightness = hill['lightness'] as double;
      final peaks = hill['peaks'] as List<double>;
      final peakHeights = hill['peakHeights'] as List<double>;
      final valleys = hill['valleys'] as List<double>;
      final valleyDepths = hill['valleyDepths'] as List<double>;
      
      final path = Path();
      path.moveTo(0, baseHeight);
      
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
      
      // Use solid colors - no gradients
      paint.color = baseColor;
      
      canvas.drawPath(path, paint);
    }
  }

  void _drawSeasonalElements(Canvas canvas, Size size, Paint paint) {
    switch (season) {
      case Season.spring:
        _drawSpringElements(canvas, size, paint);
        break;
      case Season.summer:
        _drawSummerElements(canvas, size, paint);
        break;
      case Season.autumn:
        _drawAutumnElements(canvas, size, paint);
        break;
      case Season.winter:
        _drawWinterElements(canvas, size, paint);
        break;
    }
  }

  void _drawSpringElements(Canvas canvas, Size size, Paint paint) {
    // Draw multiple trees with pink blossoms and clouds
    _drawClouds(canvas, size, paint);
    
    paint.color = theme.colorScheme.primary; // Fully opaque
    _drawTree(canvas, size.width * 0.2, size.height * 0.4, size.height * 0.3, paint);
    _drawTree(canvas, size.width * 0.6, size.height * 0.5, size.height * 0.35, paint);
    _drawTree(canvas, size.width * 0.8, size.height * 0.3, size.height * 0.4, paint);
    
    // Add some flowers
    _drawFlowers(canvas, size, paint);
  }

  void _drawSummerElements(Canvas canvas, Size size, Paint paint) {
    // Draw sun with gradient (light at top, darker at bottom)
    final sunCenter = Offset(size.width * 0.85, size.height * 0.2);
    final sunRadius = size.height * 0.12;
    
    final sunGradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 1.0,
      colors: [
        Color.fromARGB(255, 
          (theme.colorScheme.primary.red * 1.2).clamp(0, 255).round(),
          (theme.colorScheme.primary.green * 1.2).clamp(0, 255).round(),
          (theme.colorScheme.primary.blue * 1.2).clamp(0, 255).round(),
        ),
        theme.colorScheme.primary,
      ],
    );
    
    final rect = Rect.fromCircle(center: sunCenter, radius: sunRadius);
    final shader = sunGradient.createShader(rect);
    paint.shader = shader;
    
    canvas.drawCircle(sunCenter, sunRadius, paint);
    paint.shader = null; // Reset shader
    
    _drawClouds(canvas, size, paint);
    
    paint.color = theme.colorScheme.primary; // Fully opaque trees
    _drawTree(canvas, size.width * 0.1, size.height * 0.4, size.height * 0.3, paint);
    _drawTree(canvas, size.width * 0.4, size.height * 0.5, size.height * 0.35, paint);
    _drawTree(canvas, size.width * 0.7, size.height * 0.4, size.height * 0.3, paint);
  }

  void _drawAutumnElements(Canvas canvas, Size size, Paint paint) {
    // Draw autumn trees with orange leaves and clouds
    _drawClouds(canvas, size, paint);
    
    paint.color = theme.colorScheme.secondary; // Fully opaque autumn trees
    _drawTree(canvas, size.width * 0.15, size.height * 0.4, size.height * 0.35, paint);
    _drawTree(canvas, size.width * 0.5, size.height * 0.3, size.height * 0.4, paint);
    _drawTree(canvas, size.width * 0.8, size.height * 0.45, size.height * 0.3, paint);
    
    // Add falling leaves
    _drawFallingLeaves(canvas, size, paint);
  }

  void _drawWinterElements(Canvas canvas, Size size, Paint paint) {
    // Draw snow-capped mountains and snow clouds
    _drawSnowClouds(canvas, size, paint);
    paint.color = theme.colorScheme.primary; // Fully opaque mountains
    _drawMountain(canvas, size, paint);
    
    // Add some bare winter trees
    paint.color = theme.colorScheme.primary; // Fully opaque trees
    _drawBareTree(canvas, size.width * 0.2, size.height * 0.4, size.height * 0.3, paint);
    _drawBareTree(canvas, size.width * 0.7, size.height * 0.5, size.height * 0.25, paint);
  }

  void _drawTree(Canvas canvas, double x, double y, double height, Paint paint) {
    // Tree trunk
    final trunkPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 8, y, 16, height * 0.3),
        const Radius.circular(8),
      ),
      trunkPaint,
    );
    
    // Tree canopy
    canvas.drawCircle(
      Offset(x, y - height * 0.1),
      height * 0.25,
      paint,
    );
  }

  void _drawMountain(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.2, size.height * 0.3);
    path.lineTo(size.width * 0.4, size.height * 0.5);
    path.lineTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.4);
    path.lineTo(size.width, size.height * 0.6);
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  void _drawClouds(Canvas canvas, Size size, Paint paint) {
    // Draw multiple clouds with subtle gradients
    _drawCloudWithGradient(canvas, size.width * 0.1, size.height * 0.15, size.height * 0.08, paint);
    _drawCloudWithGradient(canvas, size.width * 0.4, size.height * 0.1, size.height * 0.06, paint);
    _drawCloudWithGradient(canvas, size.width * 0.7, size.height * 0.12, size.height * 0.07, paint);
  }

  void _drawSnowClouds(Canvas canvas, Size size, Paint paint) {
    // Draw snow clouds with gradients
    _drawCloudWithGradient(canvas, size.width * 0.05, size.height * 0.1, size.height * 0.1, paint);
    _drawCloudWithGradient(canvas, size.width * 0.3, size.height * 0.08, size.height * 0.08, paint);
    _drawCloudWithGradient(canvas, size.width * 0.6, size.height * 0.12, size.height * 0.09, paint);
    _drawCloudWithGradient(canvas, size.width * 0.85, size.height * 0.06, size.height * 0.07, paint);
  }

  void _drawCloud(Canvas canvas, double x, double y, double size, Paint paint) {
    // Draw a fluffy cloud using multiple circles
    canvas.drawCircle(Offset(x, y), size, paint);
    canvas.drawCircle(Offset(x + size * 0.8, y), size * 0.7, paint);
    canvas.drawCircle(Offset(x + size * 1.5, y), size * 0.6, paint);
    canvas.drawCircle(Offset(x + size * 0.4, y - size * 0.3), size * 0.5, paint);
    canvas.drawCircle(Offset(x + size * 1.0, y - size * 0.2), size * 0.4, paint);
  }
  
  void _drawCloudWithGradient(Canvas canvas, double x, double y, double size, Paint paint) {
    // Create gradient for cloud (light at top, slightly darker at bottom)
    final cloudGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Color.fromARGB(255, 240, 240, 240), // Slightly darker at bottom
      ],
    );
    
    final rect = Rect.fromLTWH(x - size, y - size, size * 3, size * 2);
    final shader = cloudGradient.createShader(rect);
    paint.shader = shader;
    
    // Draw a fluffy cloud using multiple circles
    canvas.drawCircle(Offset(x, y), size, paint);
    canvas.drawCircle(Offset(x + size * 0.8, y), size * 0.7, paint);
    canvas.drawCircle(Offset(x + size * 1.5, y), size * 0.6, paint);
    canvas.drawCircle(Offset(x + size * 0.4, y - size * 0.3), size * 0.5, paint);
    canvas.drawCircle(Offset(x + size * 1.0, y - size * 0.2), size * 0.4, paint);
    
    paint.shader = null; // Reset shader
  }

  void _drawFlowers(Canvas canvas, Size size, Paint paint) {
    paint.color = theme.colorScheme.secondary.withValues(alpha: 0.6);
    
    // Draw small flowers scattered around
    for (int i = 0; i < 8; i++) {
      final x = (size.width * 0.1) + (i * size.width * 0.1);
      final y = size.height * (0.6 + (i % 3) * 0.1);
      _drawFlower(canvas, x, y, 8, paint);
    }
  }

  void _drawFlower(Canvas canvas, double x, double y, double size, Paint paint) {
    // Draw a simple flower with petals
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi) / 5;
      final petalX = x + cos(angle) * size;
      final petalY = y + sin(angle) * size;
      canvas.drawCircle(Offset(petalX, petalY), size * 0.3, paint);
    }
    // Center
    paint.color = theme.colorScheme.primary.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(x, y), size * 0.2, paint);
  }

  void _drawFallingLeaves(Canvas canvas, Size size, Paint paint) {
    paint.color = theme.colorScheme.secondary.withValues(alpha: 0.4);
    
    // Draw falling leaves
    for (int i = 0; i < 6; i++) {
      final x = size.width * (0.1 + i * 0.15);
      final y = size.height * (0.2 + (i % 3) * 0.2);
      _drawLeaf(canvas, x, y, 6, paint);
    }
  }

  void _drawLeaf(Canvas canvas, double x, double y, double size, Paint paint) {
    final path = Path();
    path.moveTo(x, y);
    path.quadraticBezierTo(x + size, y - size, x + size * 0.5, y + size);
    path.quadraticBezierTo(x - size * 0.5, y + size, x, y);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBareTree(Canvas canvas, double x, double y, double height, Paint paint) {
    // Tree trunk
    final trunkPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 6, y, 12, height * 0.4),
        const Radius.circular(6),
      ),
      trunkPaint,
    );
    
    // Bare branches
    final branchPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Main branches
    canvas.drawLine(
      Offset(x, y - height * 0.1),
      Offset(x - height * 0.2, y - height * 0.3),
      branchPaint,
    );
    canvas.drawLine(
      Offset(x, y - height * 0.1),
      Offset(x + height * 0.2, y - height * 0.3),
      branchPaint,
    );
    canvas.drawLine(
      Offset(x, y - height * 0.1),
      Offset(x, y - height * 0.4),
      branchPaint,
    );
  }

  Color _getSeasonalColor() {
    switch (season) {
      case Season.spring:
        return Colors.green; // Bright green for spring
      case Season.summer:
        return Colors.blue; // Bright blue for summer
      case Season.autumn:
        return Colors.orange; // Bright orange for autumn
      case Season.winter:
        return Colors.grey; // Gray for winter
    }
  }
  
  /// Get sky colors - 2-3 shades of yellow flowing in same direction
  List<Color> _getSkyColors(Season season) {
    switch (season) {
      case Season.spring:
        return [
          const Color(0xFF87CEEB), // Bright sky blue
          const Color(0xFFB0E0E6), // Light blue
        ];
      case Season.summer:
        return [
          const Color(0xFFF9C846), // Bright yellow-orange
          const Color(0xFFE6B800), // Darker yellow
          const Color(0xFFD4A017), // Darkest yellow
        ];
      case Season.autumn:
        return [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFE6C200), // Darker gold
        ];
      case Season.winter:
        return [
          const Color(0xFFE6F3FF), // Light blue
          const Color(0xFFB0C4DE), // Steel blue
        ];
    }
  }
  
  /// Get hill colors - orange, lime, and green with lighter/darker shades
  List<Color> _getHillColors(Season season) {
    switch (season) {
      case Season.spring:
        return [
          const Color(0xFF90EE90), // Light green
          const Color(0xFF32CD32), // Lime green
          const Color(0xFF228B22), // Forest green
        ];
      case Season.summer:
        return [
          const Color(0xFFFF8C00), // Orange
          const Color(0xFF32CD32), // Lime green
          const Color(0xFF228B22), // Forest green
          const Color(0xFF006400), // Dark green
        ];
      case Season.autumn:
        return [
          const Color(0xFFFF8C00), // Orange
          const Color(0xFFFFA500), // Light orange
          const Color(0xFF32CD32), // Lime green
          const Color(0xFF228B22), // Forest green
        ];
      case Season.winter:
        return [
          const Color(0xFF4682B4), // Steel blue
          const Color(0xFF5F9EA0), // Cadet blue
          const Color(0xFF708090), // Slate gray
        ];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! SeasonalHeaderPainter ||
        oldDelegate.theme != theme ||
        oldDelegate.season != season;
  }
}

/// Season enum for background patterns
enum Season {
  spring,
  summer,
  autumn,
  winter,
}
