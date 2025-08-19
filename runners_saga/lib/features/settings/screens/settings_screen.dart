import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/auth_providers.dart';
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
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(color: Colors.white70)),
      );
}
