import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

class FirebaseService {
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static FirebaseStorage? _storage;
  
  // Getters for Firebase instances
  static FirebaseAuth get auth => _auth!;
  static FirebaseFirestore get firestore => _firestore!;
  static FirebaseStorage get storage => _storage!;
  
  /// Initialize Firebase services
  static Future<void> initialize() async {
    try {
      // Initialize Firebase Auth
      _auth = FirebaseAuth.instance;
      
      // Initialize Firestore
      _firestore = FirebaseFirestore.instance;
      
      // Initialize Firebase Storage
      _storage = FirebaseStorage.instance;
      
      // Configure Firestore settings with limited memory
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 25 * 1024 * 1024, // Limited to 25MB
      );
      
      developer.log('Firebase services initialized successfully');
    } catch (e) {
      developer.log('Error initializing Firebase services: $e');
      rethrow;
    }
  }
  
  /// Get current user
  static User? get currentUser => _auth?.currentUser;
  
  /// Check if user is signed in
  static bool get isSignedIn => _auth?.currentUser != null;
  
  /// Sign out user
  static Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (e) {
      developer.log('Error signing out: $e');
      rethrow;
    }
  }
  
  /// Get user document reference
  static DocumentReference<Map<String, dynamic>> getUserDoc(String userId) {
    return _firestore!.collection('users').doc(userId);
  }
  
  /// Get runs collection reference
  static CollectionReference<Map<String, dynamic>> getRunsCollection() {
    return _firestore!.collection('runs');
  }
  
  /// Get seasons collection reference
  static CollectionReference<Map<String, dynamic>> getSeasonsCollection() {
    return _firestore!.collection('seasons');
  }
  
  /// Get progress collection reference
  static CollectionReference<Map<String, dynamic>> getProgressCollection() {
    return _firestore!.collection('progress');
  }
  
  /// Get audio storage reference
  static Reference getAudioStorageRef() {
    return _storage!.ref().child('audio');
  }
  
  /// Get images storage reference
  static Reference getImagesStorageRef() {
    return _storage!.ref().child('images');
  }
  
  /// Get stories storage reference
  static Reference getStoriesStorageRef() {
    return _storage!.ref().child('stories');
  }
}
