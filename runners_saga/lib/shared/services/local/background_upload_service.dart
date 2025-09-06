import 'dart:async';
import 'local_run_storage_service.dart';
import 'local_to_firebase_upload_service.dart';

/// Background service for uploading pending run data to Firebase
/// This service runs periodically to ensure all local data is uploaded
class BackgroundUploadService {
  static Timer? _uploadTimer;
  static bool _isRunning = false;
  static const Duration _uploadInterval = Duration(minutes: 5); // Check every 5 minutes

  /// Start the background upload service
  static void start() {
    if (_isRunning) {
      print('🔄 BackgroundUploadService: Already running');
      return;
    }

    _isRunning = true;
    print('🚀 BackgroundUploadService: Starting background upload service');
    
    _uploadTimer = Timer.periodic(_uploadInterval, (timer) {
      _uploadPendingRuns();
    });
  }

  /// Stop the background upload service
  static void stop() {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    print('🛑 BackgroundUploadService: Stopped background upload service');
  }

  /// Upload all pending runs
  static Future<void> _uploadPendingRuns() async {
    try {
      print('🔄 BackgroundUploadService: Checking for pending uploads...');
      
      final stats = await LocalRunStorageService.getStorageStats();
      final pendingCount = stats['pendingUpload'] as int;
      
      if (pendingCount == 0) {
        print('✅ BackgroundUploadService: No pending uploads');
        return;
      }

      print('📤 BackgroundUploadService: Found $pendingCount pending uploads, starting upload...');
      
      final result = await LocalToFirebaseUploadService.uploadAllPendingRuns();
      final successful = result['successfulUploads'] as int;
      final failed = result['failedUploads'] as int;
      
      print('📊 BackgroundUploadService: Upload complete - $successful successful, $failed failed');
      
      if (failed > 0) {
        final errors = result['errors'] as List<String>;
        print('❌ BackgroundUploadService: Upload errors: ${errors.take(3).join(', ')}');
      }
      
    } catch (e) {
      print('❌ BackgroundUploadService: Error in background upload: $e');
    }
  }

  /// Force upload all pending runs immediately
  static Future<Map<String, dynamic>> forceUploadAll() async {
    print('🚀 BackgroundUploadService: Force uploading all pending runs...');
    return await LocalToFirebaseUploadService.uploadAllPendingRuns();
  }

  /// Get service status
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'uploadInterval': _uploadInterval.inMinutes,
      'nextUploadIn': _isRunning ? '${_uploadInterval.inMinutes} minutes' : 'Service stopped',
    };
  }

  /// Clean up uploaded files
  static Future<void> cleanupUploadedFiles() async {
    try {
      print('🧹 BackgroundUploadService: Cleaning up uploaded files...');
      await LocalToFirebaseUploadService.cleanupUploadedFiles();
      print('✅ BackgroundUploadService: Cleanup complete');
    } catch (e) {
      print('❌ BackgroundUploadService: Error during cleanup: $e');
    }
  }
}










