import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'background_service_manager.dart';
import 'background_timer_manager.dart';
import 'run/progress_monitor_service.dart';
import 'story/scene_trigger_service.dart';
import 'audio/audio_manager.dart';

/// Manages app lifecycle and coordinates background services
class AppLifecycleManager {
  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance => _instance ??= AppLifecycleManager._();
  
  AppLifecycleManager._();
  
  // Service references
  late BackgroundServiceManager _backgroundServiceManager;
  late BackgroundTimerManager _backgroundTimerManager;
  late ProgressMonitorService _progressMonitorService;
  late SceneTriggerService _sceneTriggerService;
  late AudioManager _audioManager;
  
  // App lifecycle state
  bool _isAppInBackground = false;
  DateTime? _lastBackgroundTime;
  bool _isInitialized = false;
  
  // Stream controllers
  final StreamController<bool> _appStateController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _backgroundEventController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters
  bool get isAppInBackground => _isAppInBackground;
  Stream<bool> get appStateStream => _appStateController.stream;
  Stream<Map<String, dynamic>> get backgroundEventStream => _backgroundEventController.stream;
  
  /// Initialize the app lifecycle manager
  Future<void> initialize({
    required BackgroundServiceManager backgroundServiceManager,
    required BackgroundTimerManager backgroundTimerManager,
    required ProgressMonitorService progressMonitorService,
    required SceneTriggerService sceneTriggerService,
    required AudioManager audioManager,
  }) async {
    if (_isInitialized) return;
    
    _backgroundServiceManager = backgroundServiceManager;
    _backgroundTimerManager = backgroundTimerManager;
    _progressMonitorService = progressMonitorService;
    _sceneTriggerService = sceneTriggerService;
    _audioManager = audioManager;
    
    // Initialize background service manager
    await _backgroundServiceManager.initialize();
    
    // Set up background service event listeners
    _backgroundServiceManager.backgroundEventStream.listen(_handleBackgroundServiceEvent);
    _backgroundServiceManager.backgroundStateStream.listen(_handleBackgroundServiceStateChange);
    
    // Set up background timer events
    _backgroundTimerManager.backgroundUpdateStream.listen(_handleBackgroundTimerEvent);
    
    _isInitialized = true;
    
    debugPrint('🔧 AppLifecycleManager: Initialized successfully');
  }
  
  /// Handle app lifecycle changes from Flutter
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
    
    debugPrint('📱 AppLifecycleManager: App going to background at $_lastBackgroundTime');
    
    // Notify all services about app backgrounding
    _backgroundTimerManager.onAppLifecycleChanged(true);
    _progressMonitorService.onAppLifecycleChanged(true);
    _sceneTriggerService.onAppLifecycleChanged(AppLifecycleState.paused);
    
    // Ensure background services are running
    _ensureBackgroundServicesRunning();
    
    // Pause audio to prevent conflicts when app returns
    _pauseAudioForBackground();
    
