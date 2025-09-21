import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart'; // Not used
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:just_audio/just_audio.dart';
import 'progress_monitor_service.dart';
import '../story/scene_trigger_service.dart';
import '../audio/audio_manager.dart';
// import '../firebase/firestore_service.dart';
import '../audio/download_service.dart';
// import '../firebase/firebase_storage_service.dart';
import '../../models/episode_model.dart';
import '../../models/run_model.dart';
import '../../models/run_target_model.dart';
import '../../models/run_stats_model.dart';
import '../../models/run_enums.dart';
// import '../../providers/settings_providers.dart';

class RunSessionManager {
  final ProgressMonitorService _progressMonitor = ProgressMonitorService();
  final SceneTriggerService _sceneTrigger = SceneTriggerService();
  final AudioManager _audioManager = AudioManager();
  
  // Session state
  bool _isSessionActive = false;
  bool _isPaused = false;
  EpisodeModel? _currentEpisode;
  RunModel? _currentRun;
  
  // Session tracking
  DateTime? _sessionStartTime;
  DateTime? _sessionPauseTime;
  Duration _totalPausedTime = Duration.zero;
  bool _timersStopped = false; // Flag to prevent timer restart
  bool _globallyStopped = false; // Global stop flag
  
  // Target values for the current session
  Duration? _userTargetTime;
  double? _userTargetDistance;
  
  // Callbacks
  Function(RunSessionState state)? onSessionStateChanged;
  Function(SceneType scene)? onSceneStarted;
  Function(SceneType scene)? onSceneCompleted;
  Function(double progress)? onProgressUpdated;
  Function(RunStats stats)? onStatsUpdated;
  Function(List<LocationPoint> route)? onRouteUpdated;
  Function(Duration time)? onTimeUpdated; // New callback for elapsed time updates
  
  // Getters
  bool get isSessionActive => _isSessionActive;
  bool get isPaused => _isPaused;
  EpisodeModel? get currentEpisode => _currentEpisode;
  RunModel? get currentRun => _currentRun;
  RunSessionState get sessionState => _getSessionState();
  double get currentProgress => _progressMonitor.progress;
  List<SceneType> get playedScenes => _sceneTrigger.playedScenes.toList();

  /// Update clip interval configuration during an active session
  void updateClipInterval(ClipIntervalMode mode, {double? distanceKm, double? minutes}) {
    _sceneTrigger.setClipInterval(mode, distanceKm: distanceKm, minutes: minutes);
  }

  /// Refresh clip interval configuration from settings
  Future<void> refreshClipIntervalFromSettings() async {
    await _sceneTrigger.refreshClipIntervalFromSettings();
  }

  /// Initialize the run session manager
  Future<void> initialize() async {
    await _audioManager.initialize();
    
    // Scene trigger callbacks will be set up in startSession
  }

  /// Attach Riverpod ref so child services can access providers
  void attachRef(Ref ref) {
    _progressMonitor.setRef(ref);
    _sceneTrigger.setRef(ref);
  }

  /// Check if a new session can be started
  bool canStartSession() {
    return !_isSessionActive; // Only check if session is not already active
  }
  
