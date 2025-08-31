import 'dart:async';
import 'dart:collection';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:runners_saga/shared/models/episode_model.dart';
import 'package:runners_saga/shared/services/audio/download_service.dart';

enum SceneType {
  missionBriefing,
  theJourney,
  firstContact,
  theCrisis,
  extractionDebrief,
}

class SceneTriggerService {
  static const Map<SceneType, double> _sceneTriggerPercentages = {
    SceneType.missionBriefing: 0.0,
    SceneType.theJourney: 0.2,
    SceneType.firstContact: 0.4,
    SceneType.theCrisis: 0.7,
    SceneType.extractionDebrief: 0.9,
  };

  static const Map<SceneType, String> _sceneTitles = {
    SceneType.missionBriefing: 'Mission Briefing',
    SceneType.theJourney: 'The Journey',
    SceneType.firstContact: 'First Contact',
    SceneType.theCrisis: 'The Crisis',
    SceneType.extractionDebrief: 'Extraction & Debrief',
  };

  // Remove hardcoded audio file mappings - these should come from Firebase/local storage
  // static const Map<SceneType, String> _sceneAudioFiles = { ... };

  // Audio session and background handling
  audio_session.AudioSession? _audioSession;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Queue<SceneType> _backgroundSceneQueue = Queue<SceneType>();
  bool _isInBackground = false;
  bool _backgroundSystemInitialized = false;

  // Core properties
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<SceneType> _playedScenes = <SceneType>{};
  SceneType? _currentScene;
  double _currentProgress = 0.0;
  Duration? _targetTime;
  double? _targetDistance;
  bool _isRunning = false;
  
  // Episode data for audio file resolution
  EpisodeModel? _currentEpisode;
  
  // Download service for local file access
  final DownloadService _downloadService = DownloadService();
  
  // Single Audio File Architecture
  String? _episodeAudioFile;
  bool _isSingleFileMode = false;
  
  // Scene timestamps within the single audio file (to be provided by user)
  final Map<SceneType, Duration> _sceneTimestamps = {
    SceneType.missionBriefing: Duration.zero,
    SceneType.theJourney: Duration(seconds: 120),      // 2:00 - placeholder
    SceneType.firstContact: Duration(seconds: 240),    // 4:00 - placeholder
    SceneType.theCrisis: Duration(seconds: 420),       // 7:00 - placeholder
    SceneType.extractionDebrief: Duration(seconds: 540), // 9:00 - placeholder
  };
  
  // Audio state management
  bool _isAudioLoaded = false;
  bool _isAudioPaused = false;

  // Callbacks
  Function(SceneType)? onSceneStart;
  Function(SceneType)? onSceneComplete;
  Function(double)? onProgressUpdate;

  // Getters
  Set<SceneType> get playedScenes => Set.unmodifiable(_playedScenes);
  SceneType? get currentScene => _currentScene;
  double get currentProgress => _currentProgress;
  bool get isRunning => _isRunning;
  bool get isScenePlaying => _currentScene != null;

  // Static methods
  static double getSceneTriggerPercentage(SceneType sceneType) {
    return _sceneTriggerPercentages[sceneType] ?? 0.0;
  }
  
  // Single Audio File Methods
  void setSingleAudioFile(String audioFilePath) {
    _episodeAudioFile = audioFilePath;
    _isSingleFileMode = true;
    if (kDebugMode) {
      debugPrint('🎵 Single audio file mode enabled: $audioFilePath');
    }
  }
  
  void updateSceneTimestamps(Map<SceneType, Duration> timestamps) {
    _sceneTimestamps.clear();
    _sceneTimestamps.addAll(timestamps);
    if (kDebugMode) {
      debugPrint('🎵 Scene timestamps updated:');
      for (final entry in _sceneTimestamps.entries) {
        debugPrint('  ${entry.key}: ${entry.value}');
      }
    }
  }
  
  bool get isSingleFileMode => _isSingleFileMode;
  
  // Start single audio file playback from beginning
  Future<void> startSingleAudioFilePlayback() async {
    if (!_isSingleFileMode || !_isAudioLoaded) {
      if (kDebugMode) {
        debugPrint('❌ Cannot start single audio file: mode=$_isSingleFileMode, loaded=$_isAudioLoaded');
      }
      return;
    }
    
    try {
      if (kDebugMode) {
        debugPrint('🎵 Starting single audio file playback from beginning');
      }
      
      // Seek to the beginning
      await _audioPlayer.seek(Duration.zero);
      
      // Start playback
      await _audioPlayer.play();
      
      if (kDebugMode) {
        debugPrint('✅ Single audio file playback started');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to start single audio file playback: $e');
      }
    }
  }

