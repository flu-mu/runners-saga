import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'progress_monitor_service.dart';
import 'scene_trigger_service.dart';
import 'audio_manager.dart';
import '../models/episode_model.dart';
import '../models/run_model.dart';
import '../models/run_target_model.dart';
import '../providers/settings_providers.dart';

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
  
  // Callbacks
  Function(RunSessionState state)? onSessionStateChanged;
  Function(SceneType scene)? onSceneStarted;
  Function(SceneType scene)? onSceneCompleted;
  Function(double progress)? onProgressUpdated;
  Function(RunStats stats)? onStatsUpdated;
  Function(List<LocationPoint> route)? onRouteUpdated;
  
  // Getters
  bool get isSessionActive => _isSessionActive;
  bool get isPaused => _isPaused;
  EpisodeModel? get currentEpisode => _currentEpisode;
  RunModel? get currentRun => _currentRun;
  RunSessionState get sessionState => _getSessionState();
  double get currentProgress => _progressMonitor.progress;
  List<SceneType> get playedScenes => _sceneTrigger.playedScenes.toList();

  /// Initialize the run session manager
  Future<void> initialize() async {
    await _audioManager.initialize();
    
    // Set up scene trigger callbacks
    _sceneTrigger.onSceneStart = _onSceneStart;
    _sceneTrigger.onSceneComplete = _onSceneComplete;
    _sceneTrigger.onProgressUpdate = _onProgressUpdate;
  }

  /// Check if a new session can be started
  bool canStartSession() {
    return !_isSessionActive && !_progressMonitor.isStopped && !_globallyStopped;
  }
  
  /// Start a new run session
  Future<void> startSession(
    EpisodeModel episode, {
    required Duration userTargetTime,
    required double userTargetDistance,
    required TrackingMode trackingMode,
  }) async {
    if (_isSessionActive) {
      throw Exception('Session already active');
    }
    
    // Check if progress monitor is stopped
    if (_progressMonitor.isStopped) {
      print('🛑 RunSessionManager: Cannot start session - progress monitor is stopped');
      throw Exception('Progress monitor is stopped and cannot be restarted');
    }
    
    try {
      _currentEpisode = episode;
      _sessionStartTime = DateTime.now();
      _isSessionActive = true;
      _isPaused = false;
      
      // Initialize progress monitor with user's selected targets
      _progressMonitor.initialize(
        targetTime: userTargetTime,
        targetDistance: userTargetDistance,
        trackingMode: trackingMode,
        onDistanceUpdate: _onDistanceUpdate,
        onTimeUpdate: _onTimeUpdate,
        onPaceUpdate: _onPaceUpdate,
        onProgressUpdate: _onProgressUpdate,
        onRouteUpdate: _onRouteUpdate,
      );
      
      // Initialize scene trigger service with user's selected targets
      _sceneTrigger.initialize(
        targetTime: userTargetTime,
        targetDistance: userTargetDistance,
        episodeId: episode.id,
        onSceneStart: _onSceneStart,
        onSceneComplete: _onSceneComplete,
        onProgressUpdate: _onProgressUpdate,
      );
      
      // Load audio files from the database for this episode
      // Force debug logging for testing
      print('🎵 Loading audio files for episode: ${episode.id}');
      print('📋 Episode audio files: ${episode.audioFiles}');
      print('📊 Audio files count: ${episode.audioFiles.length}');
      
      SceneTriggerService.loadAudioFilesFromDatabase(episode.audioFiles);
      
      // Start progress monitoring
      if (kDebugMode) {
        print('🚀 Starting progress monitor...');
      }
      
      // Check if progress monitor can be started
      try {
        await _progressMonitor.start();
        if (kDebugMode) {
          print('✅ Progress monitor started');
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

  /// Stop the current session
  Future<void> stopSession() async {
    if (!_isSessionActive && !_isPaused) return;
    
    _isSessionActive = false;
    _isPaused = false;
    _globallyStopped = true; // Set global stop flag
    _currentEpisode = null;
    
    // Force stop the progress monitor first
    _progressMonitor.forceStopMonitoring();
    
    // Stop all other services
    _progressMonitor.stop();
    _sceneTrigger.stop();
    await _audioManager.stopAll();
    
    // Create run model
    _currentRun = _createRunModel();
    
    // Notify state change
    onSessionStateChanged?.call(sessionState);
    
    print('🛑 RunSessionManager: Session stopped - all services stopped');
  }

  /// Complete the current session
  Future<void> completeSession() async {
    if (!_isSessionActive && !_isPaused) return;
    
    try {
      // Ensure all scenes have played
      await _ensureAllScenesPlayed();
      
      // Stop the session
      await stopSession();
      
      // Mark episode as completed
      if (_currentEpisode != null) {
        // This would typically update the database
        if (kDebugMode) {
          print('Episode ${_currentEpisode!.id} completed');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error completing session: $e');
      }
      rethrow;
    }
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



  /// Handle progress updates
  void _onProgressUpdate(double progress) {
    // Don't process updates if session is stopped or globally stopped
    if (_globallyStopped || (!_isSessionActive && _isPaused == false)) {
      if (kDebugMode) {
        print('📊 Progress update ignored - session stopped or globally stopped');
      }
      return;
    }
    
    if (kDebugMode) {
      print('📊 Progress update received: ${(progress * 100).toStringAsFixed(1)}%');
    }
    
    onProgressUpdated?.call(progress);
    
    // Update scene trigger service with progress
    if (_isSessionActive && !_isPaused) {
      _sceneTrigger.updateProgress(progress: progress);
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
          timestamp: e.timestamp as DateTime,
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
    
    // Load and play the first available audio file
    final audioFile = SceneTriggerService.getFirstSceneAudioFile();
    if (audioFile.isNotEmpty) {
      if (kDebugMode) {
        print('🎵 Loading first audio file: $audioFile');
        print('📋 All available files: ${SceneTriggerService.getAvailableAudioFiles()}');
        print('🎵 Starting audio immediately...');
      }
      
      // Try using URL source instead of AssetSource
      try {
        // Use URL source pointing directly to the web server
        // The audioFile already contains the full path from the database
        final url = 'http://localhost:8080/assets/$audioFile';
        
        // Create a local player variable to handle completion
        final player = AudioPlayer();
        
        // Set up completion listener
        player.onPlayerComplete.listen((_) {
          if (kDebugMode) {
            print('🎵 Audio completed: $audioFile');
          }
          // Notify scene completion
          onSceneCompleted?.call(scene);
          player.dispose();
        });
        
        await player.setSourceUrl(url);
        await player.resume();
        
        if (kDebugMode) {
          print('🎵 Audio loaded with URL: $url');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error loading audio: $e');
        }
      }
    }
  }

  /// Handle scene completion
  void _onSceneComplete(SceneType scene) {
    onSceneCompleted?.call(scene);
    
    // Background music handling removed to avoid issues
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
  RunModel _createRunModel() {
    final stats = _progressMonitor.getRunStats();
    
    return RunModel(
      userId: 'current_user_id', // This should come from auth
      startTime: _sessionStartTime!,
      endTime: DateTime.now(),
      route: _progressMonitor.route
          .map((pos) => LocationPoint(
                latitude: pos.latitude,
                longitude: pos.longitude,
                accuracy: pos.accuracy,
                altitude: pos.altitude,
                speed: pos.speed,
                timestamp: pos.timestamp,
                heading: pos.heading,
              ))
          .toList(),
      totalDistance: stats['distance'] as double,
      totalTime: stats['elapsedTime'] as Duration,
      averagePace: stats['averagePace'] as double,
      maxPace: stats['maxPace'] as double,
      minPace: stats['minPace'] as double,
      seasonId: _currentEpisode?.seasonId ?? '',
      missionId: _currentEpisode?.id ?? '',
      status: RunStatus.completed,
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
    return _progressMonitor.route
        .map((pos) => LocationPoint(
              latitude: pos.latitude,
              longitude: pos.longitude,
              accuracy: pos.accuracy,
              altitude: pos.altitude,
              speed: pos.speed,
              timestamp: pos.timestamp,
              heading: pos.heading,
            ))
        .toList();
  }

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
    
    print('☢️ RunSessionManager: NUCLEAR STOP - Everything killed');
  }
  
  /// Dispose resources
  void dispose() {
    _isSessionActive = false;
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

/// Run statistics
class RunStats {
  final double distance;
  final Duration elapsedTime;
  final double currentPace;
  final double averagePace;
  final double maxPace;
  final double minPace;
  final double progress;
  final List<SceneType> playedScenes;
  final SceneType? currentScene;
  final List<LocationPoint> route;
  
  RunStats({
    required this.distance,
    required this.elapsedTime,
    required this.currentPace,
    required this.averagePace,
    required this.maxPace,
    required this.minPace,
    required this.progress,
    required this.playedScenes,
    this.currentScene,
    required this.route,
  });
}


