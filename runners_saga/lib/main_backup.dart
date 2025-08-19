import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';
import 'shared/widgets/app_router.dart';
import 'shared/providers/app_providers.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== APP STARTUP BEGINNING ===');
  
  try {
    // Debug: Check if we're on web platform
    if (kIsWeb) {
      print('=== WEB PLATFORM DETECTED ===');
      print('Checking Flutter Firebase options...');
      try {
        final options = DefaultFirebaseOptions.web;
        print('✅ Flutter Firebase options loaded successfully');
        print('Project ID: ${options.projectId}');
        print('API Key: ${options.apiKey}');
        print('App ID: ${options.appId}');
      } catch (e) {
        print('❌ Error loading Flutter Firebase options: $e');
      }
    }
    
    // Initialize Firebase with timeout to prevent hanging
    print('=== INITIALIZING FIREBASE ===');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('⚠️ Firebase initialization timed out - continuing anyway');
        return Firebase.app();
      },
    );
    print('✅ Firebase initialized successfully');
    
    // Debug: Check Firebase app instance
    final app = Firebase.app();
    print('Firebase app name: ${app.name}');
    print('Firebase app options: ${app.options}');
    
    // Initialize Firebase services with timeout
    print('=== INITIALIZING FIREBASE SERVICES ===');
    // Only initialize essential services at startup
    await _initializeEssentialFirebaseServices().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('⚠️ Firebase services initialization timed out - continuing anyway');
      },
    );
    print('✅ Essential Firebase services initialized successfully');
    
    print('=== STARTING APP ===');
    runApp(const ProviderScope(child: RunnersSagaApp()));
  } catch (e) {
    print('=== FIREBASE INITIALIZATION FAILED ===');
    print('Error type: ${e.runtimeType}');
    print('Error message: $e');
    print('Stack trace: ${StackTrace.current}');
    
    print('=== STARTING APP WITH ERROR SCREEN ===');
    // If Firebase fails to initialize, show error and exit
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Firebase Initialization Failed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $e',
                style: TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Check the console for detailed debugging information.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

Future<void> _initializeEssentialFirebaseServices() async {
  print('  → Initializing Firestore...');
  try {
    // Initialize Firestore settings with limited memory
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 25 * 1024 * 1024, // Reduced to 25MB
    );
    print('  ✅ Firestore initialized successfully');
  } catch (e) {
    print('  ❌ Firestore initialization failed: $e');
    // Don't rethrow - continue without Firestore
  }
  
  print('  → Initializing Firebase Auth...');
  try {
    // Initialize Firebase Auth but don't block on network connection
    // Just set up the instance without waiting for auth state
    FirebaseAuth.instance;
    print('  ✅ Firebase Auth initialized successfully');
  } catch (e) {
    print('  ❌ Firebase Auth initialization failed: $e');
    // Don't rethrow - continue without Auth
  }
  
  // Note: Firebase Storage will be initialized when first needed
  print('  ⚠️ Firebase Storage will be initialized on-demand');
  
  // Set a flag to indicate Firebase is ready (even if some services failed)
  _firebaseInitialized = true;
}

// Global flag to track Firebase initialization
bool _firebaseInitialized = false;

// Getter to check if Firebase is ready
bool get isFirebaseReady => _firebaseInitialized;

// Initialize Firebase Storage when first needed
Future<void> _initializeFirebaseStorage() async {
  print('  → Initializing Firebase Storage...');
  try {
    FirebaseStorage.instance;
    print('  ✅ Firebase Storage initialized successfully');
  } catch (e) {
    print('  ❌ Firebase Storage initialization failed: $e');
    rethrow;
  }
}

class RunnersSagaApp extends ConsumerWidget {
  const RunnersSagaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    
    return MaterialApp.router(
      title: "The Runner's Saga",
      theme: appTheme.lightTheme,
      darkTheme: appTheme.darkTheme,
      themeMode: appTheme.themeMode,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
