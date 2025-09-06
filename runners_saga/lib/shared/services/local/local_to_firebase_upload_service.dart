import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_run_storage_service.dart';

/// Service for uploading locally saved run data to Firebase
/// This handles the upload process and manages file status
class LocalToFirebaseUploadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload all pending run files to Firebase
  static Future<Map<String, dynamic>> uploadAllPendingRuns() async {
    print('🚀 LocalToFirebaseUploadService: Starting upload of pending runs...');
    
          final results = <String, dynamic>{
        'totalFiles': 0,
        'successfulUploads': 0,
        'failedUploads': 0,
        'errors': <String>[],
      };

    try {
      // Get all pending run files
      final pendingFiles = await LocalRunStorageService.getPendingRunFiles();
      results['totalFiles'] = pendingFiles.length;

      if (pendingFiles.isEmpty) {
        print('📋 LocalToFirebaseUploadService: No pending runs to upload');
        return results;
      }

      print('📋 LocalToFirebaseUploadService: Found ${pendingFiles.length} pending runs');

      // Upload each file
      for (final file in pendingFiles) {
        try {
          final success = await _uploadSingleRun(file);
                  if (success) {
          results['successfulUploads'] = (results['successfulUploads'] as int) + 1;
          print('✅ LocalToFirebaseUploadService: Successfully uploaded ${file.path}');
        } else {
          results['failedUploads'] = (results['failedUploads'] as int) + 1;
          (results['errors'] as List<String>).add('Failed to upload ${file.path}');
          print('❌ LocalToFirebaseUploadService: Failed to upload ${file.path}');
        }
        } catch (e) {
          results['failedUploads'] = (results['failedUploads'] as int) + 1;
          (results['errors'] as List<String>).add('Error uploading ${file.path}: $e');
          print('❌ LocalToFirebaseUploadService: Error uploading ${file.path}: $e');
        }
      }

      print('📊 LocalToFirebaseUploadService: Upload complete - ${results['successfulUploads']}/${results['totalFiles']} successful');
      return results;
    } catch (e) {
      print('❌ LocalToFirebaseUploadService: Error in uploadAllPendingRuns: $e');
      (results['errors'] as List<String>).add('General error: $e');
      return results;
    }
  }

  /// Upload a single run file to Firebase
  static Future<bool> _uploadSingleRun(File file) async {
    try {
      // Load run data from file
      final runData = await LocalRunStorageService.loadRunData(file.path);
      if (runData == null) {
        print('⚠️ LocalToFirebaseUploadService: Could not load run data from ${file.path}');
        return false;
      }

      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ LocalToFirebaseUploadService: No authenticated user');
        return false;
      }

      // Convert GPS points back to the format expected by Firebase
      final gpsPoints = (runData['gpsPoints'] as List)
          .map((point) => {
                'latitude': point['latitude'],
                'longitude': point['longitude'],
                'accuracy': point['accuracy'],
                'altitude': point['altitude'],
                'heading': point['heading'],
                'speed': point['speed'],
                'timestamp': point['timestamp'],
              })
          .toList();

      // Create run document for Firebase
      final runDoc = {
        'userId': user.uid,
        'episodeId': runData['episodeId'],
        'runId': runData['runId'],
        'timestamp': Timestamp.fromDate(DateTime.parse(runData['timestamp'])),
        'duration': runData['duration'],
        'distance': runData['distance'],
        'gpsPoints': gpsPoints,
        'gpsPointCount': runData['gpsPointCount'],
        'status': 'completed',
        'source': 'local_upload', // Mark as uploaded from local storage
        'uploadedAt': Timestamp.now(),
        'additionalData': runData['additionalData'] ?? {},
        'version': runData['version'] ?? '1.0',
      };

      // Save to Firebase
      await _firestore
          .collection('runs')
          .doc(runData['runId'])
          .set(runDoc);

      // Mark local file as uploaded
      await LocalRunStorageService.markAsUploaded(file.path);

      print('✅ LocalToFirebaseUploadService: Successfully uploaded run ${runData['runId']}');
      return true;
    } catch (e) {
      print('❌ LocalToFirebaseUploadService: Error uploading single run: $e');
      return false;
    }
  }

  /// Upload a specific run by file path
  static Future<bool> uploadRunByPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ LocalToFirebaseUploadService: File does not exist: $filePath');
        return false;
      }

      return await _uploadSingleRun(file);
    } catch (e) {
      print('❌ LocalToFirebaseUploadService: Error uploading run by path: $e');
      return false;
    }
  }

  /// Create a Firebase run document from a local JSON file
  /// This is the main function to call after a local file is created
  static Future<Map<String, dynamic>> createFirebaseRunFromFile(String filePath) async {
    print('🚀 LocalToFirebaseUploadService: Creating Firebase run from file: $filePath');
    
    final result = {
      'success': false,
      'runId': null,
      'firebaseDocId': null,
      'error': null,
      'filePath': filePath,
    };

    try {
      // 1. Load the local JSON file
      final runData = await LocalRunStorageService.loadRunData(filePath);
      if (runData == null) {
        result['error'] = 'Could not load run data from file';
        print('❌ LocalToFirebaseUploadService: Could not load run data from $filePath');
        return result;
      }

      print('📖 LocalToFirebaseUploadService: Loaded run data for runId: ${runData['runId']}');

      // 2. Get current user
      final user = _auth.currentUser;
      if (user == null) {
        result['error'] = 'No authenticated user';
        print('⚠️ LocalToFirebaseUploadService: No authenticated user');
        return result;
      }

      // 3. Convert GPS points to Firebase format
      final gpsPoints = _convertGpsPointsForFirebase(runData['gpsPoints'] as List);
      print('📍 LocalToFirebaseUploadService: Converted ${gpsPoints.length} GPS points for Firebase');

      // 4. Create the Firebase run document
      final firebaseRunDoc = {
        'userId': user.uid,
        'episodeId': runData['episodeId'],
        'runId': runData['runId'],
        'timestamp': Timestamp.fromDate(DateTime.parse(runData['timestamp'])),
        'duration': runData['duration'],
        'distance': runData['distance'],
        'gpsPoints': gpsPoints,
        'gpsPointCount': runData['gpsPointCount'],
        'status': 'completed',
        'source': 'local_upload',
        'uploadedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'additionalData': runData['additionalData'] ?? {},
        'version': runData['version'] ?? '1.0',
        'deviceInfo': {
          'platform': 'mobile',
          'appVersion': runData['additionalData']?['appVersion'] ?? '1.0.0',
          'uploadMethod': 'immediate_upload',
        },
      };

      // 5. Save to Firebase Firestore
      final runId = runData['runId'] as String;
      await _firestore
          .collection('runs')
          .doc(runId)
          .set(firebaseRunDoc);

      print('✅ LocalToFirebaseUploadService: Successfully created Firebase run document: $runId');

      // 6. Mark local file as uploaded
      await LocalRunStorageService.markAsUploaded(filePath);
      print('✅ LocalToFirebaseUploadService: Marked local file as uploaded');

      // 7. Update result
      result['success'] = true;
      result['runId'] = runId;
      result['firebaseDocId'] = runId;
      result['gpsPointCount'] = gpsPoints.length;
      result['distance'] = runData['distance'];
      result['duration'] = runData['duration'];

      print('🎉 LocalToFirebaseUploadService: Firebase run creation completed successfully');
      return result;

    } catch (e) {
      result['error'] = e.toString();
      print('❌ LocalToFirebaseUploadService: Error creating Firebase run: $e');
      return result;
    }
  }

  /// Convert GPS points from local JSON format to Firebase format
  static List<Map<String, dynamic>> _convertGpsPointsForFirebase(List<dynamic> localGpsPoints) {
    return localGpsPoints.map((point) {
      final pointMap = point as Map<String, dynamic>;
      return {
        'latitude': pointMap['latitude'],
        'longitude': pointMap['longitude'],
        'accuracy': pointMap['accuracy'],
        'altitude': pointMap['altitude'],
        'heading': pointMap['heading'],
        'speed': pointMap['speed'],
        'speedAccuracy': pointMap['speedAccuracy'],
        'altitudeAccuracy': pointMap['altitudeAccuracy'],
        'headingAccuracy': pointMap['headingAccuracy'],
        'timestamp': pointMap['timestamp'],
        'createdAt': Timestamp.now(),
      };
    }).toList();
  }

  /// Clean up uploaded files (delete local files after successful upload)
  static Future<void> cleanupUploadedFiles() async {
    try {
      // Get all pending files and check their status
      final pendingFiles = await LocalRunStorageService.getPendingRunFiles();
      
      for (final file in pendingFiles) {
        final runData = await LocalRunStorageService.loadRunData(file.path);
        if (runData != null && runData['status'] == 'uploaded') {
          await LocalRunStorageService.deleteRunFile(file.path);
        }
      }

      print('🧹 LocalToFirebaseUploadService: Cleaned up uploaded files');
    } catch (e) {
      print('❌ LocalToFirebaseUploadService: Error cleaning up files: $e');
    }
  }

  /// Get upload statistics
  static Future<Map<String, dynamic>> getUploadStats() async {
    try {
      final storageStats = await LocalRunStorageService.getStorageStats();
      return {
        'localStorage': storageStats,
        'lastUploadAttempt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ LocalToFirebaseUploadService: Error getting upload stats: $e');
      return {
        'localStorage': {'totalFiles': 0, 'pendingUpload': 0, 'uploaded': 0},
        'lastUploadAttempt': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }
}
