import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/run_model.dart';

class FirestoreService {
  static const String _runsCollection = 'runs';
  static const String _usersCollection = 'users';
  
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  
  // Lazy initialization to ensure Firebase is ready
  FirebaseFirestore get _firestoreInstance {
    try {
      _firestore ??= FirebaseFirestore.instance;
      print('✅ FirestoreService: Firestore instance ready');
      return _firestore!;
    } catch (e) {
      print('❌ FirestoreService: Firebase not initialized yet. Please wait for app startup to complete.');
      throw Exception('Firebase not initialized yet. Please wait for app startup to complete.');
    }
  }
  
  FirebaseAuth get _authInstance {
    try {
      _auth ??= FirebaseAuth.instance;
      print('✅ FirestoreService: Firebase Auth instance ready');
      return _auth!;
    } catch (e) {
      print('❌ FirestoreService: Firebase not initialized yet. Please wait for app startup to complete.');
      throw Exception('Firebase not initialized yet. Please wait for app startup to complete.');
    }
  }
  
  // Get current user ID
  String? get currentUserId => _authInstance.currentUser?.uid;
  
  // Helper method to safely convert document data
  Map<String, dynamic> _convertDocData(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) {
      print('⚠️ FirestoreService: Document ${doc.id} has no data');
      throw Exception('Document ${doc.id} has no data');
    }
    
    if (data is! Map<String, dynamic>) {
      print('⚠️ FirestoreService: Document ${doc.id} data is not a Map: ${data.runtimeType}');
      throw Exception('Document ${doc.id} data is not in expected format');
    }
    
