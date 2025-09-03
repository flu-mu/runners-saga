import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/run/run_session_manager.dart';
import '../services/story/scene_trigger_service.dart';
import '../services/run/progress_monitor_service.dart';
import '../models/episode_model.dart';
import '../models/run_model.dart';
import '../models/run_target_model.dart';
import '../models/run_enums.dart';
import 'settings_providers.dart';

part 'run_session_providers.g.dart';

/// Provider for the Run Session Manager
@riverpod
RunSessionManager runSessionManager(RunSessionManagerRef ref) {
  final manager = RunSessionManager();
  
  // Initialize the manager
  manager.initialize();
  
  // Don't dispose immediately - let the controller manage the lifecycle
  // ref.onDispose(() {
  //   manager.dispose();
  // });
  
  return manager;
}



/// Provider for the current run session state
@riverpod
class CurrentRunSession extends _$CurrentRunSession {
  @override
  RunSessionState build() {
    return RunSessionState.inactive;
  }
  
  void updateState(RunSessionState newState) {
    state = newState;
  }
}

/// Provider for the current run progress
@riverpod
class CurrentRunProgress extends _$CurrentRunProgress {
  @override
  double build() {
    return 0.0;
  }
  
  void updateProgress(double progress) {
    state = progress;
  }
}

/// Provider for the current run statistics
@riverpod
class CurrentRunStats extends _$CurrentRunStats {
  @override
  RunStats? build() {
    return null;
  }
  
  void updateStats(RunStats stats) {
    state = stats;
  }
}

/// Provider for the currently playing scene
@riverpod
class CurrentScene extends _$CurrentScene {
  @override
  SceneType? build() {
    return null;
  }
  
  void updateScene(SceneType? scene) {
    state = scene;
  }
}

/// Provider for the list of played scenes
@riverpod
class PlayedScenes extends _$PlayedScenes {
  @override
  List<SceneType> build() {
    return [];
  }
  
  void updatePlayedScenes(List<SceneType> scenes) {
    state = scenes;
  }
  
  void addScene(SceneType scene) {
    if (!state.contains(scene)) {
      state = [...state, scene];
    }
  }
  
  void clearScenes() {
    state = [];
  }
}

/// Provider for the user's selected run target
@Riverpod(keepAlive: true)
class UserRunTarget extends _$UserRunTarget {
  @override
  RunTargetSelection? build() {
    return null;
  }
  
  void setRunTarget(RunTargetSelection target) {
    state = target;
  }
  
  void clearRunTarget() {
    state = null;
  }
}

/// Provider for the current episode being run
@riverpod
class CurrentRunEpisode extends _$CurrentRunEpisode {
  @override
  EpisodeModel? build() {
    return null;
  }
  
  void setEpisode(EpisodeModel episode) {
    state = episode;
  }
  
  void clearEpisode() {
    state = null;
  }
}

/// Provider for the completed run data
@riverpod
class CompletedRun extends _$CompletedRun {
  @override
  RunModel? build() {
    return null;
  }
  
  void setCompletedRun(RunModel run) {
    state = run;
  }
  
  void clearCompletedRun() {
    state = null;
  }
}

/// Provider for the run session manager with state synchronization
@riverpod
class RunSessionController extends _$RunSessionController {
  @override
  RunSessionManager build() {
    final manager = ref.read(runSessionManagerProvider);
    
    // Set up state synchronization
    _setupStateSync(manager);
    
    return manager;
  }
  
  void _setupStateSync(RunSessionManager manager) {
    manager.onSessionStateChanged = (state) {
      ref.read(currentRunSessionProvider.notifier).updateState(state);
    };
    
    manager.onProgressUpdated = (progress) {
      ref.read(currentRunProgressProvider.notifier).updateProgress(progress);
    };
    
    manager.onStatsUpdated = (stats) {
      ref.read(currentRunStatsProvider.notifier).updateStats(stats);
    };
    
    manager.onSceneStarted = (scene) {
      ref.read(currentSceneProvider.notifier).updateScene(scene);
      ref.read(playedScenesProvider.notifier).addScene(scene);
    };
    
    manager.onSceneCompleted = (scene) {
      ref.read(currentSceneProvider.notifier).updateScene(null);
      // Mark the scene as completed in the played scenes list
      ref.read(playedScenesProvider.notifier).addScene(scene);
    };
    
    // Store onTimeUpdated callback for external access
    _onTimeUpdated = manager.onTimeUpdated;
  }
  
