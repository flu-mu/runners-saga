import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/services/firebase/firestore_service.dart';
import '../../../core/constants/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => context.go('/'),
            tooltip: 'Go Home',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Account'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  authState == AuthState.authenticated ? Icons.verified_user : Icons.person_outline,
                  color: authState == AuthState.authenticated ? Colors.greenAccent : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authState == AuthState.authenticated ? (user?.email ?? 'Signed in') : 'Not signed in',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (authState == AuthState.authenticated) {
                      ref.read(authControllerProvider.notifier).signOut();
                    } else {
                      context.push('/login');
                    }
                  },
                  child: Text(
                    authState == AuthState.authenticated ? 'Sign out' : 'Sign in',
                  ),
                )
              ],
            ),
          ),
          
          _sectionTitle('Data & Cache'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cached, color: kElectricAqua),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear App Cache',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Clear cached data to get fresh information from the server',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestoreService = FirestoreService();
                    await firestoreService.clearCache();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cache cleared successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to clear cache: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kElectricAqua,
                  foregroundColor: kMidnightNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestoreService = FirestoreService();
                    final result = await firestoreService.fixTimestampFormats();
                    
                    if (context.mounted) {
                      final fixedCount = result['fixedCount'] as int;
                      final totalRuns = result['totalRuns'] as int;
                      final stringTimestamps = result['stringTimestamps'] as int;
                      
                      String message;
                      if (fixedCount > 0) {
                        message = 'Fixed $fixedCount timestamp formats! Your workouts should now display correctly.';
                      } else if (stringTimestamps > 0) {
                        message = 'Found $stringTimestamps runs with string dates, but they may not be ISO format. Check console for details.';
                      } else {
                        message = 'All $totalRuns runs already have valid timestamps!';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: fixedCount > 0 ? Colors.green : Colors.blue,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to fix timestamps: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.schedule),
                label: const Text('Fix Run Timestamps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kElectricAqua,
                  foregroundColor: kMidnightNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestoreService = FirestoreService();
                    final result = await firestoreService.forceUpdateAllTimestamps();
                    
                    if (context.mounted) {
                      final updatedCount = result['updatedCount'] as int;
                      final totalRuns = result['totalRuns'] as int;
                      
                      String message;
                      if (updatedCount > 0) {
                        message = 'Force updated $updatedCount timestamps! This should fix all workout display issues.';
                      } else {
                        message = 'All $totalRuns runs already have valid timestamps!';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: updatedCount > 0 ? Colors.green : Colors.blue,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to force update timestamps: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.update),
                label: const Text('Force Update All Timestamps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: kMidnightNavy,
        selectedItemColor: kElectricAqua,
        unselectedItemColor: Colors.white70,
        currentIndex: 0, // Settings is selected
        onTap: (index) {
          switch (index) {
            case 0: // Settings (current)
              break;
            case 1: // Home
              context.go('/');
              break;
            case 2: // Workouts
              context.go('/workouts');
              break;
            case 3: // Run
              context.go('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          )
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(color: Colors.white70)),
      );
}