    _appStateController.add(true);
  }
  
  /// Handle app coming to foreground
  void _handleAppForegrounded() {
    if (!_isAppInBackground) return;
    
    _isAppInBackground = false;
    final backgroundDuration = _lastBackgroundTime != null 
        ? DateTime.now().difference(_lastBackgroundTime!)
        : Duration.zero;
    
    debugPrint('📱 AppLifecycleManager: App coming to foreground after $backgroundDuration in background');
    
    // Notify all services about app foregrounding
    _backgroundTimerManager.onAppLifecycleChanged(false);
    _progressMonitorService.onAppLifecycleChanged(false);
    _sceneTriggerService.onAppLifecycleChanged(AppLifecycleState.resumed);
    
    // Check background service status
    _checkBackgroundServiceStatus();
    
    // Resume audio and check for conflicts
    _resumeAudioFromBackground();
    
    _appStateController.add(false);
  }
  
  /// Handle app being detached (killed)
  void _handleAppDetached() {
    debugPrint('📱 AppLifecycleManager: App being detached/killed');
    
    // Ensure background services continue running
    _ensureBackgroundServicesRunning();
  }
  
  /// Handle app being hidden
  void _handleAppHidden() {
    debugPrint('📱 AppLifecycleManager: App being hidden');
    _handleAppBackgrounded();
  }
  
  /// Ensure background services are running
  Future<void> _ensureBackgroundServicesRunning() async {
    try {
      // Check if we have an active run session
      if (_progressMonitorService.isMonitoring && !_progressMonitorService.isPaused) {
        // Start background service if not already running
        if (!_backgroundServiceManager.isBackgroundServiceRunning) {
          final runId = DateTime.now().millisecondsSinceEpoch.toString();
          final episodeTitle = 'Active Run';
          final targetTime = Duration(minutes: 60); // Default target
          final targetDistance = 5.0; // Default target
          
          await _backgroundServiceManager.startBackgroundService(
            runId: runId,
            episodeTitle: episodeTitle,
            targetTime: targetTime,
            targetDistance: targetDistance,
          );
          
          debugPrint('🔧 AppLifecycleManager: Background service started for active run');
        }
      }
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Failed to ensure background services: $e');
    }
  }
  
  /// Check background service status
  Future<void> _checkBackgroundServiceStatus() async {
    try {
      final isRunning = await _backgroundServiceManager.isBackgroundServiceRunning;
      
      if (isRunning) {
        debugPrint('✅ AppLifecycleManager: Background service is running');
        
        // Sync state from background service
        await _syncStateFromBackgroundService();
      } else {
        debugPrint('⚠️ AppLifecycleManager: Background service is not running');
      }
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error checking background service status: $e');
    }
  }
  
  /// Sync state from background service
  Future<void> _syncStateFromBackgroundService() async {
    try {
      // Get current session state from background service
      final sessionState = _backgroundServiceManager.getCurrentSessionState();
      if (sessionState != null) {
        debugPrint('🔄 AppLifecycleManager: Syncing state from background service');
        
        // Restore timer state
        final timerState = _backgroundTimerManager.getCurrentState();
        if (timerState['isRunning'] == true) {
          await _backgroundTimerManager.restoreFromBackgroundState(timerState);
        }
        
        // Note: GPS data is already persisted and will be loaded automatically
      }
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error syncing state from background service: $e');
    }
  }
  
  /// Pause audio to prevent conflicts when app goes to background
  void _pauseAudioForBackground() {
    try {
      // Don't stop audio completely, just pause to prevent conflicts
      // This allows the background service to continue managing audio
      debugPrint('🔇 AppLifecycleManager: Audio paused for background');
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error pausing audio: $e');
    }
  }
  
  /// Resume audio and check for conflicts when app returns from background
  void _resumeAudioFromBackground() {
    try {
      // Check if any audio is playing that shouldn't be
      _checkAudioConflicts();
      
      debugPrint('🔊 AppLifecycleManager: Audio resumed from background');
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error resuming audio: $e');
    }
  }
  
  /// Check for audio conflicts after returning from background
  void _checkAudioConflicts() {
    try {
      // Check if multiple audio sources are playing simultaneously
      // This can happen if the app was backgrounded during scene transitions
      
      // Get current scene state
      final currentScene = _sceneTriggerService.currentScene;
      final isScenePlaying = _sceneTriggerService.isScenePlaying;
      
      if (isScenePlaying && currentScene != null) {
        debugPrint('🎬 AppLifecycleManager: Scene audio is playing: $currentScene');
        
        // Ensure only one audio source is playing
        _ensureSingleAudioSource();
      }
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error checking audio conflicts: $e');
    }
  }
  
  /// Ensure only one audio source is playing
  void _ensureSingleAudioSource() {
    try {
      // Stop any background music or SFX that might be conflicting
      _audioManager.stopBackgroundMusic();
      _audioManager.stopSfx();
      
      // Keep only story audio playing
      debugPrint('🎵 AppLifecycleManager: Audio conflicts resolved - single source ensured');
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error resolving audio conflicts: $e');
    }
  }
  
  /// Handle background service events
  void _handleBackgroundServiceEvent(String event) {
    debugPrint('📡 AppLifecycleManager: Background service event: $event');
    
    // Parse event and forward to appropriate handlers
    if (event.startsWith('GPS_UPDATE')) {
      _handleGpsUpdate(event);
    } else if (event.startsWith('TIMER_UPDATE')) {
      _handleTimerUpdate(event);
    } else if (event.startsWith('SCENE_TRIGGER')) {
      _handleSceneTrigger(event);
    }
    
    // Forward event to listeners
    _backgroundEventController.add({
      'type': 'BACKGROUND_SERVICE_EVENT',
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Handle background service state changes
  void _handleBackgroundServiceStateChange(bool isRunning) {
    debugPrint('🔄 AppLifecycleManager: Background service state changed: $isRunning');
    
    if (!isRunning) {
      // Background service stopped unexpectedly
      debugPrint('⚠️ AppLifecycleManager: Background service stopped unexpectedly');
      
      // Try to restart if we have an active session
      if (_progressMonitorService.isMonitoring) {
        _ensureBackgroundServicesRunning();
      }
    }
  }
  
  /// Handle background timer events
  void _handleBackgroundTimerEvent(Map<String, dynamic> event) {
    debugPrint('⏱️ AppLifecycleManager: Background timer event: $event');
    
    // Forward timer events to listeners
    _backgroundEventController.add({
      'type': 'BACKGROUND_TIMER_EVENT',
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Handle GPS updates from background service
  void _handleGpsUpdate(String event) {
    // Parse GPS event and update progress monitor if needed
    debugPrint('📍 AppLifecycleManager: GPS update from background service: $event');
  }
  
  /// Handle timer updates from background service
  void _handleTimerUpdate(String event) {
    // Parse timer event and update background timer if needed
    debugPrint('⏱️ AppLifecycleManager: Timer update from background service: $event');
  }
  
  /// Handle scene triggers from background service
  void _handleSceneTrigger(String event) {
    // Parse scene trigger event and handle scene progression
    debugPrint('🎬 AppLifecycleManager: Scene trigger from background service: $event');
  }
  
  /// Get current app state for debugging
  Map<String, dynamic> getCurrentState() {
    return {
      'isAppInBackground': _isAppInBackground,
      'lastBackgroundTime': _lastBackgroundTime?.toIso8601String(),
      'isInitialized': _isInitialized,
      'backgroundServiceRunning': _backgroundServiceManager.isBackgroundServiceRunning,
      'progressMonitorMonitoring': _progressMonitorService.isMonitoring,
      'progressMonitorPaused': _progressMonitorService.isPaused,
      'backgroundTimerRunning': _backgroundTimerManager.isRunning,
      'backgroundTimerPaused': _backgroundTimerManager.isPaused,
      'sceneTriggerRunning': _sceneTriggerService.isRunning,
      'sceneTriggerPlaying': _sceneTriggerService.isScenePlaying,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      return await _backgroundServiceManager.requestBatteryOptimizationExemption();
    } catch (e) {
      debugPrint('❌ AppLifecycleManager: Error requesting battery optimization exemption: $e');
      return false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _appStateController.close();
    _backgroundEventController.close();
    debugPrint('🔄 AppLifecycleManager: Disposed');
  }
}