  /// Start a new run session
  Future<void> startSession(
    EpisodeModel episode, {
    required Duration userTargetTime,
    required double userTargetDistance,
    required TrackingMode trackingMode,
    double strideMeters = 1.0,
    double simulatePaceMinPerKm = 6.0,
    bool trackingEnabled = true,
  }) async {
    if (_isSessionActive) {
      throw Exception('Session already active');
    }
    
    // Progress monitor can always be started
    
    try {
      _currentEpisode = episode;
      _userTargetTime = userTargetTime;
      _userTargetDistance = userTargetDistance;
      _sessionStartTime = DateTime.now();
      _isSessionActive = true;
      _isPaused = false;
      
      // Initialize progress monitor with user's selected targets
      _progressMonitor.initialize(
        targetTime: userTargetTime,
        targetDistance: userTargetDistance,
        trackingMode: trackingMode,
        strideMeters: strideMeters,
        simulatePaceMinPerKm: simulatePaceMinPerKm,
        trackingEnabled: trackingEnabled,
        onDistanceUpdate: _onDistanceUpdate,
        onTimeUpdate: _onTimeUpdate,
        onPaceUpdate: _onPaceUpdate, 
        onProgressUpdate: _onProgressUpdate, 
        onRouteUpdate: _onRouteUpdate,
      );

      // Ensure background progress monitoring can trigger scenes while app is backgrounded
      // This connects the ProgressMonitorService's background timer to the SceneTriggerService
      _progressMonitor.setSceneTriggerService(_sceneTrigger);
      
      // Initialize scene trigger service with user's selected targets and episode data
      await _sceneTrigger.initialize(
        targetTime: userTargetTime,
        targetDistance: userTargetDistance,
        episode: episode,
      );
      
      // Set up scene trigger callbacks
      _sceneTrigger.onSceneStart = _onSceneStart;
      
      // Start progress monitoring (but without blocking timers)
      if (kDebugMode) {
        print('🚀 Starting progress monitor (without blocking timers)...');
      }
      
      // Check if progress monitor can be started
      try {
        await _progressMonitor.start();
        if (kDebugMode) {
          print('✅ Progress monitor started (without blocking timers)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Progress monitor failed to start: $e');
        }
        // Don't rethrow - just log the error and continue
      }
      
      // Start scene trigger system
      // Force debug logging for testing
      print('🎬 Starting scene trigger system...');
      
      _sceneTrigger.start();
      
      print('✅ Scene trigger system started');
      
      // Notify state change
      print('🔄 RunSessionManager: Notifying session state change to: ${sessionState.name}');
      onSessionStateChanged?.call(sessionState);
      
      // State change notification completed
      
    } catch (e) {
      rethrow;
    }
  }

  /// Pause the current session
  Future<void> pauseSession() async {
    if (!_isSessionActive || _isPaused) return;
    
    _sessionPauseTime = DateTime.now();
    _isPaused = true;
    
    // Pause all services
    _progressMonitor.pause();
    _sceneTrigger.pause();
    await _audioManager.pauseAll();
    
    // Notify state change
    onSessionStateChanged?.call(sessionState);
  }

  /// Resume the current session
  Future<void> resumeSession() async {
    if (_isSessionActive || !_isPaused) return;
    
    // Don't resume if timers were explicitly stopped
    if (_timersStopped) return;
    
    if (_sessionPauseTime != null) {
      _totalPausedTime += DateTime.now().difference(_sessionPauseTime!);
      _sessionPauseTime = null;
    }
    
    _isPaused = false;
    
    // Resume all services
    _progressMonitor.resume();
    _sceneTrigger.resume();
    await _audioManager.resumeAll();
    
    // Notify state change
    onSessionStateChanged?.call(sessionState);
  }
  
  /// Enable single audio file mode for the current session
  Future<void> enableSingleAudioFileMode({
    required String audioFilePath,
    required Map<SceneType, Duration> sceneTimestamps,
  }) async {
    if (!_isSessionActive) {
      if (kDebugMode) {
        print('❌ Cannot enable single audio file mode: session not active');
      }
      return;
    }
    
    try {
      if (kDebugMode) {
        print('🎵 Enabling single audio file mode: $audioFilePath');
        print('🎵 Scene timestamps: $sceneTimestamps');
      }
      
      // Update the scene trigger service with single audio file
      _sceneTrigger.setSingleAudioFile(audioFilePath);
      _sceneTrigger.updateSceneTimestamps(sceneTimestamps);
      
      // Re-initialize with single audio file mode
      await _sceneTrigger.initialize(
        targetTime: _userTargetTime,
        targetDistance: _userTargetDistance,
        episode: _currentEpisode,
        singleAudioFile: audioFilePath,
        sceneTimestamps: sceneTimestamps,
      );
      
      if (kDebugMode) {
        print('✅ Single audio file mode enabled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to enable single audio file mode: $e');
      }
    }
  }
  
