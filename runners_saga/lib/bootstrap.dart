import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

/// Bootstraps essential services before runApp.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('=== APP STARTUP BEGINNING ===');

  if (kIsWeb) {
    debugPrint('=== WEB PLATFORM DETECTED ===');
    final options = DefaultFirebaseOptions.web;
    debugPrint('Firebase Project: ${options.projectId}');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configure Firestore (safe defaults).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 25 * 1024 * 1024,
    );

    // Touch FirebaseAuth to ensure ready.
    FirebaseAuth.instance;

    debugPrint('✅ Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

































