import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'progress_monitor_service.dart';
import '../story/scene_trigger_service.dart';
import '../audio/audio_manager.dart';
import '../firebase/firestore_service.dart';
import '../audio/download_service.dart';
import '../firebase/firebase_storage_service.dart';
import '../../models/episode_model.dart';
import '../../models/run_model.dart';
import '../../models/run_target_model.dart';
import '../../providers/settings_providers.dart';

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
    return !_isSessionActive; // Only check if session is not already active
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
    
    // Progress monitor can always be started
    
    try {
      _currentEpisode = episode;
      _sessionStartTime = DateTime.now();
      _isSessionActive = true;
      _isPaused = false;
      
      // Initialize progress monitor with user's selected targets
      _progressMonitor.initialize(
        targetTime: userTargetTime,
        targetDistance: userTargetDistance,
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
  void _onProgressUpdate(double progress) {
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
    
    // Check if episode is downloaded and play from local files
    if (_currentEpisode != null) {
      final downloadService = DownloadService();
      final episodeId = _currentEpisode!.id;
      
      if (kDebugMode) {
        print('🎵 Checking if episode $episodeId is downloaded...');
      }
      
      try {
        final isDownloaded = await downloadService.isEpisodeDownloaded(episodeId);
        
        if (isDownloaded) {
          // Get local files and find the correct scene file
          final localFiles = await downloadService.getLocalEpisodeFiles(episodeId);
          if (localFiles.isNotEmpty) {
            // Find the file for the specific scene
            final sceneAudioFile = SceneTriggerService.getSceneAudioFile(scene);
            final fileName = FirebaseStorageService.getFileNameFromUrl(sceneAudioFile);
            final sceneLocalFile = localFiles.firstWhere(
              (file) => file.endsWith(fileName),
              orElse: () => localFiles.first, // Fallback to first file if scene not found
            );
            
            if (kDebugMode) {
              print('🎵 Scene: ${SceneTriggerService.getSceneTitle(scene)}');
              print('🎵 Target file: $fileName');
              print('🎵 Playing from local file: $sceneLocalFile');
            }
            
            // Create a local player variable to handle completion
            final player = AudioPlayer();
            
            // Set up completion listener
            player.onPlayerComplete.listen((_) {
              if (kDebugMode) {
                print('🎵 Audio completed: $sceneLocalFile');
              }
              // Notify scene completion
              onSceneCompleted?.call(scene);
              player.dispose();
            });
            
            await player.setSourceDeviceFile(sceneLocalFile);
            await player.resume();
            
            if (kDebugMode) {
              print('✅ Audio playing from local file: $sceneLocalFile');
            }
          } else {
            if (kDebugMode) {
              print('⚠️ Episode marked as downloaded but no local files found');
            }
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
    print('🎯 _getSessionState: _globallyStopped=$_globallyStopped, _timersStopped=$_timersStopped');
    
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
    print('🔍 RunSessionManager: Progress monitor stats: $stats');
    
    // Get the current user ID from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
    print('🔍 RunSessionManager: Current user ID: $currentUserId');
    
    // Check if we have session start time
    if (_sessionStartTime == null) {
      print('❌ RunSessionManager: _sessionStartTime is null! Using current time as fallback.');
      _sessionStartTime = DateTime.now().subtract(const Duration(minutes: 30)); // Use a reasonable fallback
    }
    
    // Check route data
    final route = _progressMonitor.route;
    print('🔍 RunSessionManager: Route has ${route.length} GPS points');
    if (route.isNotEmpty) {
      print('🔍 RunSessionManager: First point: ${route.first.latitude}, ${route.first.longitude}');
      print('🔍 RunSessionManager: Last point: ${route.last.latitude}, ${route.last.longitude}');
    }
    
    return RunModel(
      userId: currentUserId,
      startTime: _sessionStartTime!,
      endTime: DateTime.now(),
      route: route
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
      startTime: _sessionStartTime!,
      endTime: DateTime.now(),
      route: route
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
              timestamp: pos.timestamp,
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
    
    print('☢️ RunSessionManager: NUCLEAR STOP - Everything killed');
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


