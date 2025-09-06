import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

/// Service for saving run data locally as JSON files
/// This allows for offline storage and later upload to Firebase
class LocalRunStorageService {
  static const String _runsDirectory = 'runs';
  static const String _fileExtension = '.json';

  /// Get the directory for storing run files
  static Future<Directory> _getRunsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final runsDir = Directory('${appDir.path}/$_runsDirectory');
    
    if (!await runsDir.exists()) {
      await runsDir.create(recursive: true);
    }
    
    return runsDir;
  }

  /// Generate a unique filename for the run
  static String _generateFileName(String runId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'run_${runId}_$timestamp$_fileExtension';
  }

  /// Convert Position to Map for JSON serialization
  static Map<String, dynamic> _positionToMap(Position position) {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'heading': position.heading,
      'speed': position.speed,
      'speedAccuracy': position.speedAccuracy,
      'altitudeAccuracy': position.altitudeAccuracy,
      'headingAccuracy': position.headingAccuracy,
      'timestamp': position.timestamp?.toIso8601String(),
    };
  }

  /// Save run data to local JSON file
  static Future<String> saveRunData({
    required String runId,
    required List<Position> gpsPoints,
    required Duration duration,
    required double distance,
    required String episodeId,
    required String userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final runsDir = await _getRunsDirectory();
      final fileName = _generateFileName(runId);
      final file = File('${runsDir.path}/$fileName');

      // Prepare run data for JSON serialization
      final runData = {
        'runId': runId,
        'userId': userId,
        'episodeId': episodeId,
        'timestamp': DateTime.now().toIso8601String(),
        'duration': duration.inSeconds,
        'distance': distance,
        'gpsPoints': gpsPoints.map(_positionToMap).toList(),
        'gpsPointCount': gpsPoints.length,
        'additionalData': additionalData ?? {},
        'status': 'pending_upload', // Mark as pending upload to Firebase
        'version': '1.0', // For future compatibility
      };

      // Write to file
      await file.writeAsString(jsonEncode(runData));
      
      print('💾 LocalRunStorageService: Run data saved to ${file.path}');
      print('💾 LocalRunStorageService: GPS points: ${gpsPoints.length}');
      print('💾 LocalRunStorageService: Duration: ${duration.inSeconds}s');
      print('💾 LocalRunStorageService: Distance: ${distance.toStringAsFixed(2)}km');
      
      return file.path;
    } catch (e) {
      print('❌ LocalRunStorageService: Error saving run data: $e');
      rethrow;
    }
  }

  /// Load run data from local JSON file
  static Future<Map<String, dynamic>?> loadRunData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ LocalRunStorageService: File does not exist: $filePath');
        return null;
      }

      final jsonString = await file.readAsString();
      final runData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      print('📁 LocalRunStorageService: Run data loaded from $filePath');
      return runData;
    } catch (e) {
      print('❌ LocalRunStorageService: Error loading run data: $e');
      return null;
    }
  }

  /// Get all pending run files (not yet uploaded to Firebase)
  static Future<List<File>> getPendingRunFiles() async {
    try {
      final runsDir = await _getRunsDirectory();
      final files = await runsDir.list().where((file) => 
        file is File && file.path.endsWith(_fileExtension)
      ).cast<File>().toList();

      final pendingFiles = <File>[];
      for (final file in files) {
        final runData = await loadRunData(file.path);
        if (runData != null && runData['status'] == 'pending_upload') {
          pendingFiles.add(file);
        }
      }

      print('📋 LocalRunStorageService: Found ${pendingFiles.length} pending run files');
      return pendingFiles;
    } catch (e) {
      print('❌ LocalRunStorageService: Error getting pending files: $e');
      return [];
    }
  }

  /// Mark run as uploaded to Firebase
  static Future<void> markAsUploaded(String filePath) async {
    try {
      final runData = await loadRunData(filePath);
      if (runData != null) {
        runData['status'] = 'uploaded';
        runData['uploadedAt'] = DateTime.now().toIso8601String();
        
        final file = File(filePath);
        await file.writeAsString(jsonEncode(runData));
        
        print('✅ LocalRunStorageService: Run marked as uploaded: $filePath');
      }
    } catch (e) {
      print('❌ LocalRunStorageService: Error marking as uploaded: $e');
    }
  }

  /// Delete run file (after successful upload)
  static Future<void> deleteRunFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ LocalRunStorageService: Run file deleted: $filePath');
      }
    } catch (e) {
      print('❌ LocalRunStorageService: Error deleting file: $e');
    }
  }

  /// Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final runsDir = await _getRunsDirectory();
      final files = await runsDir.list().where((file) => 
        file is File && file.path.endsWith(_fileExtension)
      ).cast<File>().toList();

      int pendingCount = 0;
      int uploadedCount = 0;
      int totalSize = 0;

      for (final file in files) {
        final runData = await loadRunData(file.path);
        if (runData != null) {
          if (runData['status'] == 'pending_upload') {
            pendingCount++;
          } else if (runData['status'] == 'uploaded') {
            uploadedCount++;
          }
        }
        
        final stat = await file.stat();
        totalSize += stat.size;
      }

      return {
        'totalFiles': files.length,
        'pendingUpload': pendingCount,
        'uploaded': uploadedCount,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('❌ LocalRunStorageService: Error getting storage stats: $e');
      return {
        'totalFiles': 0,
        'pendingUpload': 0,
        'uploaded': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': '0.00',
      };
    }
  }
}