  // Store the callback for external access
  Function(Duration time)? _onTimeUpdated;
  
  // Expose session state getter
  RunSessionState get sessionState => state.sessionState;
  
  /// Start a new run session
  Future<void> startSession(
    EpisodeModel episode, {
    required Duration userTargetTime,
    required double userTargetDistance,
    required TrackingMode trackingMode,
  }) async {
    try {
      // Set the current episode
      ref.read(currentRunEpisodeProvider.notifier).setEpisode(episode);
      
      // Start the session with user's selected targets
      await state.startSession(
        episode,
        userTargetTime: userTargetTime,
        userTargetDistance: userTargetDistance,
        trackingMode: trackingMode,
      );
    } catch (e) {
      // Handle error
      rethrow;
    }
  }
  
  /// Pause the current session
  Future<void> pauseSession() async {
    try {
      await state.pauseSession();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Resume the current session
  Future<void> resumeSession() async {
    try {
      await state.resumeSession();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Stop the current session
  void stopSession() {
    try {
      state.stopSession();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Complete the current session
  Future<void> completeSession() async {
    try {
      await state.completeSession();
      
      // Get the completed run
      final completedRun = state.currentRun;
      if (completedRun != null) {
        ref.read(completedRunProvider.notifier).setCompletedRun(completedRun);
      }
      
      // Clear current episode
      ref.read(currentRunEpisodeProvider.notifier).clearEpisode();
      
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  /// Manually complete session when user finishes run (preserves GPS data)
  Future<void> manuallyCompleteSession() async {
    try {
      await state.manuallyCompleteSession();
      
      // Get the completed run
      final completedRun = state.currentRun;
      if (completedRun != null) {
        ref.read(completedRunProvider.notifier).setCompletedRun(completedRun);
      }
      
      // Clear current episode
      ref.read(currentRunEpisodeProvider.notifier).clearEpisode();
      
    } catch (e) {
      // Handle error
      rethrow;
    }
  }
  
  /// Stop the progress timer directly
  void stopProgressTimer() {
    state.stopProgressTimer();
  }
  
  /// Force stop the progress monitor
  void forceStopProgressMonitor() {
    state.forceStopProgressMonitor();
  }
  
  /// Reset the global stop flag
  void resetGlobalStop() {
    state.resetGlobalStop();
  }
  
  /// Completely disable all timers and monitoring
  void disableAllTimers() {
    state.disableAllTimers();
  }
  
  /// Nuclear option: completely kill everything
  void nuclearStop() {
    state.nuclearStop();
  }
  
  /// Check if a new session can be started
  bool canStartSession() {
    return state.canStartSession();
  }
  
  /// Get current session statistics
  RunStats? getCurrentStats() {
    return state.getCurrentStats();
  }
  
  /// Get current GPS route from progress monitor
  List<LocationPoint> getCurrentRoute() {
    return state.getCurrentRoute();
  }
  
  /// Check if session is active
  bool get isSessionActive => state.isSessionActive;
  
  /// Get current progress
  double get currentProgress => state.currentProgress;
  
  /// Get played scenes
  List<SceneType> get playedScenes => state.playedScenes;

  // Expose the callback setter
  set onTimeUpdated(Function(Duration time)? callback) {
    _onTimeUpdated = callback;
    // Ensure the callback is set on the underlying manager
    if (state != null) {
      state.onTimeUpdated = callback;
      print('🔗 RunSessionController: onTimeUpdated callback set on manager: ${callback != null ? 'connected' : 'disconnected'}');
    } else {
      print('⚠️ RunSessionController: Cannot set onTimeUpdated - state is null');
    }
  }
}

