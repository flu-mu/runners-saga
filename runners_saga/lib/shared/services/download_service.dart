import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import '../../main.dart'; // Import to access isFirebaseReady

class DownloadResult {
  final bool success;
  final List<String> localPaths;
  final String? error;
  final double progress;
  
  const DownloadResult({
    required this.success, 
    required this.localPaths, 
    this.error,
    this.progress = 0.0,
  });
}

class DownloadService {
  static const String _episodeDirName = 'episodes';
  
  /// Get the local directory for storing downloaded episodes
  Future<String> _episodeDir(String episodeId) async {
    final dir = await getApplicationDocumentsDirectory();
    final p = '${dir.path}/$_episodeDirName/$episodeId';
    final d = Directory(p);
    if (!d.existsSync()) d.createSync(recursive: true);
    return p;
  }
  
  /// Check if episode is already downloaded
  Future<bool> isEpisodeDownloaded(String episodeId) async {
    try {
      final dir = await _episodeDir(episodeId);
      final episodeDir = Directory(dir);
      if (!episodeDir.existsSync()) return false;
      
      // Check if any audio files exist
      final files = episodeDir.listSync();
      return files.any((file) => file.path.endsWith('.mp3') || file.path.endsWith('.wav'));
    } catch (e) {
      print('Error checking if episode is downloaded: $e');
      return false;
    }
  }
  
  /// Get local paths of downloaded episode files
  Future<List<String>> getLocalEpisodeFiles(String episodeId) async {
    try {
      final dir = await _episodeDir(episodeId);
      final episodeDir = Directory(dir);
      if (!episodeDir.existsSync()) return [];
      
      final files = episodeDir.listSync()
          .where((file) => file.path.endsWith('.mp3') || file.path.endsWith('.wav'))
          .map((file) => file.path)
          .toList();
      
      return files;
    } catch (e) {
      print('Error getting local episode files: $e');
      return [];
    }
  }
  