  // Convert scene timestamps from Firebase format to Duration format
  Map<SceneType, Duration> _convertSceneTimestampsToDurations(List<Map<String, dynamic>> sceneTimestamps) {
    final Map<SceneType, Duration> result = {};
    
    for (final scene in sceneTimestamps) {
      final sceneTypeString = scene['sceneType'] as String?;
      final startSeconds = scene['startSeconds'] as int?;
      
      if (sceneTypeString != null && startSeconds != null) {
        // Convert string to SceneType enum
        SceneType? sceneType;
        switch (sceneTypeString) {
          case 'missionBriefing':
            sceneType = SceneType.scene1;
            break;
          case 'theJourney':
            sceneType = SceneType.scene2;
            break;
          case 'firstContact':
            sceneType = SceneType.scene3;
            break;
          case 'theCrisis':
            sceneType = SceneType.scene4;
            break;
          case 'extractionDebrief':
            sceneType = SceneType.scene5;
            break;
        }
        
        if (sceneType != null) {
          result[sceneType] = Duration(seconds: startSeconds);
        }
      }
    }
    
    return result;
  }

  /// Stop the current run session and save data
  void stopSession() {
    print('🛑 RunSessionManager: stopSession() called from: ${StackTrace.current}');
    print('🛑 RunSessionManager: stopSession() - _isSessionActive before: $_isSessionActive');
    
    if (!_isSessionActive) {
      print('🛑 RunSessionManager: stopSession() - Session already inactive, returning early');
      return;
    }

    _isSessionActive = false;
    print('🛑 RunSessionManager: stopSession() - _isSessionActive set to: $_isSessionActive');
    
    _progressMonitor.forceStopMonitoring();
    print('🛑 RunSessionManager: stopSession() - Progress monitor stopped, route cleared');
    
    _audioManager.stopAll();
    print('🛑 RunSessionManager: stopSession() - All audio stopped');
    
    _sceneTrigger.stop();
    print('🛑 RunSessionManager: stopSession() - Scene trigger service stopped');
    
    // Clear all callbacks to prevent further updates
    _clearAllCallbacks();
    
    print('🛑 RunSessionManager: stopSession() completed');
  }

  /// Complete the current session
  Future<void> completeSession() async {
    print('🎯 RunSessionManager: completeSession() called from: ${StackTrace.current}');
    print('🎯 RunSessionManager: completeSession() - _isSessionActive: $_isSessionActive');
    
    if (!_isSessionActive) {
      print('🎯 RunSessionManager: completeSession() - Session already inactive, returning early');
      return;
    }
    
    print('🎯 RunSessionManager: completeSession() - Session completion requested - waiting for user to finish run');
    
    // Note: We no longer automatically stop the session here
    // The user must manually finish the run to preserve GPS data
    print('🎯 RunSessionManager: completeSession() - Session remains active until user finishes run');
  }

