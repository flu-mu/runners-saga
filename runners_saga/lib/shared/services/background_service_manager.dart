import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Manages background processing for run tracking
class BackgroundServiceManager {
  static const MethodChannel _channel = MethodChannel('runners_saga/background_service');
  static const EventChannel _eventChannel = EventChannel('runners_saga/background_events');
  
  static BackgroundServiceManager? _instance;
  static BackgroundServiceManager get instance => _instance ??= BackgroundServiceManager._();
  
  BackgroundServiceManager._();
  
  /// Starts the background service for run tracking
  Future<bool> startBackgroundService({
    required String runId,
    required String episodeTitle,
    required Duration targetTime,
    required double targetDistance,
  }) async {
    try {
      if (kIsWeb) {
        debugPrint('🌐 Background service not available on web');
        return false;
      }
      
      final result = await _channel.invokeMethod('startBackgroundService', {
        'runId': runId,
        'episodeTitle': episodeTitle,
        'targetTime': targetTime.inSeconds,
        'targetDistance': targetDistance,
      });
      
      debugPrint('✅ Background service started: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Failed to start background service: $e');
      return false;
    }
  }
  
  /// Stops the background service
  Future<bool> stopBackgroundService() async {
    try {
      if (kIsWeb) {
        debugPrint('🌐 Background service not available on web');
        return false;
      }
      
      final result = await _channel.invokeMethod('stopBackgroundService');
      
      debugPrint('✅ Background service stopped: $result');
      return result == true;
    } catch (e) {
      debugPrint('❌ Failed to stop background service: $e');
      return false;
    }
  }
  
  /// Updates the background service notification
  Future<bool> updateNotification({
    required String title,
    required String content,
  }) async {
    try {
      if (kIsWeb) {
        debugPrint('🌐 Background service not available on web');
        return false;
      }
      
      final result = await _channel.invokeMethod('updateNotification', {
        'title': title,
        'content': content,
      });
      
      return result == true;
    } catch (e) {
      debugPrint('❌ Failed to update notification: $e');
      return false;
    }
  }
  
  /// Checks if background service is running
  Future<bool> isBackgroundServiceRunning() async {
    try {
      if (kIsWeb) {
        return false;
      }
      
      final result = await _channel.invokeMethod('isBackgroundServiceRunning');
      return result == true;
    } catch (e) {
      debugPrint('❌ Failed to check background service status: $e');
      return false;
    }
  }
  
  /// Stream of background service events
  Stream<String> get backgroundEvents {
    if (kIsWeb) {
      return const Stream.empty();
    }
    
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }
  
  /// Request battery optimization exemption (Android only)
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      if (kIsWeb) {
        return false;
      }
      
      final result = await _channel.invokeMethod('requestBatteryOptimizationExemption');
      return result == true;
    } catch (e) {
      debugPrint('❌ Failed to request battery optimization exemption: $e');
      return false;
    }
  }
}