    return data;
  }
  
  // Save a new run to Firestore
  Future<String> saveRun(RunModel run) async {
    try {
      print('💾 FirestoreService.saveRun: Starting save process...');
      
      // Check Firebase Auth instance
      print('💾 FirestoreService.saveRun: Firebase Auth instance: ${_authInstance}');
      print('💾 FirestoreService.saveRun: Firebase Auth app: ${_authInstance.app}');
      
      final userId = currentUserId;
      print('💾 FirestoreService.saveRun: currentUserId = $userId');
      
      // Additional authentication debugging
      try {
        final currentUser = _authInstance.currentUser;
        print('💾 FirestoreService.saveRun: _authInstance.currentUser: ${currentUser?.uid}');
        print('💾 FirestoreService.saveRun: User authenticated: ${currentUser != null}');
        print('💾 FirestoreService.saveRun: User email: ${currentUser?.email}');
        print('💾 FirestoreService.saveRun: User display name: ${currentUser?.displayName}');
      } catch (e) {
        print('❌ FirestoreService.saveRun: Error accessing currentUser: $e');
      }
      
      if (userId == null) {
        print('❌ FirestoreService.saveRun: User not authenticated');
        throw Exception('User not authenticated');
      }
      
      // Convert run to Firestore-compatible JSON
      print('💾 FirestoreService.saveRun: Converting run to Firestore JSON...');
      final runData = run.toFirestore();
      print('💾 FirestoreService.saveRun: Firestore JSON conversion successful, ${runData.keys.length} keys');
      
      // Add metadata - createdAt is already set by the model
      runData['updatedAt'] = FieldValue.serverTimestamp();
      runData['userId'] = userId; // Ensure userId is included
      
      print('💾 FirestoreService.saveRun: Timestamps - createdAt: ${runData['createdAt']}');
      
      // Save to Firestore - using top-level runs collection for easier querying
      print('💾 FirestoreService.saveRun: Saving to main runs collection...');
      final docRef = await _firestoreInstance
          .collection(_runsCollection)
          .add(runData);
      print('✅ FirestoreService.saveRun: Saved to main collection with ID: ${docRef.id}');
      
      // Only save to main runs collection - no user subcollections needed
      print('✅ FirestoreService.saveRun: Run saved to main collection only');
      
      return docRef.id;
    } catch (e) {
      print('❌ FirestoreService.saveRun: Error occurred: $e');
      print('❌ FirestoreService.saveRun: Error type: ${e.runtimeType}');
      print('❌ FirestoreService.saveRun: Stack trace: ${StackTrace.current}');
      throw Exception('Failed to save run: $e');
    }
  }
  
  // Update an existing run
  Future<void> updateRun(String runId, RunModel run) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final runData = run.toFirestore();
      runData['updatedAt'] = FieldValue.serverTimestamp();
      runData['userId'] = userId; // Ensure userId is included
      
      // Update only in top-level runs collection
      await _firestoreInstance.collection(_runsCollection).doc(runId).update(runData);
    } catch (e) {
      throw Exception('Failed to update run: $e');
    }
  }
  
  // Complete a run with final statistics
  Future<void> completeRun(String runId, RunModel completedRun) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Ensure the run has all required completion data
      if (completedRun.status != RunStatus.completed) {
        throw Exception('Run must be marked as completed');
      }
      
      if (completedRun.completedAt == null) {
        throw Exception('Run must have a completion time');
      }
      
      final runData = completedRun.toFirestore();
      runData['updatedAt'] = FieldValue.serverTimestamp();
      // completedAt is already set by the model
      runData['userId'] = userId;
      
      print('💾 FirestoreService.completeRun: Timestamps - completedAt: ${runData['completedAt']}');
      
      // Add completion metadata
      runData['totalPoints'] = completedRun.route?.length ?? 0;
      runData['finalDistance'] = completedRun.totalDistance ?? 0.0;
      runData['finalTime'] = completedRun.totalTime?.inSeconds ?? 0;
      runData['finalPace'] = completedRun.averagePace ?? 0.0;
      
      // Add new run statistics fields
      runData['elevationGain'] = completedRun.elevationGain ?? 0.0;
      runData['maxSpeed'] = completedRun.maxSpeed ?? 0.0;
      runData['avgHeartRate'] = completedRun.avgHeartRate ?? 0.0;
      runData['caloriesBurned'] = completedRun.caloriesBurned ?? 0.0;
      
      // Update only in top-level runs collection
      await _firestoreInstance.collection(_runsCollection).doc(runId).update(runData);
    } catch (e) {
      throw Exception('Failed to complete run: $e');
    }
  }
  
  // Get a specific run by ID
  Future<RunModel?> getRun(String runId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Try to get from top-level collection first
      final doc = await _firestoreInstance
          .collection(_runsCollection)
          .doc(runId)
          .get();
      
      if (doc.exists) {
        final data = _convertDocData(doc);
        // Verify the run belongs to the current user
        if (data['userId'] == userId) {
          return RunModel.fromJson({
            ...data,
            'id': doc.id,
          });
        }
      }
      
      return null;
    } catch (e) {
      throw Exception('Failed to get run: $e');
    }
  }
  
  // Get all runs for the current user
  Future<List<RunModel>> getUserRuns({
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      Query query = _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          // Temporarily removed orderBy to avoid index requirement
          // .orderBy('createdAt', descending: true)
          .limit(limit);
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) => RunModel.fromJson({
                ..._convertDocData(doc),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user runs: $e');
    }
  }
  
        // Get runs by status
      Future<List<RunModel>> getRunsByStatus(RunStatus status, {int limit = 100}) async {
        try {
          final userId = currentUserId;
          if (userId == null) {
            throw Exception('User not authenticated');
          }
          
          // For completed runs, also check completedAt field
          Query query = _firestoreInstance
              .collection(_runsCollection)
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: status.name);
          
          // Order by createdAt for most runs, but for completed runs also consider completedAt
          if (status == RunStatus.completed) {
            // Try to order by completedAt first, fallback to createdAt
            try {
              query = query.orderBy('completedAt', descending: true);
            } catch (e) {
              print('⚠️ FirestoreService: Could not order by completedAt, using createdAt: $e');
              query = query.orderBy('createdAt', descending: true);
            }
          } else {
            query = query.orderBy('createdAt', descending: true);
          }
          
          final querySnapshot = await query.limit(limit).get();
          
          return querySnapshot.docs
              .map((doc) => RunModel.fromJson({
                    ..._convertDocData(doc),
                    'id': doc.id,
                  }))
              .toList();
        } catch (e) {
          throw Exception('Failed to get runs by status: $e');
        }
      }
  
  // Get runs by season
  Future<List<RunModel>> getRunsBySeason(String seasonId, {int limit = 100}) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final querySnapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .where('episodeId', isEqualTo: seasonId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => RunModel.fromJson({
                ..._convertDocData(doc),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get runs by season: $e');
    }
  }
  
  // Get runs by mission
  Future<List<RunModel>> getRunsByMission(String missionId, {int limit = 100}) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final querySnapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .where('episodeId', isEqualTo: missionId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => RunModel.fromJson({
                ..._convertDocData(doc),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get runs by mission: $e');
    }
  }
  
  // Get completed runs only
  Future<List<RunModel>> getCompletedRuns({int limit = 100}) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final querySnapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: RunStatus.completed.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => RunModel.fromJson({
                ..._convertDocData(doc),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get completed runs: $e');
    }
  }
  
  // Delete a run
  Future<void> deleteRun(String runId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Delete from both collections
      final batch = _firestoreInstance.batch();
      
      final runDocRef = _firestoreInstance.collection(_runsCollection).doc(runId);
      batch.delete(runDocRef);
      
      final userRunDocRef = _firestoreInstance
          .collection(_usersCollection)
          .doc(userId)
          .collection(_runsCollection)
          .doc(runId);
      batch.delete(userRunDocRef);
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete run: $e');
    }
  }
  
  // Get run statistics for the current user
  Future<Map<String, dynamic>> getUserRunStats() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final querySnapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: RunStatus.completed.name)
          .get();
      
      final completedRuns = querySnapshot.docs
          .map((doc) => RunModel.fromJson(_convertDocData(doc)))
          .toList();
      
      if (completedRuns.isEmpty) {
        return {
          'totalRuns': 0,
          'totalDistance': 0.0,
          'totalTime': Duration.zero,
          'averagePace': 0.0,
          'bestPace': 0.0,
          'longestRun': 0.0,
          'totalPoints': 0,
        };
      }
      
      double totalDistance = 0.0;
      Duration totalTime = Duration.zero;
      double totalPace = 0.0;
      double bestPace = double.infinity;
      double longestRun = 0.0;
      int totalPoints = 0;
      
      for (final run in completedRuns) {
        totalDistance += run.totalDistance ?? 0.0;
        totalTime += run.totalTime ?? Duration.zero;
        totalPace += run.averagePace ?? 0.0;
        totalPoints += run.route?.length ?? 0;
        
        if ((run.averagePace ?? 0) > 0 && (run.averagePace ?? 0) < bestPace) {
          bestPace = run.averagePace ?? 0;
        }
        
        if ((run.totalDistance ?? 0) > longestRun) {
          longestRun = run.totalDistance ?? 0;
        }
      }
      
      final averagePace = totalPace / completedRuns.length;
      
      return {
        'totalRuns': completedRuns.length,
        'totalDistance': totalDistance,
        'totalTime': totalTime,
        'averagePace': averagePace,
        'bestPace': bestPace == double.infinity ? 0.0 : bestPace,
        'longestRun': longestRun,
        'totalPoints': totalPoints,
      };
    } catch (e) {
      throw Exception('Failed to get user run stats: $e');
    }
  }

  /// Add an entry to user_progress for high-level progress tracking
  Future<void> addUserProgress({
    required String episodeId,
    required String episodeTitle,
    required Duration elapsedTime,
    required double targetDistance,
    required Duration targetTime,
    required double actualDistance,
    required String status,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      final payload = {
        'userId': userId,
        'episodeId': episodeId,
        'episodeTitle': episodeTitle,
        'completedAt': FieldValue.serverTimestamp(),
        'elapsedTime': elapsedTime.inSeconds,
        'targetDistance': targetDistance,
        'targetTime': targetTime.inSeconds,
        'actualDistance': actualDistance,
        'status': status,
      };

      // Write to top-level user_progress
      await _firestoreInstance.collection('user_progress').add(payload);

      // Mirror to nested user document as well
      await _firestoreInstance
          .collection(_usersCollection)
          .doc(userId)
          .collection('user_progress')
          .add(payload);
    } catch (e) {
      throw Exception('Failed to add user progress: $e');
    }
  }
  
  // Stream of user runs for real-time updates
  // Note: Requires composite index: userId (ascending) + createdAt (descending)
  Stream<List<RunModel>> getUserRunsStream({int limit = 100}) {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      return _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final validRuns = <RunModel>[];
            
            for (final doc in snapshot.docs) {
              try {
                final runData = _convertDocData(doc);
                final run = RunModel.fromJson({
                  ...runData,
                  'id': doc.id,
                });
                validRuns.add(run);
              } catch (e) {
                print('⚠️ FirestoreService: Skipping invalid run document ${doc.id}: $e');
                // Continue processing other documents instead of failing completely
                continue;
              }
            }
            
            // Already sorted by createdAt from the query
            return validRuns;
          });
    } catch (e) {
      final userId = currentUserId ?? 'unknown';
      print('❌ FirestoreService: Error in getUserRunsStream: $e');
      print('🔍 INDEX ERROR DETAILS:');
      print('   Query: userId == "$userId" ORDER BY createdAt DESC');
      print('   Required Index: Collection "runs", Fields: userId (Ascending), createdAt (Descending)');
      print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
      print('   Error: $e');
      throw Exception('Failed to get user runs stream: $e');
    }
  }
  
  // Stream of runs with completedAt field (completed runs)
  // Note: Requires composite index: userId (ascending) + completedAt (ascending) + createdAt (descending)
  Stream<List<RunModel>> getCompletedRunsStream({int limit = 100}) {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // First try to query by completedAt field (most accurate)
      try {
        return _firestoreInstance
            .collection(_runsCollection)
            .where('userId', isEqualTo: userId)
            .where('completedAt', isGreaterThan: null) // Only runs with completedAt field
            .orderBy('completedAt', descending: true)
            .limit(limit)
            .snapshots()
            .map((snapshot) {
              final validRuns = <RunModel>[];
              
              for (final doc in snapshot.docs) {
                try {
                  final runData = _convertDocData(doc);
                  
                  // Debug: Print the data structure to see what fields are missing/null
                  print('🔍 FirestoreService: Document ${doc.id} data keys: ${runData.keys.toList()}');
                  print('🔍 FirestoreService: Document ${doc.id} totalDistance: ${runData['totalDistance']} (type: ${runData['totalDistance']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} totalTime: ${runData['totalTime']} (type: ${runData['totalTime']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} averagePace: ${runData['averagePace']} (type: ${runData['averagePace']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} maxPace: ${runData['maxPace']} (type: ${runData['maxPace']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} minPace: ${runData['minPace']} (type: ${runData['minPace']?.runtimeType})');
                  
                  final run = RunModel.fromJson({
                    ...runData,
                    'id': doc.id,
                  });
                  validRuns.add(run);
                } catch (e) {
                  print('⚠️ FirestoreService: Skipping invalid completed run document ${doc.id}: $e');
                  print('⚠️ FirestoreService: Document ${doc.id} raw data: ${doc.data()}');
                  // Continue processing other documents instead of failing completely
                  continue;
                }
              }
              
              // Sort by completedAt (most recent first)
              validRuns.sort((a, b) {
                              // Since completedAt is the actual field, we can use it for sorting
              final aCompletedAt = a.completedAt;
              final bCompletedAt = b.completedAt;
                if (aCompletedAt == null && bCompletedAt == null) return 0;
                if (aCompletedAt == null) return 1;
                if (bCompletedAt == null) return -1;
                return bCompletedAt.compareTo(aCompletedAt);
              });
              
              return validRuns;
            });
      } catch (e) {
        print('⚠️ FirestoreService: Could not query by completedAt, falling back to status: $e');
        print('🔍 INDEX ERROR DETAILS:');
        print('   Query: userId == "$userId" AND completedAt > null ORDER BY completedAt DESC');
        print('   Required Index: Collection "runs", Fields: userId (Ascending), completedAt (Descending)');
        print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
        print('   Error: $e');
        
        // Fallback: query by status for backward compatibility
        return _firestoreInstance
            .collection(_runsCollection)
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: RunStatus.completed.name)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .snapshots()
            .map((snapshot) {
              final validRuns = <RunModel>[];
              
              for (final doc in snapshot.docs) {
                try {
                  final runData = _convertDocData(doc);
                  
                  // Debug: Print the data structure to see what fields are missing/null
                  print('🔍 FirestoreService: Document ${doc.id} data keys: ${runData.keys.toList()}');
                  print('🔍 FirestoreService: Document ${doc.id} totalDistance: ${runData['totalDistance']} (type: ${runData['totalDistance']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} totalTime: ${runData['totalTime']} (type: ${runData['totalTime']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} averagePace: ${runData['averagePace']} (type: ${runData['averagePace']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} maxPace: ${runData['maxPace']} (type: ${runData['maxPace']?.runtimeType})');
                  print('🔍 FirestoreService: Document ${doc.id} minPace: ${runData['minPace']} (type: ${runData['minPace']?.runtimeType})');
                  
                  final run = RunModel.fromJson(runData);
                  validRuns.add(run);
                } catch (e) {
                  print('⚠️ FirestoreService: Skipping invalid completed run document ${doc.id}: $e');
                  print('⚠️ FirestoreService: Document ${doc.id} raw data: ${doc.data()}');
                  // Continue processing other documents instead of failing completely
                  continue;
                }
              }
              
              // Sort by createdAt as fallback
              validRuns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return validRuns;
            });
      }
    } catch (e) {
      final userId = currentUserId ?? 'unknown';
      print('❌ FirestoreService: Error in getCompletedRunsStream: $e');
      print('🔍 INDEX ERROR DETAILS:');
      print('   Query: userId == "$userId" AND completedAt > null ORDER BY completedAt DESC');
      print('   Required Index: Collection "runs", Fields: userId (Ascending), completedAt (Descending)');
      print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
      print('   Error: $e');
      throw Exception('Failed to get completed runs stream: $e');
    }
  }
  
  /// Clear Firestore cache and force fresh data fetch
  Future<void> clearCache() async {
    try {
      print('🧹 FirestoreService: Clearing cache...');
      
      // Try to clear Firestore cache (may fail if indexes are missing)
      try {
        await _firestoreInstance.clearPersistence();
        print('🧹 FirestoreService: Persistence cleared');
      } catch (e) {
        print('⚠️ FirestoreService: Could not clear persistence (indexes may be missing): $e');
        // Continue with other cache clearing methods
      }
      
      // Force a fresh connection
      await _firestoreInstance.enableNetwork();
      print('🧹 FirestoreService: Network re-enabled');
      
      print('✅ FirestoreService: Cache cleared successfully');
    } catch (e) {
      print('❌ FirestoreService: Error clearing cache: $e');
      // Don't throw - cache clearing is not critical
    }
  }
  
  /// Force refresh of runs data by clearing cache and re-fetching
  Future<List<RunModel>> forceRefreshRuns({int limit = 100}) async {
    try {
      print('🔄 FirestoreService: Force refreshing runs...');
      
      // Clear cache first
      await clearCache();
      
      // Get fresh data
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final snapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.server));
      
      final validRuns = <RunModel>[];
      
      for (final doc in snapshot.docs) {
        try {
          final runData = _convertDocData(doc);
          final run = RunModel.fromJson({
            ...runData,
            'id': doc.id,
          });
          validRuns.add(run);
        } catch (e) {
          print('⚠️ FirestoreService: Skipping invalid run document ${doc.id}: $e');
          continue;
        }
      }
      
      print('✅ FirestoreService: Force refresh completed - ${validRuns.length} runs loaded');
      return validRuns;
    } catch (e) {
      final userId = currentUserId ?? 'unknown';
      print('❌ FirestoreService: Error in force refresh: $e');
      print('🔍 INDEX ERROR DETAILS:');
      print('   Query: userId == "$userId" ORDER BY createdAt DESC');
      print('   Required Index: Collection "runs", Fields: userId (Ascending), createdAt (Descending)');
      print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
      print('   Error: $e');
      throw Exception('Failed to force refresh runs: $e');
    }
  }
  
  /// Fix timestamp format for existing runs (migration helper)
  Future<Map<String, dynamic>> fixTimestampFormats() async {
    try {
      print('🔧 FirestoreService: Starting timestamp format fix...');
      
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get all runs for the user
      final snapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      int fixedCount = 0;
      int totalRuns = snapshot.docs.length;
      int stringTimestamps = 0;
      int validTimestamps = 0;
      final batch = _firestoreInstance.batch();
      final errors = <String>[];
      
      print('🔧 FirestoreService: Found $totalRuns total runs to check');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final completedAt = data['completedAt'];
        
        // Fix createdAt field
        if (createdAt != null) {
          if (createdAt is String) {
            stringTimestamps++;
            if (createdAt.contains('T')) {
              try {
                // Parse the ISO string and convert to Timestamp
                final dateTime = DateTime.parse(createdAt);
                final timestamp = Timestamp.fromDate(dateTime);
                
                // Update the document
                final docRef = _firestoreInstance.collection(_runsCollection).doc(doc.id);
                batch.update(docRef, {'createdAt': timestamp});
                fixedCount++;
                
                print('🔧 FirestoreService: Fixed createdAt timestamp for run ${doc.id}: $createdAt -> ${timestamp.toDate()}');
              } catch (e) {
                final error = 'Failed to fix createdAt timestamp for run ${doc.id}: $e';
                print('⚠️ FirestoreService: $error');
                errors.add(error);
              }
            } else {
              print('🔍 FirestoreService: Run ${doc.id} has non-ISO createdAt string: $createdAt');
            }
          } else if (createdAt is Timestamp) {
            validTimestamps++;
            print('✅ FirestoreService: Run ${doc.id} already has valid createdAt Timestamp');
          } else {
            print('⚠️ FirestoreService: Run ${doc.id} has unknown createdAt type: ${createdAt.runtimeType}');
          }
        } else {
          print('⚠️ FirestoreService: Run ${doc.id} has no createdAt field');
        }
        
        // Fix completedAt field
        if (completedAt != null) {
          if (completedAt is String) {
            stringTimestamps++;
            if (completedAt.contains('T')) {
              try {
                // Parse the ISO string and convert to Timestamp
                final dateTime = DateTime.parse(completedAt);
                final timestamp = Timestamp.fromDate(dateTime);
                
                // Update the document
                final docRef = _firestoreInstance.collection(_runsCollection).doc(doc.id);
                batch.update(docRef, {'completedAt': timestamp});
                fixedCount++;
                
                print('🔧 FirestoreService: Fixed completedAt timestamp for run ${doc.id}: $completedAt -> ${timestamp.toDate()}');
              } catch (e) {
                final error = 'Failed to fix completedAt timestamp for run ${doc.id}: $e';
                print('⚠️ FirestoreService: $error');
                errors.add(error);
              }
            } else {
              print('🔍 FirestoreService: Run ${doc.id} has non-ISO completedAt string: $completedAt');
            }
          } else if (completedAt is Timestamp) {
            validTimestamps++;
            print('✅ FirestoreService: Run ${doc.id} already has valid completedAt Timestamp');
          } else {
            print('⚠️ FirestoreService: Run ${doc.id} has unknown completedAt type: ${completedAt.runtimeType}');
          }
        }
      }
      
      print('🔧 FirestoreService: Summary - Total: $totalRuns, String: $stringTimestamps, Valid: $validTimestamps, Fixed: $fixedCount');
      
      if (fixedCount > 0) {
        await batch.commit();
        print('✅ FirestoreService: Successfully fixed $fixedCount timestamp formats');
        
        // Force a cache refresh to ensure the fixed data is loaded
        try {
          await _firestoreInstance.enableNetwork();
          print('🔄 FirestoreService: Network refreshed after timestamp fix');
        } catch (e) {
          print('⚠️ FirestoreService: Could not refresh network: $e');
        }
      } else {
        print('✅ FirestoreService: No timestamp formats need fixing');
      }
      
      return {
        'totalRuns': totalRuns,
        'stringTimestamps': stringTimestamps,
        'validTimestamps': validTimestamps,
        'fixedCount': fixedCount,
        'errors': errors,
      };
    } catch (e) {
      print('❌ FirestoreService: Error fixing timestamp formats: $e');
      throw Exception('Failed to fix timestamp formats: $e');
    }
  }

  /// Force update all run timestamps to proper Firestore format
  Future<Map<String, dynamic>> forceUpdateAllTimestamps() async {
    try {
      print('🔧 FirestoreService: Force updating all timestamps...');
      
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get all runs for the user
      final snapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      int updatedCount = 0;
      int totalRuns = snapshot.docs.length;
      final batch = _firestoreInstance.batch();
      final errors = <String>[];
      
      print('🔧 FirestoreService: Found $totalRuns total runs to update');
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final createdAt = data['createdAt'];
          final completedAt = data['completedAt'];
          
          // Update createdAt field
          if (createdAt != null) {
            Timestamp? newCreatedAt;
            
            if (createdAt is String) {
              // Parse ISO string
              try {
                final dateTime = DateTime.parse(createdAt);
                newCreatedAt = Timestamp.fromDate(dateTime);
                print('🔧 FirestoreService: Converting createdAt string to timestamp: $createdAt -> ${newCreatedAt.toDate()}');
              } catch (e) {
                final error = 'Failed to parse createdAt string timestamp for run ${doc.id}: $e';
                print('⚠️ FirestoreService: $error');
                errors.add(error);
                continue;
              }
            } else if (createdAt is Timestamp) {
              // Already a timestamp, but let's ensure it's properly formatted
              newCreatedAt = createdAt;
              print('✅ FirestoreService: Run ${doc.id} already has valid createdAt Timestamp');
            } else {
              print('⚠️ FirestoreService: Run ${doc.id} has unknown createdAt type: ${createdAt.runtimeType}');
              continue;
            }
            
            // Update the document with the proper timestamp
            final docRef = _firestoreInstance.collection(_runsCollection).doc(doc.id);
            batch.update(docRef, {'createdAt': newCreatedAt});
            updatedCount++;
          } else {
            print('⚠️ FirestoreService: Run ${doc.id} has no createdAt field');
          }
          
          // Update completedAt field
          if (completedAt != null) {
            Timestamp? newCompletedAt;
            
            if (completedAt is String) {
              // Parse ISO string
              try {
                final dateTime = DateTime.parse(completedAt);
                newCompletedAt = Timestamp.fromDate(dateTime);
                print('🔧 FirestoreService: Converting completedAt string to timestamp: $completedAt -> ${newCompletedAt.toDate()}');
              } catch (e) {
                final error = 'Failed to parse completedAt string timestamp for run ${doc.id}: $e';
                print('⚠️ FirestoreService: $error');
                errors.add(error);
                continue;
              }
            } else if (completedAt is Timestamp) {
              // Already a timestamp, but let's ensure it's properly formatted
              newCompletedAt = completedAt;
              print('✅ FirestoreService: Run ${doc.id} already has valid completedAt Timestamp');
            } else {
              print('⚠️ FirestoreService: Run ${doc.id} has unknown completedAt type: ${completedAt.runtimeType}');
              continue;
            }
            
            // Update the document with the proper timestamp
            final docRef = _firestoreInstance.collection(_runsCollection).doc(doc.id);
            batch.update(docRef, {'completedAt': newCompletedAt});
            updatedCount++;
          }
          
        } catch (e) {
          final error = 'Error processing run ${doc.id}: $e';
          print('⚠️ FirestoreService: $error');
          errors.add(error);
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        print('✅ FirestoreService: Successfully updated $updatedCount timestamp formats');
        
        // Force a cache refresh
        try {
          await _firestoreInstance.enableNetwork();
          print('🔄 FirestoreService: Network refreshed after timestamp updates');
        } catch (e) {
          print('⚠️ FirestoreService: Could not refresh network: $e');
        }
      } else {
        print('✅ FirestoreService: No timestamps needed updating');
      }
      
      return {
        'totalRuns': totalRuns,
        'updatedCount': updatedCount,
        'errors': errors,
      };
    } catch (e) {
      print('❌ FirestoreService: Error force updating timestamps: $e');
      throw Exception('Failed to force update timestamps: $e');
    }
  }

  /// Test all required indexes and show detailed error information
  Future<void> testIndexes() async {
    try {
      print('🔍 FirestoreService: Testing all required indexes...');
      final userId = currentUserId;
      if (userId == null) {
        print('❌ Cannot test indexes: User not authenticated');
        return;
      }
      
      print('🔍 Testing Index 1: userId + createdAt (for getUserRunsStream)');
      try {
        await _firestoreInstance
            .collection(_runsCollection)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.server));
        print('✅ Index 1 PASSED: userId + createdAt');
      } catch (e) {
        print('❌ Index 1 FAILED: userId + createdAt');
        print('   Required Index: Collection "runs", Fields: userId (Ascending), createdAt (Descending)');
        print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
        print('   Error: $e');
      }
      
      print('🔍 Testing Index 2: userId + completedAt (for getCompletedRunsStream)');
      try {
        await _firestoreInstance
            .collection(_runsCollection)
            .where('userId', isEqualTo: userId)
            .where('completedAt', isGreaterThan: null)
            .orderBy('completedAt', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.server));
        print('✅ Index 2 PASSED: userId + completedAt');
      } catch (e) {
        print('❌ Index 2 FAILED: userId + completedAt');
        print('   Required Index: Collection "runs", Fields: userId (Ascending), completedAt (Descending)');
        print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
        print('   Error: $e');
      }
      
      print('🔍 Testing Index 3: userId + status + createdAt (fallback for getCompletedRunsStream)');
      try {
        await _firestoreInstance
            .collection(_runsCollection)
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.server));
        print('✅ Index 3 PASSED: userId + status + createdAt');
      } catch (e) {
        print('❌ Index 3 FAILED: userId + status + createdAt');
        print('   Required Index: Collection "runs", Fields: userId (Ascending), status (Ascending), createdAt (Descending)');
        print('   Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
        print('   Error: $e');
      }
      
      print('🔍 Index testing completed. Check the errors above to see which indexes need to be created.');
    } catch (e) {
      print('❌ Error testing indexes: $e');
    }
  }

  /// Get runs with server-only source (bypasses cache)
  /// Note: This method forces a fresh fetch by clearing cache first
  Future<List<RunModel>> getRunsFromServer({int limit = 100}) async {
    try {
      print('🔄 FirestoreService: Getting runs from server...');
      
      // Clear cache first to ensure fresh data
      await clearCache();
      
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final snapshot = await _firestoreInstance
          .collection(_runsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.server));
      
      final validRuns = <RunModel>[];
      
      for (final doc in snapshot.docs) {
        try {
          final runData = _convertDocData(doc);
          final run = RunModel.fromJson({
            ...runData,
            'id': doc.id,
          });
          validRuns.add(run);
        } catch (e) {
          print('⚠️ FirestoreService: Skipping invalid run document ${doc.id}: $e');
          continue;
        }
      }
      
      print('✅ FirestoreService: Server fetch completed - ${validRuns.length} runs loaded');
      return validRuns;
    } catch (e) {
      print('❌ FirestoreService: Error in getRunsFromServer: $e');
      throw Exception('Failed to get runs from server: $e');
    }
  }
}