  void loadAudioFilesFromDatabase(List<String> audioFiles) {
    if (kDebugMode) {
      debugPrint('🎵 Loading ${audioFiles.length} audio files from database');
      for (final file in audioFiles) {
        debugPrint('  📁 $file');
      }
    }
    // This method is a placeholder for future audio file loading logic
    // For now, we just log the files that would be loaded
  }

  static String getSceneTitle(SceneType sceneType) {
    return _sceneTitles[sceneType] ?? 'Unknown Scene';
  }

  static String getSceneAudioFile(SceneType sceneType) {
    // This method should not be used - audio files come from episode data
    // Remove hardcoded fallback
    throw UnsupportedError('Audio file information should come from episode data, not hardcoded values');
  }

  // Initialization
  Future<void> initialize({
    Duration? targetTime,
    double? targetDistance,
    EpisodeModel? episode,
    String? singleAudioFile,
    Map<SceneType, Duration>? sceneTimestamps,
  }) async {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
    _currentEpisode = episode;
    _currentProgress = 0.0;
    _playedScenes.clear();
    _currentScene = null;
    _isRunning = false;

    if (kDebugMode) {
      if (episode != null) {
        debugPrint('🎵 SceneTriggerService: Initialized with episode ${episode.id}');
        debugPrint('🎵 Episode audio files: ${episode.audioFiles}');
        
        // Check for single audio file support
        if (episode.audioFile != null && episode.audioFile!.isNotEmpty) {
          debugPrint('🎵 Episode has single audio file: ${episode.audioFile}');
        }
        if (episode.sceneTimestamps != null && episode.sceneTimestamps!.isNotEmpty) {
          debugPrint('🎵 Episode has scene timestamps: ${episode.sceneTimestamps}');
        }
      } else {
        debugPrint('⚠️ SceneTriggerService: Initialized without episode data');
      }
    }

    // Initialize single audio file mode if provided or if episode supports it
    if (singleAudioFile != null || (episode?.audioFile != null && episode!.audioFile!.isNotEmpty)) {
      final audioFile = singleAudioFile ?? episode!.audioFile!;
      final timestamps = sceneTimestamps ?? _convertSceneTimestampsToDurations(episode?.sceneTimestamps);
      
      setSingleAudioFile(audioFile);
      if (timestamps != null) {
        updateSceneTimestamps(timestamps);
      }
      await _initializeSingleAudioFile();
    }

    await _initializeBackgroundAudio();
    await _initializeNotifications();
  }

  Future<void> _initializeBackgroundAudio() async {
    try {
      _audioSession = await audio_session.AudioSession.instance;
      
      final config = audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.allowBluetooth | 
                                     audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: audio_session.AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.music,
          flags: audio_session.AndroidAudioFlags.none,
          usage: audio_session.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      );

      await _audioSession!.configure(config);
      _backgroundSystemInitialized = true;
      
      if (kDebugMode) {
        debugPrint('🎵 Background audio system initialized with enhanced configuration');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize background audio: $e');
      }
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);
      
