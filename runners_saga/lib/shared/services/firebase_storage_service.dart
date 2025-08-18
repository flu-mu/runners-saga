import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../main.dart'; // Import to access isFirebaseReady

class FirebaseStorageService {
  static FirebaseStorage? _storage;
  
  // Base path for audio files
  static const String _audioBasePath = 'audio/episodes';
  
  // Lazy initialization to ensure Firebase is ready
  static FirebaseStorage get _storageInstance {
    if (!isFirebaseReady) {
      throw Exception('Firebase not initialized yet. Please wait for app startup to complete.');
    }
    _storage ??= FirebaseStorage.instance;
    return _storage!;
  }
  
  /// Get the download URL for an audio file
  static Future<String> getAudioFileUrl(String episodeId, String fileName) async {
    try {
      final filePath = '$_audioBasePath/$episodeId/$fileName';
      final ref = _storageInstance.ref().child(filePath);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error getting download URL for $fileName: $e');
      rethrow;
    }
  }
  
  /// Get all audio file URLs for an episode
  static Future<List<String>> getEpisodeAudioUrls(String episodeId, List<String> fileNames) async {
    try {
      final urls = <String>[];
      for (final fileName in fileNames) {
        final url = await getAudioFileUrl(episodeId, fileName);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      print('Error getting episode audio URLs: $e');
      rethrow;
    }
  }
  
  /// Upload an audio file to Firebase Storage
  static Future<String> uploadAudioFile(String episodeId, String fileName, File file) async {
    try {
      final filePath = '$_audioBasePath/$episodeId/$fileName';
      final ref = _storageInstance.ref().child(filePath);
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading audio file $fileName: $e');
      rethrow;
    }
  }
  
  /// Delete an audio file from Firebase Storage
  static Future<void> deleteAudioFile(String episodeId, String fileName) async {
    try {
      final filePath = '$_audioBasePath/$episodeId/$fileName';
      final ref = _storageInstance.ref().child(filePath);
      await ref.delete();
    } catch (e) {
      print('Error deleting audio file $fileName: $e');
      rethrow;
    }
  }
  
  /// Get the file name from a Firebase Storage URL
  static String getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last;
      }
      // Simple fallback: get filename from URL
      final lastSlash = url.lastIndexOf('/');
      if (lastSlash != -1 && lastSlash < url.length - 1) {
        return url.substring(lastSlash + 1);
      }
      return url;
    } catch (e) {
      print('Error parsing URL: $e');
      return url;
    }
  }
  
  /// Check if a file exists in Firebase Storage
  static Future<bool> fileExists(String episodeId, String fileName) async {
    try {
      final filePath = '$_audioBasePath/$episodeId/$fileName';
      final ref = _storageInstance.ref().child(filePath);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }
}
