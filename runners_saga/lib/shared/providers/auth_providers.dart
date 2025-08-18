import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../models/user_model.dart';
import 'settings_providers.dart';

/// Provider for current user
final currentUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider for auth service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for user profile
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  // TODO: Implement when Firebase is properly configured
  return null;
});

/// Provider for auth state
final authStateProvider = StateProvider<AuthState>((ref) {
  return AuthState.initial;
});

/// Auth state enum
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Provider for authentication loading state
final authLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for authentication error
final authErrorProvider = StateProvider<String?>((ref) {
  return null;
});

/// Provider for current user profile
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user != null) {
    final authService = ref.watch(authServiceProvider);
    return await authService.getUserProfile(user.uid);
  }
  return null;
});

/// Provider for user preferences
final userPreferencesProvider = StateProvider<Map<String, dynamic>>((ref) {
  return {};
});

/// Provider for user statistics
final userStatsProvider = FutureProvider<UserStats?>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile != null) {
    return UserStats(
      totalRuns: profile.totalRuns,
      totalDistance: profile.totalDistance,
      totalTime: profile.totalTime,
      averagePace: 0.0, // TODO: Calculate from run history
      bestPace: 0.0, // TODO: Calculate from run history
      longestRun: profile.totalDistance, // Use total distance as approximation
      currentStreak: 0, // TODO: Calculate from run history
      longestStreak: 0, // TODO: Calculate from run history
      currentLevel: profile.currentLevel,
      experiencePoints: profile.experiencePoints,
      totalSeasonsCompleted: profile.completedSeasons.length,
      totalAchievements: profile.achievements.length,
    );
  }
  return null;
});

/// Authentication controller provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

/// Authentication controller
class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(AuthState.initial) {
    // Listen to authentication state changes
    _ref.listen(currentUserProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            state = AuthState.authenticated;
            // Load user weight into settings provider on sign in
            final auth = _ref.read(authServiceProvider);
            auth.getUserWeightKg().then((w) {
              if (w != null && w > 0) {
                _ref.read(userWeightKgProvider.notifier).state = w;
              }
            });
          } else {
            state = AuthState.unauthenticated;
          }
        },
        loading: () => state = AuthState.loading,
        error: (error, stack) => state = AuthState.error,
      );
    });
  }

  /// Sign in with email and password
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('=== AUTH CONTROLLER: Starting sign in ===');
      _ref.read(authLoadingProvider.notifier).state = true;
      _ref.read(authErrorProvider.notifier).state = null;
      
      print('=== AUTH CONTROLLER: Getting auth service ===');
      final authService = _ref.read(authServiceProvider);
      print('=== AUTH CONTROLLER: Auth service obtained: $authService ===');
      
      print('=== AUTH CONTROLLER: Calling auth service signInWithEmailAndPassword ===');
      await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('=== AUTH CONTROLLER: Sign in successful, setting state to authenticated ===');
      state = AuthState.authenticated;
    } catch (e) {
      print('=== AUTH CONTROLLER: ERROR during sign in ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error toString: ${e.toString()}');
      
      _ref.read(authErrorProvider.notifier).state = e.toString();
      state = AuthState.error;
    } finally {
      _ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  /// Create user with email and password
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      print('=== AUTH CONTROLLER: Starting account creation ===');
      _ref.read(authLoadingProvider.notifier).state = true;
      _ref.read(authErrorProvider.notifier).state = null;
      
      print('=== AUTH CONTROLLER: Getting auth service ===');
      final authService = _ref.read(authServiceProvider);
      print('=== AUTH CONTROLLER: Auth service obtained: $authService ===');
      
      print('=== AUTH CONTROLLER: Calling auth service createUserWithEmailAndPassword ===');
      await authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
      );
      
      print('=== AUTH CONTROLLER: Account created successfully, setting state to authenticated ===');
      state = AuthState.authenticated;
    } catch (e) {
      print('=== AUTH CONTROLLER: ERROR during account creation ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error toString: ${e.toString()}');
      
      _ref.read(authErrorProvider.notifier).state = e.toString();
      state = AuthState.error;
    } finally {
      _ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      print('=== AUTH CONTROLLER: Starting sign out ===');
      _ref.read(authLoadingProvider.notifier).state = true;
      
      print('=== AUTH CONTROLLER: Getting auth service ===');
      final authService = _ref.read(authServiceProvider);
      print('=== AUTH CONTROLLER: Auth service obtained: $authService ===');
      
      print('=== AUTH CONTROLLER: Calling auth service signOut ===');
      await authService.signOut();
      print('=== AUTH CONTROLLER: Auth service signOut completed ===');
      
      print('=== AUTH CONTROLLER: Setting state to unauthenticated ===');
      state = AuthState.unauthenticated;
      print('=== AUTH CONTROLLER: Sign out completed successfully ===');
    } catch (e) {
      print('=== AUTH CONTROLLER: ERROR during sign out ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error toString: ${e.toString()}');
      
      _ref.read(authErrorProvider.notifier).state = e.toString();
      state = AuthState.error;
    } finally {
      _ref.read(authLoadingProvider.notifier).state = false;
      print('=== AUTH CONTROLLER: Sign out process finished ===');
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      print('=== AUTH CONTROLLER: Starting Google sign in ===');
      _ref.read(authLoadingProvider.notifier).state = true;
      _ref.read(authErrorProvider.notifier).state = null;
      
      print('=== AUTH CONTROLLER: Getting auth service ===');
      final authService = _ref.read(authServiceProvider);
      print('=== AUTH CONTROLLER: Auth service obtained: $authService ===');
      
      print('=== AUTH CONTROLLER: Calling auth service signInWithGoogle ===');
      await authService.signInWithGoogle();
      
      print('=== AUTH CONTROLLER: Google sign in successful, setting state to authenticated ===');
      state = AuthState.authenticated;
    } catch (e) {
      print('=== AUTH CONTROLLER: ERROR during Google sign in ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error toString: ${e.toString()}');
      
      _ref.read(authErrorProvider.notifier).state = e.toString();
      state = AuthState.error;
    } finally {
      _ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      _ref.read(authLoadingProvider.notifier).state = true;
      _ref.read(authErrorProvider.notifier).state = null;
      
      final authService = _ref.read(authServiceProvider);
      await authService.resetPassword(email);
    } catch (e) {
      _ref.read(authErrorProvider.notifier).state = e.toString();
      rethrow;
    } finally {
      _ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  /// Clear error
  void clearError() {
    _ref.read(authErrorProvider.notifier).state = null;
  }
}

/// User statistics model
class UserStats {
  final int totalRuns;
  final double totalDistance;
  final int totalTime; // Changed from Duration to int to match UserModel
  final double averagePace;
  final double bestPace;
  final double longestRun;
  final int currentStreak;
  final int longestStreak;
  final int currentLevel;
  final int experiencePoints;
  final int totalSeasonsCompleted;
  final int totalAchievements;

  UserStats({
    required this.totalRuns,
    required this.totalDistance,
    required this.totalTime,
    required this.averagePace,
    required this.bestPace,
    required this.longestRun,
    required this.currentStreak,
    required this.longestStreak,
    required this.currentLevel,
    required this.experiencePoints,
    required this.totalSeasonsCompleted,
    required this.totalAchievements,
  });
}
