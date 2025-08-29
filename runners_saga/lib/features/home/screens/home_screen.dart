import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../core/constants/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: kMidnightNavy,
      body: SafeArea(
        child: Column(
          children: [
            // Hero section with app branding (reduced height)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kRoyalPlum,
                      kDeepTeal,
                      kMidnightNavy,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BackgroundPatternPainter(),
                      ),
                    ),
                    // App logo, title, and settings/login status
                    Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App logo placeholder
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: kElectricAqua,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: kElectricAqua.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.directions_run,
                                size: 40,
                                color: kMidnightNavy,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'THE RUNNER\'S SAGA',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Embark on an epic journey through time and space',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: kTextHigh,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // User status indicator
                            InkWell(
                              onTap: () {
                                if (authState != AuthState.authenticated) {
                                  context.push('/login');
                                }
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: kElectricAqua.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      authState == AuthState.authenticated ? Icons.verified_user : Icons.person_outline,
                                      size: 18,
                                      color: authState == AuthState.authenticated ? kMeadowGreen : kElectricAqua,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      authState == AuthState.authenticated
                                          ? (user?.email ?? 'Signed in')
                                          : 'Not signed in',
                                      style: const TextStyle(
                                        color: kTextHigh, 
                                        fontSize: 14, 
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main content area (now larger and more accessible)
            Expanded(
              flex: 3,
              child: Container(
                color: kMidnightNavy,
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Abel Township Saga section
                      Container(
                width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                          color: kSurfaceBase,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kElectricAqua.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                                Text(
                                  'Abel Township Saga',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: kElectricAqua,
                                  size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                            Text(
                              'Begin your journey in the mysterious town of Abel, where every run reveals a new chapter of the story.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: kTextHigh,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Clickable button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  context.push('/seasons');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kElectricAqua,
                                  foregroundColor: kMidnightNavy,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Enter Abel Township',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: kMidnightNavy,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Additional Episodes Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: kSurfaceElev,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kRoyalPlum.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'More Episodes',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: kRoyalPlum,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Explore additional storylines and running adventures beyond Abel Township.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: kTextHigh,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Episode previews
                            Row(
                              children: [
                                _buildEpisodePreview('S01E02', 'Distraction', kEmberCoral),
                                const SizedBox(width: 12),
                                _buildEpisodePreview('S01E03', 'Lay of the Land', kMeadowGreen),
                      ],
                    ),
                  ],
                ),
            ),

                      const SizedBox(height: 20),
            
                      // Training Programs section
            Container(
              width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                          color: kSurfaceElev,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kEmberCoral.withOpacity(0.3),
                            width: 1,
                          ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                            Text(
                              'Training Programs',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                            Text(
                              'Structured training plans coming soon to help you build endurance and unlock new story content.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: kTextHigh,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kSurfaceBase,
        selectedItemColor: kElectricAqua,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            context.push('/run/history');
          } else if (index == 2) {
            context.push('/settings');
          }
        },
      ),
    );
  }

  Widget _buildEpisodePreview(String episodeId, String title, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              episodeId,
            style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          Text(
            title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for background pattern
class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Draw subtle grid pattern
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