  /// Download episode audio files from Firebase URLs
  Future<DownloadResult> downloadEpisode(
    String episodeId, 
    List<String> urls, {
    Function(double)? onProgress,
  }) async {
    try {
      final dest = await _episodeDir(episodeId);
      final local = <String>[];
      double totalProgress = 0.0;
      
      for (int i = 0; i < urls.length; i++) {
        final url = urls[i];
        final fileName = _getFileNameFromUrl(url);
        final out = File('$dest/$fileName');
        
        // Skip if file already exists
        if (out.existsSync()) {
          local.add(out.path);
          totalProgress = (i + 1) / urls.length;
          onProgress?.call(totalProgress);
          continue;
        }
        
        // Download file
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          await out.writeAsBytes(res.bodyBytes);
          local.add(out.path);
          print('✅ Downloaded: $fileName');
        } else {
          print('❌ HTTP ${res.statusCode} for $fileName');
          return DownloadResult(
            success: false, 
            localPaths: local, 
            error: 'HTTP ${res.statusCode} for $fileName',
            progress: totalProgress,
          );
        }
        
        // Update progress
        totalProgress = (i + 1) / urls.length;
        onProgress?.call(totalProgress);
      }
      
      return DownloadResult(
        success: true, 
        localPaths: local,
        progress: 1.0,
      );
    } catch (e) {
      print('Download error: $e');
      return DownloadResult(
        success: false, 
        localPaths: const [], 
        error: e.toString(),
        progress: 0.0,
      );
    }
  }
  
  /// Download episode from Firebase Storage using episode ID and file names
  Future<DownloadResult> downloadEpisodeFromFirebase(
    String episodeId, 
    List<String> fileNames, {
    Function(double)? onProgress,
  }) async {
    try {
      final dest = await _episodeDir(episodeId);
      final local = <String>[];
      double totalProgress = 0.0;
      
      for (int i = 0; i < fileNames.length; i++) {
        final fileName = fileNames[i];
        final out = File('$dest/$fileName');
        
        // Skip if file already exists
        if (out.existsSync()) {
          local.add(out.path);
          totalProgress = (i + 1) / fileNames.length;
          onProgress?.call(totalProgress);
          continue;
        }
        
        // Get Firebase download URL
        final url = await _getFirebaseDownloadUrl(episodeId, fileName);
        
        // Download file
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          await out.writeAsBytes(res.bodyBytes);
          local.add(out.path);
          print('✅ Downloaded: $fileName');
        } else {
          print('❌ HTTP ${res.statusCode} for $fileName');
          return DownloadResult(
            success: false, 
            localPaths: local, 
            error: 'HTTP ${res.statusCode} for $fileName',
            progress: totalProgress,
          );
        }
        
        // Update progress
        totalProgress = (i + 1) / fileNames.length;
        onProgress?.call(totalProgress);
      }
      
      return DownloadResult(
        success: true, 
        localPaths: local,
        progress: 1.0,
      );
    } catch (e) {
      print('Error downloading from Firebase: $e');
      return DownloadResult(
        success: false, 
        localPaths: const [], 
        error: e.toString(),
        progress: 0.0,
      );
    }
  }
  
  /// Download episode using existing URLs from database (handles https:// URLs)
  Future<DownloadResult> downloadEpisodeFromDatabase(
    String episodeId, 
    List<String> audioFileUrls, {
    Function(double)? onProgress,
  }) async {
    try {
      // Extract file names from the URLs and use Firebase Storage directly
      final fileNames = audioFileUrls.map((url) {
        // Extract filename from URL
        final parts = url.split('/');
        return parts.last; // Get the filename
      }).toList();
      
      // Use Firebase Storage to get proper download URLs
      return await downloadEpisodeFromFirebase(episodeId, fileNames, onProgress: onProgress);
    } catch (e) {
      print('Error processing database URLs: $e');
      return DownloadResult(
        success: false, 
        localPaths: const [], 
        error: e.toString(),
        progress: 0.0,
      );
    }
  }
  
  /// Get Firebase download URL for a file
  Future<String> _getFirebaseDownloadUrl(String episodeId, String fileName) async {
    try {
      // Check if Firebase is ready
      if (!isFirebaseReady) {
        throw Exception('Firebase not initialized yet. Please wait for app startup to complete.');
      }
      
      final filePath = 'audio/episodes/$episodeId/$fileName';
      final ref = FirebaseStorage.instance.ref().child(filePath);
      
      // Check if file exists first
      try {
        await ref.getMetadata();
      } catch (e) {
        throw Exception('Audio file not found: $fileName. Please check if it\'s uploaded to Firebase Storage.');
      }
      
      return await ref.getDownloadURL();
    } catch (e) {
      if (e.toString().contains('unauthorized')) {
        throw Exception('Access denied. Please check Firebase Storage security rules.');
      } else if (e.toString().contains('not found')) {
        throw Exception('Audio file not found: $fileName');
      } else {
        throw Exception('Failed to get download URL: $e');
      }
    }
  }
  
  /// Extract filename from URL
  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last;
      }
      // Fallback: get filename from URL
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
  
  /// Delete downloaded episode
  Future<bool> deleteEpisode(String episodeId) async {
    try {
      final dir = await _episodeDir(episodeId);
      final episodeDir = Directory(dir);
      if (episodeDir.existsSync()) {
        episodeDir.deleteSync(recursive: true);
        print('✅ Deleted episode: $episodeId');
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting episode: $e');
      return false;
    }
  }
  
  /// Get download size for episode
  Future<int> getEpisodeDownloadSize(String episodeId, List<String> urls) async {
    try {
      int totalSize = 0;
      for (final url in urls) {
        final response = await http.head(Uri.parse(url));
        if (response.statusCode == 200) {
          final contentLength = response.headers['content-length'];
          if (contentLength != null) {
            totalSize += int.parse(contentLength);
          }
        }
      }
      return totalSize;
    } catch (e) {
      print('Error getting download size: $e');
      return 0;
    }
  }
}