      if (kDebugMode) {
        debugPrint('🔔 Notification system initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize notifications: $e');
      }
    }
  }

  // Single Audio File Initialization
  Future<void> _initializeSingleAudioFile() async {
    if (!_isSingleFileMode || _episodeAudioFile == null) return;
    
    try {
      if (kDebugMode) {
        debugPrint('🎵 Initializing single audio file: $_episodeAudioFile');
      }
      
      // Set the audio file path
      await _audioPlayer.setFilePath(_episodeAudioFile!);
      
      // Set up audio player listeners
      _audioPlayer.playerStateStream.listen((state) {
        if (kDebugMode) {
          debugPrint('🎵 Audio player state: ${state.processingState}');
        }
        
        if (state.processingState == ProcessingState.completed) {
          if (kDebugMode) {
            debugPrint('🎵 Single audio file playback completed');
          }
        }
      });
      
      _audioPlayer.positionStream.listen((position) {
        if (kDebugMode) {
          debugPrint('🎵 Audio position: ${position.inSeconds}s');
        }
        
        // Check if we need to pause at scene boundaries
        _checkSceneBoundaryPause(position);
      });
      
      _isAudioLoaded = true;
      
      if (kDebugMode) {
        debugPrint('✅ Single audio file initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize single audio file: $e');
      }
    }
  }
  
  void _checkSceneBoundaryPause(Duration position) {
    // Check if we're approaching the next scene boundary
    for (final sceneType in SceneType.values) {
      final timestamp = _sceneTimestamps[sceneType];
      if (timestamp != null && !_playedScenes.contains(sceneType)) {
        // Pause 1 second before the scene starts
        final pauseTime = timestamp - const Duration(seconds: 1);
        if (position >= pauseTime && position < timestamp && !_isAudioPaused) {
          _pauseAtSceneBoundary(sceneType);
        }
      }
    }
  }
  
  void _pauseAtSceneBoundary(SceneType sceneType) {
    if (kDebugMode) {
      debugPrint('🎵 Pausing at scene boundary: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
    
    _audioPlayer.pause();
    _isAudioPaused = true;
  }

  // App lifecycle management
  void onAppLifecycleChanged(AppLifecycleState state) {
    final wasInBackground = _isInBackground;
    _isInBackground = state == AppLifecycleState.paused || 
                     state == AppLifecycleState.inactive ||
                     state == AppLifecycleState.detached;
    
    if (kDebugMode) {
      debugPrint('🔄 App lifecycle changed: $state, background: $_isInBackground');
    }
    
    // If we're coming from background to foreground, resume any queued scenes
    if (wasInBackground && !_isInBackground) {
      if (kDebugMode) {
        debugPrint('🔄 App returned to foreground, checking for queued scenes...');
      }
      
      // Use a small delay to ensure the app is fully foregrounded
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!_isInBackground && _backgroundSceneQueue.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('🔄 Resuming background scenes after foreground transition');
          }
          resumeBackgroundScenes();
        }
      });
    }
  }

  // Progress tracking
  void updateProgress({double? progress, Duration? elapsedTime, double? distance}) {
    if (!_isRunning) return;

    if (progress != null) {
      _currentProgress = progress.clamp(0.0, 1.0);
    } else if (_targetTime != null && elapsedTime != null) {
      _currentProgress = (elapsedTime.inMilliseconds / _targetTime!.inMilliseconds).clamp(0.0, 1.0);
    } else if (_targetDistance != null && distance != null) {
      _currentProgress = (distance / _targetDistance!).clamp(0.0, 1.0);
    }

    _checkSceneTriggers();
  }

  void _checkSceneTriggers() {
    for (final sceneType in SceneType.values) {
      final triggerPercentage = getSceneTriggerPercentage(sceneType);
      if (_currentProgress >= triggerPercentage && !_playedScenes.contains(sceneType)) {
        _triggerScene(sceneType);
      }
    }
  }

  Future<void> _triggerScene(SceneType sceneType) async {
    if (_playedScenes.contains(sceneType)) return;
    
    await _stopCurrentScene();
    _playedScenes.add(sceneType);
    _currentScene = sceneType;
    
    if (kDebugMode) {
      debugPrint('�� Scene triggered: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('📊 Played scenes: $_playedScenes');
    }
    
    onSceneStart?.call(sceneType);
    
    if (kDebugMode) {
      debugPrint('🔄 Background state: $_isInBackground');
    }
    
    if (_isInBackground) {
      if (kDebugMode) {
        debugPrint('🔄 Handling background scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      }
      await _handleBackgroundScene(sceneType);
    } else {
      if (kDebugMode) {
        debugPrint('🎵 Playing foreground scene audio: ${SceneTriggerService.getSceneTitle(sceneType)}');
      }
      await _playSceneAudio(sceneType);
    }
  }

  Future<void> _playSceneAudio(SceneType sceneType) async {
    if (kDebugMode) {
      debugPrint('🎵 _playSceneAudio called for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
    
    try {
      if (_audioSession != null) {
        if (kDebugMode) {
          debugPrint('🎵 Activating audio session...');
        }
        await _audioSession!.setActive(true);
        if (kDebugMode) {
          debugPrint('✅ Audio session activated');
        }
      } else {
        debugPrint('⚠️ No audio session available');
      }
      
      // Check if we're in single file mode
      if (_isSingleFileMode) {
        await _playSceneFromSingleFile(sceneType);
      } else {
        await _playSceneFromMultipleFiles(sceneType);
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error playing scene audio: $e');
        debugPrint('❌ Error stack trace: ${StackTrace.current}');
      }
      _onSceneAudioComplete(sceneType);
    }
  }
  
  Future<void> _playSceneFromSingleFile(SceneType sceneType) async {
    if (!_isAudioLoaded || _episodeAudioFile == null) {
      if (kDebugMode) {
        debugPrint('❌ Single audio file not loaded or available');
      }
      _onSceneAudioComplete(sceneType);
      return;
    }
    
    try {
      final timestamp = _sceneTimestamps[sceneType];
      if (timestamp == null) {
        if (kDebugMode) {
          debugPrint('❌ No timestamp found for scene: $sceneType');
        }
        _onSceneAudioComplete(sceneType);
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🎵 Seeking to timestamp: $timestamp for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      }
      
      // Seek to the scene timestamp
      await _audioPlayer.seek(timestamp);
      
      // Resume playback if it was paused
      if (_isAudioPaused) {
        if (kDebugMode) {
          debugPrint('🎵 Resuming paused audio playback');
        }
        _isAudioPaused = false;
      }
      
      await _audioPlayer.play();
      
      if (kDebugMode) {
        debugPrint('🎵 Playing scene from single file: ${SceneTriggerService.getSceneTitle(sceneType)} at $timestamp');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error playing scene from single file: $e');
      }
      _onSceneAudioComplete(sceneType);
    }
  }
  
  Future<void> _playSceneFromMultipleFiles(SceneType sceneType) async {
    if (kDebugMode) {
      debugPrint('🎵 Getting audio path for scene: $sceneType');
    }
    
    final audioPath = await _getAudioPathForScene(sceneType);
    if (audioPath == null) {
      if (kDebugMode) {
        debugPrint('❌ No audio path found for scene: $sceneType');
      }
      _onSceneAudioComplete(sceneType);
      return;
    }

    if (kDebugMode) {
      debugPrint('🎵 Setting audio file path: $audioPath');
    }
    
    await _audioPlayer.setFilePath(audioPath);
    
    if (kDebugMode) {
      debugPrint('🎵 Starting audio playback...');
    }
    
    await _audioPlayer.play();
    
    if (kDebugMode) {
      debugPrint('🎵 Playing audio for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('📁 Audio path: $audioPath');
    }
    
    _audioPlayer.playerStateStream.listen((state) {
      if (kDebugMode) {
        debugPrint('🎵 Audio player state: ${state.processingState}');
      }
      if (state.processingState == ProcessingState.completed) {
        _onSceneAudioComplete(sceneType);
      }
    });
  }

  Future<void> _handleBackgroundScene(SceneType sceneType) async {
    // Add to background queue
    _backgroundSceneQueue.add(sceneType);
    
    if (kDebugMode) {
      debugPrint('🔄 Scene queued for background: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
    
    // Show notification
    await _showSceneNotification(sceneType);
    
    // Don't try to play audio immediately in background - it often fails
    // Instead, queue it for when the app comes to foreground
    if (kDebugMode) {
      debugPrint('🔄 Audio queued for foreground playback: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
  }

  Future<void> _showSceneNotification(SceneType sceneType) async {
    if (!_backgroundSystemInitialized) return;
    
    final sceneTitle = SceneTriggerService.getSceneTitle(sceneType);
    
    const androidDetails = AndroidNotificationDetails(
      'scene_triggers',
      'Scene Triggers',
      channelDescription: 'Notifications for story scene triggers',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    
    await _notifications.show(
      sceneType.index,
      'Story Progress',
      'New scene: $sceneTitle',
      notificationDetails,
    );
    
    if (kDebugMode) {
      debugPrint('🔔 Notification sent for scene: $sceneTitle');
    }
  }

  Future<void> resumeBackgroundScenes() async {
    if (_backgroundSceneQueue.isEmpty) return;
    
    if (kDebugMode) {
      debugPrint('🔄 Resuming ${_backgroundSceneQueue.length} background scenes');
    }
    
    // Process all queued scenes
    final scenesToPlay = List<SceneType>.from(_backgroundSceneQueue);
    _backgroundSceneQueue.clear();
    
    for (final sceneType in scenesToPlay) {
      if (kDebugMode) {
        debugPrint('🎵 Playing queued background scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      }
      
      try {
        await _playSceneAudio(sceneType);
        // Add a small delay between scenes to prevent overlap
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to play queued scene ${SceneTriggerService.getSceneTitle(sceneType)}: $e');
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('✅ Finished processing background scene queue');
    }
  }

  Future<String?> _getAudioPathForScene(SceneType sceneType) async {
    // Get audio file from episode data, not hardcoded values
    if (_currentEpisode == null) {
      if (kDebugMode) {
        debugPrint('❌ No current episode available for scene: $sceneType');
      }
      return null;
    }
    
    // Get the audio file for this scene from the episode data
    final sceneIndex = sceneType.index;
    if (sceneIndex >= 0 && sceneIndex < _currentEpisode!.audioFiles.length) {
      final audioFile = _currentEpisode!.audioFiles[sceneIndex];
      
      // Get the local file paths from the download service
      final localFiles = await _downloadService.getLocalEpisodeFiles(_currentEpisode!.id);
      
      if (localFiles.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ No local audio files found for episode ${_currentEpisode!.id}');
        }
        return null;
      }
      
      // Find the matching local file by extracting filename from URL
      final fileName = _extractFileNameFromUrl(audioFile);
      final localFile = localFiles.firstWhere(
        (path) => path.endsWith(fileName),
        orElse: () => '',
      );
      
      if (localFile.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ Local file not found for: $fileName');
          debugPrint('📁 Available local files: $localFiles');
        }
        return null;
      }
      
      if (kDebugMode) {
        debugPrint('🎵 Scene $sceneType: Using audio file from episode: $audioFile');
        debugPrint('📁 Local file path: $localFile');
      }
      
      return localFile;
    } else {
      if (kDebugMode) {
        debugPrint('❌ Scene index $sceneIndex out of range for episode audio files (${_currentEpisode!.audioFiles.length})');
      }
      return null;
    }
  }
  
  String _extractFileNameFromUrl(String url) {
    // Extract filename from Firebase URL
    // Example: https://runners-saga-app.firebasestorage.app/audio/episodes/S01E01/scene_1_quick.mp3
    // Returns: scene_1_quick.mp3
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    return pathSegments.last;
  }
  
  // Convert scene timestamps from Firebase format to Duration format
  Map<SceneType, Duration>? _convertSceneTimestampsToDurations(List<Map<String, dynamic>>? sceneTimestamps) {
    if (sceneTimestamps == null || sceneTimestamps.isEmpty) return null;
    
    final Map<SceneType, Duration> result = {};
    
    for (final scene in sceneTimestamps) {
      final sceneTypeString = scene['sceneType'] as String?;
      final startSeconds = scene['startSeconds'] as int?;
      
      if (sceneTypeString != null && startSeconds != null) {
        // Convert string to SceneType enum
        SceneType? sceneType;
        switch (sceneTypeString) {
          case 'missionBriefing':
            sceneType = SceneType.missionBriefing;
            break;
          case 'theJourney':
            sceneType = SceneType.theJourney;
            break;
          case 'firstContact':
            sceneType = SceneType.firstContact;
            break;
          case 'theCrisis':
            sceneType = SceneType.theCrisis;
            break;
          case 'extractionDebrief':
            sceneType = SceneType.extractionDebrief;
            break;
        }
        
        if (sceneType != null) {
          result[sceneType] = Duration(seconds: startSeconds);
        }
      }
    }
    
    return result;
  }

  void _onSceneAudioComplete(SceneType sceneType) {
    if (kDebugMode) {
      debugPrint('✅ Scene audio completed: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
    
    onSceneComplete?.call(sceneType);
    _currentScene = null;
  }

  Future<void> _stopCurrentScene() async {
    if (_currentScene != null) {
      await _audioPlayer.stop();
      _currentScene = null;
    }
  }

  // Control methods
  void start() {
    _isRunning = true;
    if (kDebugMode) {
      debugPrint('🚀 Scene trigger service started');
    }
  }

  void pause() {
    _isRunning = false;
    if (kDebugMode) {
      debugPrint('⏸️ Scene trigger service paused');
    }
  }

  void resume() {
    _isRunning = true;
    if (kDebugMode) {
      debugPrint('▶️ Scene trigger service resumed');
    }
  }

  void stop() {
    _isRunning = false;
    _currentProgress = 0.0;
    _playedScenes.clear();
    _currentScene = null;
    if (kDebugMode) {
      debugPrint('⏹️ Scene trigger service stopped');
    }
  }

  void reset() {
    stop();
    if (kDebugMode) {
      debugPrint('🔄 Scene trigger service reset');
    }
  }
  
  /// Update the current episode data (useful when episode changes)
  void updateEpisode(EpisodeModel episode) {
    _currentEpisode = episode;
    if (kDebugMode) {
      debugPrint('🎵 SceneTriggerService: Episode updated to ${episode.id}');
      debugPrint('🎵 New episode audio files: ${episode.audioFiles}');
    }
  }

  // Cleanup
  void dispose() {
    _audioPlayer.dispose();
    if (kDebugMode) {
      debugPrint('🗑️ Scene trigger service disposed');
    }
  }
}
