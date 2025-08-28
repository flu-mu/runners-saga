import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    print('=== SPLASH SCREEN: initState called ===');
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Check current state immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('=== SPLASH SCREEN: Post frame callback, checking auth state ===');
      _checkAuthState();
    });
  }

  void _checkAuthState() {
    print('=== SPLASH SCREEN: Checking auth state ===');
    final authState = ref.read(authControllerProvider);
    print('Current auth state: $authState');
    
    // If we're not in initial state, redirect accordingly
    if (authState != AuthState.initial) {
      print('Auth state is not initial, redirecting...');
      _redirectBasedOnAuthState(authState);
    } else {
      print('Auth state is still initial, waiting...');
    }
  }

  void _redirectBasedOnAuthState(AuthState authState) {
    print('=== SPLASH SCREEN: Redirecting based on auth state: $authState ===');
    switch (authState) {
      case AuthState.authenticated:
        print('User is authenticated, redirecting to home');
        context.go('/home');
        break;
      case AuthState.unauthenticated:
        print('User is not authenticated, redirecting to onboarding');
        // For new users, redirect to onboarding instead of login
        context.go('/onboarding/welcome');
        break;
      case AuthState.error:
        print('Auth error occurred, redirecting to onboarding');
        // For errors, still redirect to onboarding
        context.go('/onboarding/welcome');
        break;
      case AuthState.loading:
        print('Auth is loading, staying on splash');
        // Stay on splash, wait for auth state to resolve
        break;
      case AuthState.initial:
        print('Auth is in initial state, staying on splash');
        // Stay on splash, wait for auth state to resolve
        break;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't listen for auth state changes here - only redirect once in initState

    return Scaffold(
      backgroundColor: const Color(0xFF6750A4),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6750A4),
              Color(0xFF9C27B0),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6750A4).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_run,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // App Title
                    const Text(
                      "The Runner's Saga",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // App Subtitle
                    Text(
                      'Your Run. Your Story.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Loading Indicator
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Loading Text
                    Text(
                      'Initializing Firebase...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
