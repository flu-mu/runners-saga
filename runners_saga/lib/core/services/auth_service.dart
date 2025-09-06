import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Not available in this version
import 'dart:developer' as developer;
import '../../shared/models/user_model.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid',
    ],
    clientId: '882096923572-83p488filcuut9dd4h3qogbjehni7t2l.apps.googleusercontent.com',
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user ID token
  Future<String?> get idToken async => await _auth.currentUser?.getIdToken();

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Check if user is signed in with Google
  bool get isSignedInWithGoogle => _auth.currentUser?.providerData
      .any((userInfo) => userInfo.providerId == 'google.com') ?? false;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('=== SIGNING IN USER ===');
      developer.log('Email: $email');
      
      // Debug: Check Firebase Auth instance
      developer.log('Checking Firebase Auth instance...');
      developer.log('Firebase Auth instance: $_auth');
      developer.log('Firebase Auth app: ${_auth.app}');
      developer.log('Firebase Auth app name: ${_auth.app.name}');
      developer.log('Firebase Auth app options: ${_auth.app.options}');
      
      developer.log('Attempting to sign in with Firebase Auth...');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      developer.log('✅ User signed in successfully with Firebase Auth');
      
      // Update last active timestamp
      developer.log('Updating last active timestamp...');
      await _updateLastActive(credential.user!.uid);
      developer.log('✅ Last active timestamp updated');
      
      developer.log('User signed in successfully: ${credential.user!.email}');
      return credential;
    } catch (e) {
      developer.log('=== ERROR SIGNING IN ===');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Error message: $e');
      developer.log('Error toString: ${e.toString()}');
      
      // Check if it's a Firebase configuration error
      if (e.toString().contains('configuration') || e.toString().contains('config')) {
        developer.log('❌ This appears to be a Firebase configuration error!');
        developer.log('Firebase Auth instance details:');
        developer.log('  - Instance: $_auth');
        developer.log('  - App: ${_auth.app.name}');
        developer.log('  - App options: ${_auth.app.options}');
      }
      
      rethrow;
    }
  }

  /// Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      developer.log('=== CREATING USER ACCOUNT ===');
      developer.log('Email: $email');
      developer.log('Full Name: $fullName');
      
      // Debug: Check Firebase Auth instance
      developer.log('Checking Firebase Auth instance...');
      developer.log('Firebase Auth instance: $_auth');
      developer.log('Firebase Auth app: ${_auth.app}');
      developer.log('Firebase Auth app name: ${_auth.app.name}');
      developer.log('Firebase Auth app options: ${_auth.app.options}');
      
      // Debug: Check if we can access Firebase Auth methods
      developer.log('Checking Firebase Auth methods availability...');
      try {
        final currentUser = _auth.currentUser;
        developer.log('Current user: $currentUser');
      } catch (e) {
        developer.log('Error accessing current user: $e');
      }
      
      developer.log('Attempting to create user with Firebase Auth...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      developer.log('✅ User created successfully with Firebase Auth');

      // Create user profile in Firestore
      developer.log('Creating user profile in Firestore...');
      await _createUserProfile(
        uid: credential.user!.uid,
        email: email,
        fullName: fullName,
      );
      developer.log('✅ User profile created in Firestore');

      developer.log('User created successfully: ${credential.user!.email}');
      return credential;
    } catch (e) {
      developer.log('=== ERROR CREATING USER ===');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Error message: $e');
      developer.log('Error toString: ${e.toString()}');
      
      // Check if it's a Firebase configuration error
      if (e.toString().contains('configuration') || e.toString().contains('config')) {
        developer.log('❌ This appears to be a Firebase configuration error!');
        developer.log('Firebase Auth instance details:');
        developer.log('  - Instance: $_auth');
        developer.log('  - App: ${_auth.app.name}');
        developer.log('  - App options: ${_auth.app.options}');
      }
      
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('=== GOOGLE SIGN IN STARTED ===');
      
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        developer.log('Google Sign-In was cancelled by user');
        return null;
      }

      developer.log('Google Sign-In successful for: ${googleUser.email}');
      developer.log('Display name: ${googleUser.displayName}');
      developer.log('Photo URL: ${googleUser.photoUrl}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      developer.log('Google auth tokens obtained');
      developer.log('ID token: ${googleAuth.idToken != null ? 'Present' : 'Missing'}');
      developer.log('Access token: ${googleAuth.accessToken != null ? 'Present' : 'Missing'}');

      // Create a new credential for Firebase
      // For web, we need to pass both idToken and accessToken
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      developer.log('Firebase credential created, signing in...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      developer.log('✅ Firebase sign-in successful');
      developer.log('User UID: ${userCredential.user?.uid}');
      developer.log('User email: ${userCredential.user?.email}');

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        developer.log('New user detected, creating profile...');
        await _createUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          fullName: userCredential.user!.displayName ?? 'Unknown User',
        );
        
        // Update profile with Google photo if available
        if (googleUser.photoUrl != null) {
          await updateUserProfile(
            uid: userCredential.user!.uid,
            displayName: userCredential.user!.displayName,
            photoURL: googleUser.photoUrl,
          );
        }
      } else {
        developer.log('Existing user, updating last active...');
        await _updateLastActive(userCredential.user!.uid);
      }

      developer.log('✅ Google Sign-In completed successfully');
      return userCredential;

    } catch (e) {
      developer.log('=== GOOGLE SIGN IN ERROR ===');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Error message: $e');
      
      // Handle specific Google Sign-In errors
      if (e.toString().contains('network_error')) {
        developer.log('❌ Network error during Google Sign-In');
      } else if (e.toString().contains('popup_closed')) {
        developer.log('❌ Google Sign-In popup was closed');
      } else if (e.toString().contains('access_denied')) {
        developer.log('❌ Access denied by user');
      } else {
        developer.log('❌ Unexpected error during Google Sign-In');
      }
      
      rethrow;
    }
  }

  /// Sign out from Google Sign-In
  Future<void> signOutFromGoogle() async {
    try {
      developer.log('=== SIGNING OUT FROM GOOGLE ===');
      
      // Sign out from Google Sign-In
      await _googleSignIn.signOut();
      developer.log('✅ Signed out from Google Sign-In');
      
      // Sign out from Firebase
      await _auth.signOut();
      developer.log('✅ Signed out from Firebase');
      
    } catch (e) {
      developer.log('Error signing out from Google: $e');
      rethrow;
    }
  }

  /// Revoke Google Sign-In access
  Future<void> revokeGoogleSignInAccess() async {
    try {
      developer.log('=== REVOKING GOOGLE SIGN IN ACCESS ===');
      
      // Revoke access from Google
      await _googleSignIn.disconnect();
      developer.log('✅ Google Sign-In access revoked');
      
    } catch (e) {
      developer.log('Error revoking Google Sign-In access: $e');
      rethrow;
    }
  }

  /// Check if current user signed in with Google
  bool isCurrentUserFromGoogle() {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.providerData.any((userInfo) => userInfo.providerId == 'google.com');
  }

  /// Get Google Sign-In profile picture URL
  String? get googleSignInProfilePicture {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final googleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'google.com',
            orElse: () => throw StateError('No Google user info found'));
    
    return googleUserInfo.photoURL;
  }

  /// Get Google Sign-In display name
  String? get googleSignInDisplayName {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final googleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'google.com',
            orElse: () => throw StateError('No Google user info found'));
    
    return googleUserInfo.displayName;
  }

  /// Get Google Sign-In email
  String? get googleSignInEmail {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final googleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'google.com',
            orElse: () => throw StateError('No Google user info found'));
    
    return googleUserInfo.email;
  }

  /// Get Google Sign-In user ID
  String? get googleSignInId {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final googleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'google.com',
            orElse: () => throw StateError('No Google user info found'));
    
    return googleUserInfo.uid;
  }

  /// Check if current user signed in with Apple
  bool isCurrentUserFromApple() {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.providerData.any((userInfo) => userInfo.providerId == 'apple.com');
  }

  /// Get Apple Sign-In profile picture URL
  String? get appleSignInProfilePicture {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final appleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'apple.com',
            orElse: () => throw StateError('No Apple user info found'));
    
    return appleUserInfo.photoURL;
  }

  /// Get Apple Sign-In display name
  String? get appleSignInDisplayName {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final appleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'apple.com',
            orElse: () => throw StateError('No Apple user info found'));
    
    return appleUserInfo.displayName;
  }

  /// Get Apple Sign-In email
  String? get appleSignInEmail {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final appleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'apple.com',
            orElse: () => throw StateError('No Apple user info found'));
    
    return appleUserInfo.email;
  }

  /// Get Apple Sign-In user ID
  String? get appleSignInId {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final appleUserInfo = user.providerData
        .firstWhere((userInfo) => userInfo.providerId == 'apple.com',
            orElse: () => throw StateError('No Apple user info found'));
    
    return appleUserInfo.uid;
  }

  /// Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      developer.log('=== APPLE SIGN IN STARTED ===');
      
      // Apple Sign-In is not available in this version
      developer.log('❌ Apple Sign-In is not available on this platform');
      return null;
      
    } catch (e) {
      developer.log('❌ Error signing in with Apple: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      developer.log('=== AUTH SERVICE: Starting sign out ===');
      
      // Check if user is signed in with Google
      if (isCurrentUserFromGoogle()) {
        developer.log('User signed in with Google, signing out from Google...');
        await _googleSignIn.signOut();
        developer.log('✅ Signed out from Google Sign-In');
      }
      
      // Note: Apple Sign-In doesn't require explicit sign out
      // The user will need to sign out from their device settings
      
      // Sign out from Firebase
      developer.log('Signing out from Firebase...');
      await _auth.signOut();
      developer.log('✅ Signed out from Firebase');
      developer.log('User signed out successfully');
    } catch (e) {
      developer.log('=== AUTH SERVICE: ERROR during sign out ===');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Error message: $e');
      developer.log('Error toString: ${e.toString()}');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      developer.log('Password reset email sent to: $email');
    } catch (e) {
      developer.log('Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
      
      // Update Firestore profile
      await _firestore.collection('users').doc(uid).update({
        if (displayName != null) 'fullName': displayName,
        if (photoURL != null) 'profileImageUrl': photoURL,
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      developer.log('User profile updated successfully');
    } catch (e) {
      developer.log('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      developer.log('Error getting user profile: $e');
      return null;
    }
  }

  /// Get user's weight (kg) from Firestore preferences
  Future<double?> getUserWeightKg() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final prefs = data['preferences'] as Map<String, dynamic>?;
      final w = prefs != null ? prefs['weightKg'] : null;
      if (w == null) return null;
      return double.tryParse(w.toString());
    } catch (e) {
      developer.log('Error reading user weight: $e');
      return null;
    }
  }

  /// Update user's weight (kg) in Firestore preferences
  Future<void> setUserWeightKg(double weightKg) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await _firestore.collection('users').doc(uid).set({
        'preferences': {'weightKg': weightKg},
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('User weight updated to $weightKg kg');
    } catch (e) {
      developer.log('Error updating user weight: $e');
      rethrow;
    }
  }

  /// Get user's height (cm) from Firestore preferences
  Future<int?> getUserHeightCm() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final prefs = data['preferences'] as Map<String, dynamic>?;
      final h = prefs != null ? prefs['heightCm'] : null;
      if (h == null) return null;
      return int.tryParse(h.toString());
    } catch (e) {
      developer.log('Error reading user height: $e');
      return null;
    }
  }

  /// Update user's height (cm) in Firestore preferences
  Future<void> setUserHeightCm(int heightCm) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await _firestore.collection('users').doc(uid).set({
        'preferences': {'heightCm': heightCm},
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('User height updated to $heightCm cm');
    } catch (e) {
      developer.log('Error updating user height: $e');
      rethrow;
    }
  }

  /// Get user's age (years) from Firestore preferences
  Future<int?> getUserAgeYears() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final prefs = data['preferences'] as Map<String, dynamic>?;
      final a = prefs != null ? prefs['ageYears'] : null;
      if (a == null) return null;
      return int.tryParse(a.toString());
    } catch (e) {
      developer.log('Error reading user age: $e');
      return null;
    }
  }

  /// Update user's age (years) in Firestore preferences
  Future<void> setUserAgeYears(int ageYears) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await _firestore.collection('users').doc(uid).set({
        'preferences': {'ageYears': ageYears},
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('User age updated to $ageYears');
    } catch (e) {
      developer.log('Error updating user age: $e');
      rethrow;
    }
  }

  /// Get user's gender from Firestore preferences (female/male/nonBinary/preferNotToSay)
  Future<String?> getUserGender() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final prefs = data['preferences'] as Map<String, dynamic>?;
      final g = prefs != null ? prefs['gender'] : null;
      if (g == null) return null;
      return g.toString();
    } catch (e) {
      developer.log('Error reading user gender: $e');
      return null;
    }
  }

  /// Update user's gender in Firestore preferences
  Future<void> setUserGender(String gender) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await _firestore.collection('users').doc(uid).set({
        'preferences': {'gender': gender},
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      developer.log('User gender updated to $gender');
    } catch (e) {
      developer.log('Error updating user gender: $e');
      rethrow;
    }
  }

  /// Create user profile in Firestore
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    try {
      final userModel = UserModel(
        id: uid,
        email: email,
        fullName: fullName,
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userModel.toJson());
      developer.log('User profile created in Firestore');
    } catch (e) {
      developer.log('Error creating user profile in Firestore: $e');
      rethrow;
    }
  }

  /// Update last active timestamp
  Future<void> _updateLastActive(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Error updating last active: $e');
    }
  }

  /// Delete user account
  Future<void> deleteUserAccount() async {
    try {
      developer.log('=== DELETING USER ACCOUNT ===');
      final user = _auth.currentUser;
      if (user != null) {
        developer.log('User UID: ${user.uid}');
        developer.log('User email: ${user.email}');
        
        // Check if user is signed in with Google
        if (isCurrentUserFromGoogle()) {
          developer.log('User signed in with Google, revoking access...');
          try {
            await _googleSignIn.disconnect();
            developer.log('✅ Google Sign-In access revoked');
          } catch (e) {
            developer.log('Warning: Could not revoke Google Sign-In access: $e');
          }
        }
        
        // Delete user data from Firestore
        developer.log('Deleting user data from Firestore...');
        await _firestore.collection('users').doc(user.uid).delete();
        developer.log('✅ Firestore data deleted');
        
        // Delete user account from Firebase
        developer.log('Deleting user account from Firebase...');
        await user.delete();
        developer.log('✅ Firebase account deleted');
        
        developer.log('✅ User account deleted successfully');
      } else {
        developer.log('No current user found');
      }
    } catch (e) {
      developer.log('Error deleting user account: $e');
      rethrow;
    }
  }

  /// Create or update user profile in Firestore
  Future<void> _createOrUpdateUserProfile(
    User user,
    {
      String? displayName,
      String? email,
      String? provider,
    }
  ) async {
    try {
      final userData = <String, dynamic>{
        'lastActive': FieldValue.serverTimestamp(),
      };

      if (displayName != null && displayName.isNotEmpty) {
        userData['fullName'] = displayName;
      }
      if (email != null) {
        userData['email'] = email;
      }
      if (provider != null) {
        userData['provider'] = provider;
      }

      // Check if user profile exists
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (doc.exists) {
        // Update existing profile
        await docRef.update(userData);
        developer.log('User profile updated in Firestore');
      } else {
        // Create new profile
        userData['id'] = user.uid;
        userData['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(userData);
        developer.log('User profile created in Firestore');
      }
    } catch (e) {
      developer.log('Error creating/updating user profile: $e');
      rethrow;
    }
  }
}

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider for current user
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider for user profile
final userProfileProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserProfile(uid);
});
