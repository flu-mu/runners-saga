import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manages background processing for run tracking
class BackgroundServiceManager {
  static const MethodChannel _channel = MethodChannel('runners_saga/background_service');
  static const EventChannel _eventChannel = EventChannel('runners_saga/background_events');
  
  static BackgroundServiceManager? _instance;
  static BackgroundServiceManager get instance => _instance ??= BackgroundServiceManager._();
  
  BackgroundServiceManager._();
  
  // Background service state
  bool _isBackgroundServiceRunning = false;
  String? _currentRunId;
  String? _currentEpisodeTitle;
  Duration? _currentTargetTime;
  double? _currentTargetDistance;
  
  // App lifecycle management
  bool _isAppInBackground = false;
  DateTime? _lastBackgroundTime;
  
  // Stream controllers for background events
  final StreamController<bool> _backgroundStateController = StreamController<bool>.broadcast();
  final StreamController<String> _backgroundEventController = StreamController<String>.broadcast();
  
  // Getters
  bool get isBackgroundServiceRunning => _isBackgroundServiceRunning;
  bool get isAppInBackground => _isAppInBackground;
  Stream<bool> get backgroundStateStream => _backgroundStateController.stream;
  Stream<String> get backgroundEventStream => _backgroundEventController.stream;
  
  /// Initialize the background service manager
  Future<void> initialize() async {
    if (kIsWeb) return;
    
    // Listen to background events from native side
    _eventChannel.receiveBroadcastStream().listen((event) {
      _handleBackgroundEvent(event.toString());
    });
    
    // Check if background service is already running
    _isBackgroundServiceRunning = await checkBackgroundServiceStatus();
    
    debugPrint('🔧 BackgroundServiceManager initialized. Service running: $_isBackgroundServiceRunning');
  }
  
