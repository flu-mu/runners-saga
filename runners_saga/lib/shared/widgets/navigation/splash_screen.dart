import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../../core/themes/theme_factory.dart';

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
    final theme = ThemeFactory.getCurrentTheme();
    final themeColors = ThemeFactory.getThemeColors(ThemeFactory.getAvailableThemes().first);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.secondary.withValues(alpha: 0.6),
              theme.scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.6, 1.0],
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
                    // Hero Image Background
                    Container(
                      width: double.infinity,
                      height: 260,
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/splash_hero.png'),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                              theme.scaffoldBackgroundColor,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // App Logo
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.directions_run,
                                  size: 40,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // App Title
                              Text(
                                "RUNNER'S SAGA",
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // App Subtitle
                              Text(
                                'Run the Story. Live the Adventure.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Loading Indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Loading Text
                    Text(
                      'Initializing Firebase...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onBackground.withValues(alpha: 0.7),
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
