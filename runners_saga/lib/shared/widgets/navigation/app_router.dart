import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';

import '../../../features/auth/screens/login_screen.dart';
import '../../../features/auth/screens/signup_screen.dart';
import '../../../features/home/screens/home_screen.dart';
import '../../../features/run/screens/run_screen.dart';
import '../../../features/run/screens/run_history_screen.dart';
import '../../../features/run/screens/run_target_selection_screen.dart';
import '../../../features/run/screens/run_summary_screen.dart';
import '../../../features/story/screens/story_screen.dart';
import '../../../features/story/screens/season_hub_screen.dart';
import '../../../features/story/screens/episode_detail_screen.dart';
import '../../../features/story/screens/seasons_screen.dart';
import '../../../features/onboarding/screens/welcome_screen.dart';
import '../../../features/onboarding/screens/story_intro_screen.dart';
import '../../../features/onboarding/screens/account_creation_screen.dart';
import 'splash_screen.dart';
import '../../../features/settings/screens/settings_screen.dart';

/// App router configuration using GoRouter
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      print('=== APP ROUTER: Redirect called for path: ${state.matchedLocation} ===');
      
      // Get the auth state from the provider
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authControllerProvider);
      print('=== APP ROUTER: Current auth state: $authState ===');
      
      // If we're still in initial state, don't redirect yet
      if (authState == AuthState.initial) {
        print('=== APP ROUTER: Auth state is initial, staying on current route ===');
        return null;
      }
      
      // If we're loading, don't redirect yet
      if (authState == AuthState.loading) {
        print('=== APP ROUTER: Auth state is loading, staying on current route ===');
        return null;
      }
      
      // If not authenticated and trying to access protected routes, redirect to welcome
      if (authState != AuthState.authenticated) {
        if (state.matchedLocation != '/onboarding/welcome' && 
            state.matchedLocation != '/onboarding/story-intro' && 
            state.matchedLocation != '/onboarding/account-creation' &&
            state.matchedLocation != '/login' && 
            state.matchedLocation != '/signup' && 
            state.matchedLocation != '/' &&
            state.matchedLocation != '/settings') {
          print('=== APP ROUTER: User not authenticated, redirecting from ${state.matchedLocation} to /onboarding/welcome ===');
          return '/onboarding/welcome';
        }
      }
      
      // If authenticated and on auth/onboarding screens, redirect to home
      if (authState == AuthState.authenticated) {
        if (state.matchedLocation == '/login' || 
            state.matchedLocation == '/signup' || 
            state.matchedLocation == '/onboarding/welcome' ||
            state.matchedLocation == '/onboarding/story-intro' ||
            state.matchedLocation == '/onboarding/account-creation' ||
            state.matchedLocation == '/') {
          print('=== APP ROUTER: User authenticated, redirecting from ${state.matchedLocation} to /home ===');
          return '/home';
        }
      }
      
      print('=== APP ROUTER: No redirect needed for ${state.matchedLocation} ===');
      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Onboarding routes - Corrected flow: Welcome → Login → Story Intro
      GoRoute(
        path: '/onboarding/welcome',
        name: 'onboarding_welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      
      // Login comes after welcome
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Story intro comes after login
      GoRoute(
        path: '/onboarding/story-intro',
        name: 'onboarding_story_intro',
        builder: (context, state) => const StoryIntroScreen(),
      ),
      
      // Account creation comes after story intro
      GoRoute(
        path: '/onboarding/account-creation',
        name: 'onboarding_account_creation',
        builder: (context, state) => const AccountCreationScreen(),
      ),
      
      // Signup route (alternative to login)
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      
      // Main app routes (protected)
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      GoRoute(
        path: '/run/target-selection',
        name: 'run_target_selection',
        builder: (context, state) => const RunTargetSelectionScreen(),
      ),
      
      GoRoute(
        path: '/run',
        name: 'run',
        builder: (context, state) => const RunScreen(),
      ),
      
      GoRoute(
        path: '/run/summary',
        name: 'run_summary',
        builder: (context, state) => const RunSummaryScreen(),
      ),
      
      GoRoute(
        path: '/run/history',
        name: 'run_history',
        builder: (context, state) => const RunHistoryScreen(),
      ),

      // Settings (available for both signed in/out)
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      
      GoRoute(
        path: '/story/season-hub',
        name: 'season_hub',
        builder: (context, state) => const SeasonHubScreen(),
      ),
      
      GoRoute(
        path: '/story/:seasonId',
        name: 'story',
        builder: (context, state) {
          final seasonId = state.pathParameters['seasonId'] ?? '';
          return StoryScreen(seasonId: seasonId);
        },
      ),
      GoRoute(
        path: '/episode/:episodeId',
        name: 'episode_detail',
        builder: (context, state) {
          final episodeId = state.pathParameters['episodeId'] ?? '';
          return EpisodeDetailScreen(episodeId: episodeId);
        },
      ),
      
      // Seasons and episodes selection
      GoRoute(
        path: '/seasons',
        name: 'seasons',
        builder: (context, state) => const SeasonsScreen(),
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Extension methods for easier navigation
extension NavigationExtension on BuildContext {
  void goToHome() => go('/home');
  void goToLogin() => go('/login');
  void goToSignup() => go('/signup');
  void goToRunTarget() => go('/run/target-selection');
  void goToRun() => go('/run');
  void goToRunSummary() => go('/run/summary');
  void goToRunHistory() => go('/run/history');
  void goToSeasonHub() => go('/story/season-hub');
  void goToStory(String seasonId) => go('/story/$seasonId');
  void goToSeasons() => go('/seasons');
  void goToOnboardingWelcome() => go('/onboarding/welcome');
  void goToOnboardingStoryIntro() => go('/onboarding/story-intro');
  void goToOnboardingAccountCreation() => go('/onboarding/account-creation');
  void goBack() => pop();
}
