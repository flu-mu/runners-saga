import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase_options.dart';

/// Provider that tracks Firebase initialization status
final firebaseReadyProvider = FutureProvider<bool>((ref) async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configure Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 25 * 1024 * 1024,
    );

    // Ensure FirebaseAuth is ready
    FirebaseAuth.instance;

    return true;
  } catch (e, stackTrace) {
    // Log error but don't crash the app
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  }
});

/// Provider for Firebase initialization status with error handling
final firebaseStatusProvider = Provider<FirebaseStatus>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  
  return firebaseReady.when(
    data: (isReady) => isReady 
      ? FirebaseStatus.ready 
      : FirebaseStatus.failed,
    loading: () => FirebaseStatus.initializing,
    error: (_, __) => FirebaseStatus.failed,
  );
});

/// Enum representing Firebase initialization status
enum FirebaseStatus {
  initializing,
  ready,
  failed,
}