  /// Handle app lifecycle changes
  void onAppLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _handleAppForegrounded();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }
  
  /// Handle app going to background
  void _handleAppBackgrounded() {
    if (_isAppInBackground) return;
    
    _isAppInBackground = true;
    _lastBackgroundTime = DateTime.now();
    
    debugPrint('📱 App going to background at $_lastBackgroundTime');
    
    // Ensure background service is running if we have an active session
    if (_currentRunId != null && !_isBackgroundServiceRunning) {
      _startBackgroundServiceFromState();
    }
    
    _backgroundStateController.add(true);
  }
  
  /// Handle app coming to foreground
  void _handleAppForegrounded() {
    if (!_isAppInBackground) return;
    
    _isAppInBackground = false;
    final backgroundDuration = _lastBackgroundTime != null 
        ? DateTime.now().difference(_lastBackgroundTime!)
        : Duration.zero;
    
    debugPrint('📱 App coming to foreground. Was in background for: $backgroundDuration');
    
    // Check background service status
    _checkBackgroundServiceStatus();
    
    _backgroundStateController.add(false);
  }
  
  /// Handle app being detached (killed)
  void _handleAppDetached() {
    debugPrint('📱 App being detached/killed');
    
    // Ensure background service continues running
    if (_currentRunId != null && !_isBackgroundServiceRunning) {
      _startBackgroundServiceFromState();
    }
  }
  
  /// Handle app being hidden
  void _handleAppHidden() {
    debugPrint('📱 App being hidden');
    _handleAppBackgrounded();
  }
  
  /// Start background service from current state
  Future<void> _startBackgroundServiceFromState() async {
    if (_currentRunId == null || _currentTargetTime == null || _currentTargetDistance == null) {
      debugPrint('⚠️ Cannot start background service - missing session data');
      return;
    }
    
    await startBackgroundService(
      runId: _currentRunId!,
      episodeTitle: _currentEpisodeTitle ?? 'Unknown Episode',
      targetTime: _currentTargetTime!,
      targetDistance: _currentTargetDistance!,
    );
  }
  
  /// Check background service status
  Future<void> _checkBackgroundServiceStatus() async {
    try {
      final isRunning = await checkBackgroundServiceStatus();
      if (isRunning != _isBackgroundServiceRunning) {
        _isBackgroundServiceRunning = isRunning;
        debugPrint('🔄 Background service status changed: $_isBackgroundServiceRunning');
        
        if (!isRunning && _currentRunId != null) {
          debugPrint('⚠️ Background service stopped unexpectedly, restarting...');
          await _startBackgroundServiceFromState();
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking background service status: $e');
    }
  }
  
  /// Handle background events from native side
  void _handleBackgroundEvent(String event) {
    debugPrint('📡 Background event received: $event');
    
    if (event.startsWith('SERVICE_STARTED')) {
      _isBackgroundServiceRunning = true;
      _backgroundStateController.add(true);
    } else if (event.startsWith('SERVICE_STOPPED')) {
      _isBackgroundServiceRunning = false;
      _backgroundStateController.add(false);
    } else if (event.startsWith('GPS_UPDATE')) {
      _backgroundEventController.add(event);
    } else if (event.startsWith('TIMER_UPDATE')) {
      _backgroundEventController.add(event);
    }
    
    _backgroundEventController.add(event);
  }
  
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
      
      // Store current session state
      _currentRunId = runId;
      _currentEpisodeTitle = episodeTitle;
      _currentTargetTime = targetTime;
      _currentTargetDistance = targetDistance;
      
      final result = await _channel.invokeMethod('startBackgroundService', {
        'runId': runId,
        'episodeTitle': episodeTitle,
        'targetTime': targetTime.inSeconds,
        'targetDistance': targetDistance,
      });
      
      _isBackgroundServiceRunning = result == true;
      
      debugPrint('✅ Background service started: $_isBackgroundServiceRunning');
      _backgroundStateController.add(_isBackgroundServiceRunning);
      
      return _isBackgroundServiceRunning;
    } catch (e) {
      debugPrint('❌ Failed to start background service: $e');
      return false;
    }
  }
  
  /// Start a run session in the background service
  Future<bool> startRunSession({
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
      
      // Store current session state
      _currentRunId = runId;
      _currentEpisodeTitle = episodeTitle;
      _currentTargetTime = targetTime;
      _currentTargetDistance = targetDistance;
      
      final result = await _channel.invokeMethod('startRunSession', {
        'runId': runId,
        'episodeTitle': episodeTitle,
        'targetTime': targetTime.inSeconds,
        'targetDistance': targetDistance,
      });
      
      _isBackgroundServiceRunning = result == true;
      
      debugPrint('✅ Run session started in background service: $_isBackgroundServiceRunning');
      _backgroundStateController.add(_isBackgroundServiceRunning);
      
      return _isBackgroundServiceRunning;
    } catch (e) {
      debugPrint('❌ Failed to start run session: $e');
      return false;
    }
  }
  
  /// Stop the current run session
  Future<bool> stopRunSession() async {
    try {
      if (kIsWeb) {
        debugPrint('🌐 Background service not available on web');
        return false;
      }
      
      final result = await _channel.invokeMethod('stopRunSession');
      
      _isBackgroundServiceRunning = result == true;
      
      // Clear session state
      _currentRunId = null;
      _currentEpisodeTitle = null;
      _currentTargetTime = null;
      _currentTargetDistance = null;
      
      debugPrint('✅ Run session stopped: $_isBackgroundServiceRunning');
      _backgroundStateController.add(_isBackgroundServiceRunning);
      
      return _isBackgroundServiceRunning;
    } catch (e) {
      debugPrint('❌ Failed to stop run session: $e');
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
  Future<bool> checkBackgroundServiceStatus() async {
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
  
  /// Get current session state
  Map<String, dynamic>? getCurrentSessionState() {
    if (_currentRunId == null) return null;
    
    return {
      'runId': _currentRunId,
      'episodeTitle': _currentEpisodeTitle,
      'targetTime': _currentTargetTime?.inSeconds,
      'targetDistance': _currentTargetDistance,
      'isBackgroundServiceRunning': _isBackgroundServiceRunning,
      'isAppInBackground': _isAppInBackground,
      'lastBackgroundTime': _lastBackgroundTime?.toIso8601String(),
    };
  }
  
  /// Restore session state (for app restart scenarios)
  Future<void> restoreSessionState(Map<String, dynamic> state) async {
    try {
      final runId = state['runId'] as String?;
      final episodeTitle = state['episodeTitle'] as String?;
      final targetTimeSeconds = state['targetTime'] as int?;
      final targetDistance = state['targetDistance'] as double?;
      
      if (runId != null && targetTimeSeconds != null && targetDistance != null) {
        _currentRunId = runId;
        _currentEpisodeTitle = episodeTitle;
        _currentTargetTime = Duration(seconds: targetTimeSeconds);
        _currentTargetDistance = targetDistance;
        
        debugPrint('🔄 Session state restored: $runId');
        
        // Check if background service should be running
        if (await checkBackgroundServiceStatus()) {
          _isBackgroundServiceRunning = true;
        } else {
          // Restart background service if needed
          await _startBackgroundServiceFromState();
        }
      }
    } catch (e) {
      debugPrint('❌ Error restoring session state: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _backgroundStateController.close();
    _backgroundEventController.close();
  }
}

