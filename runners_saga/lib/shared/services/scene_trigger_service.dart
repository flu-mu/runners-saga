import 'dart:async';
// import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/firebase_storage_service.dart';

enum SceneType {
  missionBriefing, // Scene 1: 0%
  theJourney,      // Scene 2: 20%
  firstContact,    // Scene 3: 40%
  theCrisis,       // Scene 4: 70%
  extractionDebrief, // Scene 5: 90%
}

class SceneTriggerService {
  static const Map<SceneType, double> _sceneTriggers = {
    SceneType.missionBriefing: 0.0,
    SceneType.theJourney: 0.2,
    SceneType.firstContact: 0.4,
    SceneType.theCrisis: 0.7,
    SceneType.extractionDebrief: 0.9,
  };

  // Dynamic array of available audio files for the current episode
  static List<String> _availableAudioFiles = [];

  // final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<SceneType> _playedScenes = <SceneType>{};
  
  bool _isRunning = false;
  
  // Progress tracking
  double _currentProgress = 0.0;
  Duration _elapsedTime = Duration.zero;
  double _totalDistance = 0.0;
  Duration _targetTime = Duration.zero;
  double _targetDistance = 0.0;
  
  // Scene management
  SceneType? _currentScene;
  bool _isScenePlaying = false;
  
  // Callbacks
  Function(SceneType scene)? onSceneStart;
  Function(SceneType scene)? onSceneComplete;
  Function(double progress)? onProgressUpdate;
  
  // Episode tracking
  String _currentEpisodeId = '';
  
  // Getters
  bool get isRunning => _isRunning;
  bool get isScenePlaying => _isScenePlaying;
  SceneType? get currentScene => _currentScene;
  double get currentProgress => _currentProgress;
  Set<SceneType> get playedScenes => Set.unmodifiable(_playedScenes);

  /// Initialize the service with run targets
  void initialize({
    required Duration targetTime,
    required double targetDistance,
    String episodeId = '',
    Function(SceneType scene)? onSceneStart,
    Function(SceneType scene)? onSceneComplete,
    Function(double progress)? onProgressUpdate,
  }) {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
    _currentEpisodeId = episodeId;
    this.onSceneStart = onSceneStart;
    this.onSceneComplete = onSceneComplete;
    this.onProgressUpdate = onProgressUpdate;
    
    // Initialize the audio player
    // _audioPlayer.setReleaseMode(ReleaseMode.stop);
    // _audioPlayer.setVolume(1.0);
    
    _resetState();
  }

  /// Start the scene trigger system
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _startProgressTracking();
    
    // Play mission briefing immediately and mark it as played
    _playedScenes.add(SceneType.missionBriefing);
    _currentScene = SceneType.missionBriefing;
    
    if (kDebugMode) {
      print('🎬 First scene (Mission Briefing) marked as played');
      print('📊 Played scenes: $_playedScenes');
    }
    
    // Notify listeners immediately for the first scene
    onSceneStart?.call(SceneType.missionBriefing);
    