  /// Ensure all scenes have played before completing
  Future<void> _ensureAllScenesPlayed() async {
    final allScenes = SceneType.values;
    final remainingScenes = allScenes.where((scene) => !_sceneTrigger.playedScenes.contains(scene));
    
    for (final scene in remainingScenes) {
      // Force trigger remaining scenes
      _sceneTrigger.updateProgress(progress: 1.0);
    }
    
    // Wait for all scenes to complete
    while (_sceneTrigger.isScenePlaying) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Manually complete session when user finishes run (preserves GPS data)
  Future<void> manuallyCompleteSession() async {
    print('🎯 RunSessionManager: manuallyCompleteSession() called from: ${StackTrace.current}');
    print('🎯 RunSessionManager: manuallyCompleteSession() - _isSessionActive before: $_isSessionActive');
    
    if (!_isSessionActive) {
      print('🎯 RunSessionManager: manuallyCompleteSession() - Session already inactive, cannot complete');
      return;
    }
    
    print('🎯 RunSessionManager: manuallyCompleteSession() - Calling stopSession() to clean up');
    stopSession();
    print('🎯 RunSessionManager: manuallyCompleteSession() completed');
  }



  /// Handle progress updates
  void _onProgressUpdate(double progress, Duration elapsedTime, double distance) {
    // Don't process updates if session is stopped or globally stopped
    if (_globallyStopped || (!_isSessionActive && _isPaused == false)) {
      if (kDebugMode) {
        print('📊 Progress update ignored - session stopped or globally stopped');
        print('📊 _globallyStopped: $_globallyStopped, _isSessionActive: $_isSessionActive, _isPaused: $_isPaused');
      }
      return;
    }
    
    if (kDebugMode) {
      print('📊 Progress update received: ${(progress * 100).toStringAsFixed(1)}%');
    }
    
    onProgressUpdated?.call(progress);
    
    // Update scene trigger service with progress
    if (_isSessionActive && !_isPaused) {
      _sceneTrigger.updateProgress(progress: progress, elapsedTime: elapsedTime, distance: distance);
    }
    
    // Update stats to reflect the new progress
    _updateStats();
  }

  /// Handle distance updates
  void _onDistanceUpdate(double distance) {
    // Update scene trigger service with distance
    if (_isSessionActive && !_isPaused) {
      _sceneTrigger.updateProgress(distance: distance);
    }
    
    // Update stats
    _updateStats();
  }

  /// Handle time updates
  void _onTimeUpdate(Duration time) {
    if (kDebugMode) {
      print('⏰ Time update received: ${time.inSeconds}s');
    }
    
    // Update scene trigger service with time
    if (_isSessionActive && !_isPaused) {
      _sceneTrigger.updateProgress(elapsedTime: time);
    }
    
    // Update stats to reflect the new time
    _updateStats();
    
    // NEW: Notify listeners of time updates
    onTimeUpdated?.call(time);
  }

  /// Handle route updates
  void _onRouteUpdate(List<dynamic> route) {
    // Convert to LocationPoint list and forward
    try {
      final converted = route.map((e) {
        // e can be geolocator Position or our LocationPoint
        if (e is LocationPoint) return e;
        return LocationPoint(
          latitude: e.latitude as double,
          longitude: e.longitude as double,
          accuracy: (e.accuracy as num).toDouble(),
          altitude: (e.altitude as num).toDouble(),
          speed: (e.speed as num).toDouble(),
          elapsedSeconds: 0, // Will be calculated when saving
          heading: (e.heading as num?)?.toDouble(),
        );
      }).toList();
      onRouteUpdated?.call(converted);
    } catch (_) {}
    // Update stats
    _updateStats();
  }

  /// Handle pace updates
  void _onPaceUpdate(double pace) {
    // Update stats
    _updateStats();
  }

  /// Handle scene start
  Future<void> _onSceneStart(SceneType scene) async {
    if (kDebugMode) {
      print('🎬 Scene started: ${SceneTriggerService.getSceneTitle(scene)}');
    }
    
    if (kDebugMode) {
      print('🎬 About to call onSceneStarted callback...');
    }
    onSceneStarted?.call(scene);
    if (kDebugMode) {
      print('🎬 onSceneStarted callback completed');
    }

    // Duck internal/background music so story audio is prominent
    try {
      await _audioManager.duckBackgroundMusic(fraction: 0.10, gradual: true);
      if (kDebugMode) {
        print('🔇 RunSessionManager: Requested internal music ducking at scene start');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ RunSessionManager: Failed to duck internal music: $e');
      }
    }
    
    // Check if episode is downloaded; in single-file mode, playback is handled by SceneTriggerService
    if (_currentEpisode != null) {
      final downloadService = DownloadService();
      final episodeId = _currentEpisode!.id;
      
      if (kDebugMode) {
        print('🎵 Checking if episode $episodeId is downloaded...');
      }
      
      try {
        final isDownloaded = await downloadService.isEpisodeDownloaded(episodeId);
        
        if (isDownloaded) {
          // Audio playback is handled by SceneTriggerService for multiple files mode only
          if (_currentEpisode?.audioFiles.isNotEmpty == true) {
            if (kDebugMode) {
              print('🎵 Multiple audio files mode - playback handled by SceneTriggerService');
            }
            return;
          } else {
            if (kDebugMode) {
              print('❌ Single file mode disabled - only multiple files mode supported');
            }
            return;
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Episode not downloaded - user needs to download first');
            print('💡 User should download episode from episode detail screen');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error checking/playing local audio: $e');
        }
      }
    }
  }

  /// Handle scene completion
  void _onSceneComplete(SceneType scene) {
    onSceneCompleted?.call(scene);
    
    // Restore internal/background music volume after scene
    _audioManager.restoreBackgroundMusic(gradual: true);
  }

  /// Update and notify stats
  void _updateStats() {
    final stats = RunStats(
      distance: _progressMonitor.currentDistance,
      elapsedTime: _progressMonitor.elapsedTime,
      currentPace: _progressMonitor.currentPace,
      averagePace: _progressMonitor.averagePace,
      maxPace: _progressMonitor.maxPace,
      minPace: _progressMonitor.minPace,
      progress: _progressMonitor.progress,
      playedScenes: _sceneTrigger.playedScenes.toList(),
      currentScene: _sceneTrigger.currentScene,
      route: getCurrentRoute(),
    );
    
    if (kDebugMode) {
      print('📊 Updating stats: elapsedTime=${stats.elapsedTime.inSeconds}s, progress=${(stats.progress * 100).toStringAsFixed(1)}%');
    }
    
    if (kDebugMode) {
      print('📊 Calling onStatsUpdated callback with elapsedTime=${stats.elapsedTime.inSeconds}s');
    }
    onStatsUpdated?.call(stats);
  }

  /// Get current session state
  RunSessionState _getSessionState() {
    print('🎯 _getSessionState: _isPaused=$_isPaused, _isSessionActive=$_isSessionActive, _sceneTrigger.isScenePlaying=${_sceneTrigger.isScenePlaying}');
    print('🎯 _getSessionState: _globallyStopped=$_globallyStopped, _timersStopped=$_timersStopped');
    
    // Fix session state mismatch: if progress monitor is running, session should be active
    if (!_isSessionActive && _progressMonitor.isMonitoring) {
      print('🎯 _getSessionState: Fixing session state mismatch - progress monitor is running');
      _isSessionActive = true;
    }
    
    if (_isPaused) {
      print('🎯 Returning paused state');
      return RunSessionState.paused;
    }
    
    if (!_isSessionActive) {
      print('🎯 Returning inactive state');
      return RunSessionState.inactive;
    }
    
    if (_sceneTrigger.isScenePlaying) {
      print('🎯 Returning playingScene state');
      return RunSessionState.playingScene;
    }
    
    print('🎯 Returning running state');
    return RunSessionState.running;
  }

  /// Create run model from current session
  RunModel createRunModel() {
    print('🔍 RunSessionManager: Creating run model...');
    
    final stats = _progressMonitor.getRunStats();
    final elapsedTime = (stats['elapsedTime'] as Duration?) ?? Duration.zero;
    final completedAt = DateTime.now();

    // If _sessionStartTime is null, derive it from the completed time and duration.
    // This is a much safer fallback than using DateTime.now() for the start time.
    final startTime = _sessionStartTime ?? completedAt.subtract(elapsedTime);
    
    // Get the current user ID from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
    print('🔍 RunSessionManager: Current user ID: $currentUserId');
    
    // Check route data
    final route = _progressMonitor.route;
    print('🔍 RunSessionManager: Route has ${route.length} GPS points');
    
    return RunModel(
      userId: currentUserId,
      createdAt: startTime,
      completedAt: completedAt,
      route: route
          .map((pos) => LocationPoint(
                latitude: pos.latitude,
                longitude: pos.longitude,
                accuracy: pos.accuracy,
                altitude: pos.altitude,
                speed: pos.speed,
                elapsedSeconds: 0, // Will be calculated when saving
                heading: pos.heading,
              ))
          .toList(growable: false), // Use toList() to create a new, independent copy of the route
      totalDistance: (stats['distance'] as num?)?.toDouble() ?? 0.0,
      totalTime: elapsedTime,
      averagePace: (stats['averagePace'] as num?)?.toDouble() ?? 0.0,
      maxPace: (stats['maxPace'] as num?)?.toDouble() ?? 0.0,
      minPace: (stats['minPace'] as num?)?.toDouble() ?? 0.0,
      episodeId: _currentEpisode?.id ?? '',
      status: RunStatus.completed,
      achievements: [], // Add empty achievements list
      runTarget: RunTarget(
        id: 'episode_${_currentEpisode?.id ?? "unknown"}',
        type: RunTargetType.distance,
        value: _currentEpisode?.targetDistance ?? 0.0,
        displayName: '${_currentEpisode?.targetDistance ?? 0.0} km',
        description: 'Episode target distance',
        createdAt: DateTime.now(),
        isCustom: false,
      ),
      metadata: {
        'playedScenes': _sceneTrigger.playedScenes.map((s) => s.name).toList(),
        'totalPausedTime': _totalPausedTime.inMilliseconds,
      },
    );
  }

  /// Create run model from captured session data
  RunModel _createRunModelFromCapturedData(List<LocationPoint> route, Map<String, dynamic> stats) {
    print('🔍 RunSessionManager: Creating run model from captured session data...');
    
    // Get the current user ID from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
    print('🔍 RunSessionManager: Current user ID: $currentUserId');
    
    // Check if we have session start time
    if (_sessionStartTime == null) {
      print('❌ RunSessionManager: _sessionStartTime is null! Using current time as fallback.');
      _sessionStartTime = DateTime.now().subtract(const Duration(minutes: 30)); // Use a reasonable fallback
    }
    
    print('🔍 RunSessionManager: Captured route has ${route.length} GPS points');
    if (route.isNotEmpty) {
      print('🔍 RunSessionManager: First point: ${route.first.latitude}, ${route.first.longitude}');
      print('🔍 RunSessionManager: Last point: ${route.last.latitude}, ${route.last.longitude}');
    }
    
    return RunModel(
      userId: currentUserId,
      createdAt: _sessionStartTime ?? DateTime.now(),
      completedAt: DateTime.now(),
      route: route
          .map((pos) => LocationPoint(
                latitude: pos.latitude,
                longitude: pos.longitude,
                accuracy: pos.accuracy,
                altitude: pos.altitude,
                speed: pos.speed,
                elapsedSeconds: 0, // Will be calculated when saving
                heading: pos.heading,
              ))
          .toList(), // Use .toList() to create a new, independent copy of the route
      totalDistance: stats['distance'] as double,
      totalTime: stats['elapsedTime'] as Duration,
      averagePace: stats['averagePace'] as double,
      maxPace: stats['maxPace'] as double,
      minPace: stats['minPace'] as double,
      episodeId: _currentEpisode?.id ?? '',
      status: RunStatus.completed,
      achievements: [], // Add empty achievements list
      runTarget: RunTarget(
        id: 'episode_${_currentEpisode?.id ?? "unknown"}',
        type: RunTargetType.distance,
        value: _currentEpisode?.targetDistance ?? 0.0,
        displayName: '${_currentEpisode?.targetDistance ?? 0.0} km',
        description: 'Episode target distance',
        createdAt: DateTime.now(),
        isCustom: false,
      ),
      metadata: {
        'playedScenes': _sceneTrigger.playedScenes.map((s) => s.name).toList(),
        'totalPausedTime': _totalPausedTime.inMilliseconds,
      },
    );
  }

  /// Get current session statistics
  RunStats getCurrentStats() {
    print('🔍 RunSessionManager: getCurrentStats() called');
    print('🔍 RunSessionManager: Progress monitor - distance: ${_progressMonitor.currentDistance}, elapsedTime: ${_progressMonitor.elapsedTime}');
    print('🔍 RunSessionManager: Progress monitor - isMonitoring: ${_progressMonitor.isMonitoring}');
    return RunStats(
      distance: _progressMonitor.currentDistance,
      elapsedTime: _progressMonitor.elapsedTime,
      currentPace: _progressMonitor.currentPace,
      averagePace: _progressMonitor.averagePace,
      maxPace: _progressMonitor.maxPace,
      minPace: _progressMonitor.minPace,
      progress: _progressMonitor.progress,
      playedScenes: _sceneTrigger.playedScenes.toList(),
      currentScene: _sceneTrigger.currentScene,
      route: getCurrentRoute(),
    );
  }
  
  /// Get current GPS route from progress monitor
  List<LocationPoint> getCurrentRoute() {
    final route = _progressMonitor.route;
    print('🔍 RunSessionManager: getCurrentRoute() called - Progress monitor route has ${route.length} points');
    print('🔍 RunSessionManager: _isSessionActive: $_isSessionActive, _isPaused: $_isPaused');
    return route
        .map((pos) => LocationPoint(
              latitude: pos.latitude,
              longitude: pos.longitude,
              accuracy: pos.accuracy,
              altitude: pos.altitude,
              speed: pos.speed,
              elapsedSeconds: 0, // Will be calculated when saving
              heading: pos.heading,
            ))
        .toList();
  }

  /// Public getter to access the progress monitor directly
  ProgressMonitorService get progressMonitor => _progressMonitor;
  
  /// Public method to stop the progress timer directly
  void stopProgressTimer() {
    _timersStopped = true; // Prevent timers from being restarted
    _progressMonitor.stopTimer();
  }
  
  /// Force stop the progress monitor
  void forceStopProgressMonitor() {
    // Set global stop flag first
    _globallyStopped = true;
    
    // Force stop the progress monitor
    _progressMonitor.forceStopMonitoring();
    
    // Also force stop the scene trigger service
    _sceneTrigger.stop();
    
    print('🛑 RunSessionManager: Progress monitor and scene trigger forced to stop');
  }
  
  /// Reset the global stop flag (for restarting)
  void resetGlobalStop() {
    _globallyStopped = false;
    print('🔄 RunSessionManager: Global stop flag reset');
  }
  
  /// Completely disable all timers and monitoring
  void disableAllTimers() {
    _globallyStopped = true;
    _timersStopped = true;
    
    // Force stop all services
    _progressMonitor.forceStopMonitoring();
    _sceneTrigger.stop();
    
    print('🛑 RunSessionManager: All timers and monitoring disabled');
  }
  
  /// Nuclear option: completely kill everything
  void nuclearStop() {
    _globallyStopped = true;
    _timersStopped = true;
    
    // Use nuclear stop on progress monitor
    _progressMonitor.nuclearStop();
    
    // Stop scene trigger
    _sceneTrigger.stop();
    
    // Clear all callbacks to prevent further updates
    _clearAllCallbacks();
    
    // Ensure session marked inactive so a new run can start later
    _isSessionActive = false;
    _isPaused = false;
    print('☢️ RunSessionManager: NUCLEAR STOP - Everything killed; session marked inactive');
  }

  /// Prepare the manager for a brand new run after a hard stop
  void prepareForNewRun() {
    _globallyStopped = false;
    _timersStopped = false;
    _isSessionActive = false;
    _isPaused = false;
    print('🔄 RunSessionManager: Prepared for new run (flags reset)');
  }
  
  /// Clear all callbacks to prevent further updates
  void _clearAllCallbacks() {
    onSessionStateChanged = null;
    onSceneStarted = null;
    onSceneCompleted = null;
    onProgressUpdated = null;
    onStatsUpdated = null;
    onRouteUpdated = null;
    onTimeUpdated = null;
    print('🛑 RunSessionManager: All callbacks cleared');
  }
  
  /// Dispose resources
  void dispose() {
    print('🔄 RunSessionManager: Setting _isSessionActive = false in dispose()');
    _isSessionActive = false;
    print('🔄 RunSessionManager: Setting _isPaused = false in dispose()');
    _isPaused = false;
    _progressMonitor.dispose();
    _sceneTrigger.dispose();
    _audioManager.dispose();
  }
}

/// Run session state
enum RunSessionState {
  inactive,
  running,
  playingScene,
  paused,
}
