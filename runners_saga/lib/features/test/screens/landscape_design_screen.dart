import 'package:flutter/material.dart';
import 'dart:math';

/// Screen that recreates the sunset landscape design from the reference image
class LandscapeDesignScreen extends StatelessWidget {
  const LandscapeDesignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: LandscapeDesignPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Custom painter for the sunset landscape design
class LandscapeDesignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw the sky with smooth contours
    _drawSkyContours(canvas, size, paint);
    
    // Draw the layered hills
    _drawLayeredHills(canvas, size, paint);
  }

  /// Draw the sky with smooth curved contours instead of gradients
  void _drawSkyContours(Canvas canvas, Size size, Paint paint) {
    // Sky colors from reference image (top to bottom)
    final skyColors = [
      const Color(0xFF8B0000), // Deep red at top
      const Color(0xFFFF4500), // Orange-red
      const Color(0xFFFFA500), // Orange
      const Color(0xFFF9C846), // Golden yellow at horizon
    ];

    // Draw sky contours with smooth curves
    for (int i = 0; i < skyColors.length; i++) {
      final baseHeight = size.height * (0.1 + i * 0.15); // Spread across sky area
      final amplitude = 20 + (i * 8); // Gentle wave amplitude
      
      paint.color = skyColors[i];
      
      final path = Path();
      path.moveTo(0, baseHeight);
      
      // Create smooth, flowing sky contours
      for (double x = 0; x <= size.width; x += 1) {
        final progress = x / size.width;
        final wave = amplitude * sin(progress * 3.14159 * 0.8 + i * 0.3);
        final y = baseHeight + wave;
        path.lineTo(x, y);
      }
      
      path.lineTo(size.width, size.height * 0.6); // Sky ends at 60% height
      path.lineTo(0, size.height * 0.6);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  /// Draw multiple layers of hills with exact colors from reference
  void _drawLayeredHills(Canvas canvas, Size size, Paint paint) {
    // Exact colors from reference image (farthest to closest)
    final hillColors = [
      const Color(0xFF2F4F4F), // Dark teal (farthest)
      const Color(0xFF6B8E23), // Olive green
      const Color(0xFF8FBC8F), // Sage green
      const Color(0xFFAFEEEE), // Light mint green
      const Color(0xFFF0E68C), // Creamy yellow (closest)
    ];

    // Draw 5 hill layers from back to front (all rising left to right)
    for (int i = 0; i < 5; i++) {
      final baseHeight = size.height * (0.6 + i * 0.08); // Each hill starts higher
      final amplitude = 30.0 + (i * 10.0); // Gentle amplitude increase
      
      paint.color = hillColors[i];
      
      final path = Path();
      path.moveTo(0, size.height);
      path.lineTo(0, baseHeight);
      
      // Create smooth, flowing hill contours - ALL rising left to right
      _drawHillContour(path, size, baseHeight, amplitude, i);
      
      path.lineTo(size.width, size.height);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  /// Draw smooth hill contour - ALL hills rise gently from left to right
  void _drawHillContour(Path path, Size size, double baseHeight, double amplitude, int hillIndex) {
    // All hills follow the same pattern: gentle rise from left to right
    // Using smooth sine waves for natural curves, never straight lines
    
    path.moveTo(0, baseHeight);
    
    // Create smooth, flowing curves using sine waves
    for (double x = 0; x <= size.width; x += 1) {
      final progress = x / size.width;
      
      // Gentle rising curve from left to right
      final rise = amplitude * (0.3 + 0.7 * progress); // Gradually increase height
      final wave = amplitude * 0.2 * sin(progress * 3.14159 * 1.5 + hillIndex * 0.5); // Gentle wave
      
      final y = baseHeight - rise + wave;
      path.lineTo(x, y);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