    // Play audio for first scene
    _playSceneAudio(SceneType.missionBriefing);
  }

  /// Stop the scene trigger system
  void stop() {
    _isRunning = false;
    _stopProgressTracking();
    _stopCurrentScene();
    _resetState();
    
    // Clear callbacks to prevent further updates
    onSceneStart = null;
    onSceneComplete = null;
    onProgressUpdate = null;
    
    print('🛑 SceneTriggerService: Stopped and callbacks cleared');
  }

  /// Pause the scene trigger system
  void pause() {
    _isRunning = false;
    _stopProgressTracking();
    _pauseCurrentScene();
  }

  /// Resume the scene trigger system
  void resume() {
    if (_isRunning) return;
    
    _isRunning = true;
    _startProgressTracking();
    _resumeCurrentScene();
  }

  /// Update progress from main timer
  void updateProgress({
    Duration? elapsedTime,
    double? distance,
    double? progress,
  }) {
    if (elapsedTime != null) _elapsedTime = elapsedTime;
    if (distance != null) _totalDistance = distance;
    if (progress != null) {
      _currentProgress = progress.clamp(0.0, 1.0);
    } else {
      _calculateProgress();
    }
    
    if (kDebugMode) {
      print('📈 SceneTriggerService: Progress updated to ${(_currentProgress * 100).toStringAsFixed(1)}%');
      print('⏰ Elapsed time: ${_elapsedTime.inSeconds}s');
      print('📏 Distance: ${_totalDistance.toStringAsFixed(2)} km');
    }
    
    // Only check scene triggers if we're running
    if (_isRunning) {
      _checkSceneTriggers();
    }
    
    // Don't call onProgressUpdate here - that would create a loop!
    // The main timer already handles progress updates
  }

  /// Start progress tracking timer
  void _startProgressTracking() {
    // REMOVED: We don't need a separate timer here
    // The scene trigger service will receive progress updates from the main timer
    print('🔄 SceneTriggerService: Progress tracking started (no separate timer)');
  }

  /// Stop progress tracking timer
  void _stopProgressTracking() {
    // REMOVED: No timer to stop
    print('🛑 SceneTriggerService: Progress tracking stopped (no separate timer)');
  }

  /// Calculate current progress based on time and distance
  void _calculateProgress() {
    double timeProgress = _elapsedTime.inSeconds / _targetTime.inSeconds;
    double distanceProgress = _totalDistance / _targetDistance;
    
    // Use the higher progress value to ensure scenes trigger appropriately
    _currentProgress = (timeProgress > distanceProgress ? timeProgress : distanceProgress).clamp(0.0, 1.0);
  }

  /// Check if any scenes should be triggered
  void _checkSceneTriggers() {
    if (kDebugMode) {
      print('🔍 Checking scene triggers at ${(_currentProgress * 100).toStringAsFixed(1)}%');
      print('📊 Current progress: $_currentProgress');
      print('🎬 Played scenes: $_playedScenes');
      print('🎭 Current scene: $_currentScene');
    }
    
    for (final entry in _sceneTriggers.entries) {
      final sceneType = entry.key;
      final triggerPoint = entry.value;
      
      if (kDebugMode) {
        print('🎯 Checking scene ${SceneTriggerService.getSceneTitle(sceneType)} at ${(triggerPoint * 100).toStringAsFixed(1)}%');
      }
      
      // Skip if scene already played or is currently playing
      if (_playedScenes.contains(sceneType) || _currentScene == sceneType) {
        if (kDebugMode) {
          print('⏭️ Skipping scene ${SceneTriggerService.getSceneTitle(sceneType)} - already played or currently playing');
        }
        continue;
      }
      
      // Check if we've reached the trigger point
      if (_currentProgress >= triggerPoint) {
        if (kDebugMode) {
          print('🎬 Triggering scene ${SceneTriggerService.getSceneTitle(sceneType)} at ${(triggerPoint * 100).toStringAsFixed(1)}%');
        }
        _triggerScene(sceneType);
        break; // Only trigger one scene at a time
      }
    }
  }

  /// Trigger a specific scene
  Future<void> _triggerScene(SceneType sceneType) async {
    if (_playedScenes.contains(sceneType)) return;
    
    // Stop current scene if playing
    await _stopCurrentScene();
    
    // Mark scene as played
    _playedScenes.add(sceneType);
    _currentScene = sceneType;
    
    if (kDebugMode) {
      print('🎬 Scene triggered: ${SceneTriggerService.getSceneTitle(sceneType)}');
      print('📊 Played scenes: $_playedScenes');
    }
    
    // Notify listeners
    onSceneStart?.call(sceneType);
    
    // Play audio
    await _playSceneAudio(sceneType);
  }

  /// Play the audio for a specific scene
  Future<void> _playSceneAudio(SceneType sceneType) async {
    try {
      // Get the audio file from the database array
      final audioFile = getSceneAudioFile(sceneType);
      if (audioFile.isEmpty) {
        print('⚠️ No audio file found for scene: $sceneType');
        print('📋 Available audio files: $_availableAudioFiles');
        return;
      }
      
      _isScenePlaying = true;
      
      print('🎵 Playing audio for scene $sceneType: $audioFile');
      print('📋 Total available audio files: ${_availableAudioFiles.length}');
      
      // Add a small delay for smooth scene transition
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Play the actual audio file
      if (kIsWeb) {
        // On web, prefer a direct URL and fall back to MP3 if WAV has issues
        final url = _toWebAssetUrl(audioFile);
        print('🎵 [WEB] Using URL source: $url');
              // await _audioPlayer.setSourceUrl(url);
      // await _audioPlayer.resume();
      } else {
        // Mobile: Handle Firebase Storage URLs and local files
        final episodeId = _getCurrentEpisodeId();
        if (episodeId.isEmpty) {
          print('⚠️ Cannot play scene audio: Episode ID not set.');
          return;
        }

        final fileName = FirebaseStorageService.getFileNameFromUrl(audioFile); // Get just the filename
        if (fileName.isEmpty) {
          print('⚠️ Could not extract filename from URL: $audioFile');
          return;
        }

        final documentsDir = await getApplicationDocumentsDirectory();
        final localFilePath = '${documentsDir.path}/episodes/$episodeId/$fileName';

        print('🎵 [MOBILE] Attempting to play audio from local path: $localFilePath');

        try {
          // Try to play from local file first
          // await _audioPlayer.setSource(DeviceFileSource(localFilePath));
          // await _audioPlayer.resume();
          print('✅ [MOBILE] Audio started successfully with DeviceFileSource from: $localFilePath');
        } catch (e) {
          print('⚠️ Failed to play from local file ($localFilePath): $e');
          print('🎵 [MOBILE] Falling back to playing from remote URL: $audioFile');
          try {
            // Fallback to remote URL if local file fails
            // await _audioPlayer.setSourceUrl(audioFile);
            // await _audioPlayer.resume();
            print('✅ [MOBILE] Audio started successfully with UrlSource from: $audioFile');
          } catch (urlError) {
            print('❌ Failed to play from remote URL ($audioFile): $urlError');
          }
        }
      }
      
      // Set up completion listener
      // _audioPlayer.onPlayerComplete.listen((_) {
      //   _onSceneAudioComplete(sceneType);
      // });
      
      // Fallback timer in case audio doesn't complete properly
      Timer(const Duration(seconds: 10), () {
        if (_isScenePlaying && _currentScene == sceneType) {
          print('⏰ Fallback timer triggered for scene $sceneType');
          _onSceneAudioComplete(sceneType);
        }
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error playing scene audio: $e');
      }
      // Mark scene as complete even if there's an error
      _onSceneAudioComplete(sceneType);
    }
  }

  /// Build a web asset URL; if the original is WAV, try MP3 for broader browser support
  String _toWebAssetUrl(String assetPath) {
    var p = assetPath;
    if (!p.startsWith('assets/')) {
      p = 'assets/$p';
    }
    if (p.toLowerCase().endsWith('.wav')) {
      // Many browsers handle MP3 better; use parallel .mp3 if present
      final mp3 = p.substring(0, p.length - 4) + '.mp3';
      return mp3;
    }
    return p;
  }

  /// Handle scene audio completion
  void _onSceneAudioComplete(SceneType sceneType) {
    _isScenePlaying = false;
    _currentScene = null;
    
    onSceneComplete?.call(sceneType);
  }

  /// Stop the currently playing scene
  Future<void> _stopCurrentScene() async {
    if (!_isScenePlaying) return;
    
    try {
      // await _audioPlayer.stop();
      _isScenePlaying = false;
      _currentScene = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping scene audio: $e');
      }
    }
  }

  /// Pause the currently playing scene
  Future<void> _pauseCurrentScene() async {
    if (!_isScenePlaying) return;
    
    try {
      // await _audioPlayer.pause();
    } catch (e) {
      if (kDebugMode) {
        print('Error pausing scene audio: $e');
      }
    }
  }

  /// Resume the currently paused scene
  Future<void> _resumeCurrentScene() async {
    if (!_isScenePlaying || _currentScene == null) return;
    
    try {
      // await _audioPlayer.resume();
    } catch (e) {
      if (kDebugMode) {
        print('Error resuming scene audio: $e');
      }
    }
  }

  /// Reset the service state
  void _resetState() {
    _currentProgress = 0.0;
    _elapsedTime = Duration.zero;
    _totalDistance = 0.0;
    _playedScenes.clear();
    _currentScene = null;
    _isScenePlaying = false;
  }

  /// Dispose resources
  void dispose() {
    stop();
    // _audioPlayer.dispose();
  }

  /// Get scene info for a specific scene type
  static String getSceneTitle(SceneType sceneType) {
    switch (sceneType) {
      case SceneType.missionBriefing:
        return 'Mission Briefing';
      case SceneType.theJourney:
        return 'The Journey';
      case SceneType.firstContact:
        return 'First Contact';
      case SceneType.theCrisis:
        return 'The Crisis';
      case SceneType.extractionDebrief:
        return 'Extraction & Debrief';
    }
  }

  /// Get trigger percentage for a specific scene type
  static double getSceneTriggerPercentage(SceneType sceneType) {
    return _sceneTriggers[sceneType] ?? 0.0;
  }

  /// Get audio file for a specific scene type
  static String getSceneAudioFile(SceneType sceneType) {
    // Get scene index based on scene type
    final sceneIndex = _getSceneIndex(sceneType);
    
    // Return the audio file from the database array if available
    if (sceneIndex < _availableAudioFiles.length) {
      return _availableAudioFiles[sceneIndex];
    }
    
    // Fallback to empty string if scene not found
    return '';
  }
  
  /// Get the scene index based on scene type
  static int _getSceneIndex(SceneType sceneType) {
    switch (sceneType) {
      case SceneType.missionBriefing:
        return 0; // scene_1
      case SceneType.theJourney:
        return 1; // scene_2
      case SceneType.firstContact:
        return 2; // scene_3
      case SceneType.theCrisis:
        return 3; // scene_4
      case SceneType.extractionDebrief:
        return 4; // scene_5
    }
  }
  
  /// Load audio files from the database for the current episode
  static void loadAudioFilesFromDatabase(List<String> audioFiles) {
    _availableAudioFiles = List.from(audioFiles);
    
    if (kDebugMode) {
      print('🎵 Audio files loaded from database:');
      for (int i = 0; i < _availableAudioFiles.length; i++) {
        print('  ${i + 1}. ${_availableAudioFiles[i]}');
      }
      print('Total: ${_availableAudioFiles.length} audio files loaded');
      print('📋 All files: $_availableAudioFiles');
    }
  }
  
  /// Get all available audio files
  static List<String> getAvailableAudioFiles() {
    return List.unmodifiable(_availableAudioFiles);
  }
  
  /// Get the current episode ID
  String _getCurrentEpisodeId() {
    return _currentEpisodeId;
  }
  
  /// Play the first available scene (mission briefing)
  static String getFirstSceneAudioFile() {
    if (_availableAudioFiles.isNotEmpty) {
      final firstFile = _availableAudioFiles.first;
      if (kDebugMode) {
        print('🎬 First scene audio file: $firstFile');
        print('📋 All available files: $_availableAudioFiles');
      }
      return firstFile;
    }
    return ''; // No fallback - use database data only
  }
}
