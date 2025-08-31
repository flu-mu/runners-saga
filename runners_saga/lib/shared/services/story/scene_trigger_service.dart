import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:runners_saga/shared/models/episode_model.dart';
import 'package:runners_saga/shared/models/story_segment_model.dart';
import 'package:runners_saga/shared/services/audio/audio_manager.dart';
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

  // Single audio file mode properties
  bool _isSingleFileMode = false;
  String? _episodeAudioFile;
  Map<SceneType, Duration> _sceneTimestamps = {};
  bool _isAudioLoaded = false;
  EpisodeModel? _currentEpisode;
  final DownloadService _downloadService = DownloadService();

  // Callbacks
  Function(SceneType)? onSceneStart;
  Function(SceneType)? onSceneComplete;
  Function(double)? onProgressUpdate;

  // Getters
  Set<SceneType> get playedScenes => Set.unmodifiable(_playedScenes);
  SceneType? get currentScene => _currentScene;
  double get currentProgress => _currentProgress;
  bool get isRunning => _isRunning;
  bool get isScenePlaying => _audioPlayer.playing;

  // Static methods
  static double getSceneTriggerPercentage(SceneType sceneType) {
    return _sceneTriggerPercentages[sceneType] ?? 0.0;
  }

  static String getSceneTitle(SceneType sceneType) {
    return _sceneTitles[sceneType] ?? 'Unknown Scene';
  }

  static String getSceneAudioFile(SceneType sceneType) {
    throw UnsupportedError('Audio file information should come from episode data, not hardcoded values');
  }

  // Initialization
  Future<void> initialize({
    Duration? targetTime,
    double? targetDistance,
    EpisodeModel? episode,
  }) async {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
    _currentProgress = 0.0;
    _playedScenes.clear();
    _currentScene = null;
    _isRunning = false;
    _currentEpisode = episode;

    // Check if episode supports single audio file mode
    if (episode?.audioFile != null && episode?.sceneTimestamps != null) {
      _isSingleFileMode = true;
      _episodeAudioFile = episode!.audioFile;
      _sceneTimestamps = _parseSceneTimestamps(episode!.sceneTimestamps!);
      
      if (kDebugMode) {
        debugPrint('🎵 Episode supports single audio file mode - enabling automatically');
        debugPrint('🎵 Single audio file: $_episodeAudioFile');
        debugPrint('🎵 Scene timestamps: ${episode!.sceneTimestamps}');
      }
    } else {
      _isSingleFileMode = false;
      if (kDebugMode) {
        debugPrint('🎵 Episode uses multiple audio files mode');
      }
    }

    await _initializeBackgroundAudio();
    await _initializeNotifications();

    // Initialize single audio file if in single file mode
    if (_isSingleFileMode) {
      await _initializeSingleAudioFile();
    }
  }

  Map<SceneType, Duration> _parseSceneTimestamps(List<Map<String, dynamic>> timestamps) {
    final Map<SceneType, Duration> result = {};
    
    for (final timestamp in timestamps) {
      try {
        final sceneTypeStr = timestamp['sceneType'] as String;
        final startSeconds = timestamp['startSeconds'] as int;
        
        SceneType? sceneType;
        switch (sceneTypeStr) {
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
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing timestamp: $timestamp, error: $e');
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('🎵 Scene timestamps: $result');
    }
    
    return result;
  }

  Future<void> _initializeSingleAudioFile() async {
    if (!_isSingleFileMode || _episodeAudioFile == null) return;

    try {
      if (kDebugMode) {
        debugPrint('🎵 Initializing single audio file: $_episodeAudioFile');
      }

      // Get the local file path for the single audio file
      final localFiles = await _downloadService.getLocalEpisodeFiles(_currentEpisode?.id ?? '');
      if (localFiles.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ No local audio files found for single audio file mode');
        }
        return;
      }

      final localFilePath = localFiles.first;
      if (kDebugMode) {
        debugPrint('🎵 Using local file path: $localFilePath');
      }

      // Set the audio file path
      await _audioPlayer.setFilePath(localFilePath);

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

  Future<void> _initializeBackgroundAudio() async {
    try {
      _audioSession = await audio_session.AudioSession.instance;
      
      final config = audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
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
        debugPrint('🎵 Background audio system initialized');
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

  // App lifecycle management
  void onAppLifecycleChanged(AppLifecycleState state) {
    _isInBackground = state == AppLifecycleState.paused || 
                     state == AppLifecycleState.inactive ||
                     state == AppLifecycleState.detached;
    
    if (kDebugMode) {
      debugPrint('🔄 App lifecycle changed: $state, background: $_isInBackground');
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
      debugPrint('🎬 Scene triggered: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('📊 Played scenes: $_playedScenes');
    }
    
    onSceneStart?.call(sceneType);
    
    if (_isInBackground) {
      await _handleBackgroundScene(sceneType);
    } else {
      await _playSceneAudio(sceneType);
    }
  }

  Future<void> _playSceneAudio(SceneType sceneType) async {
    try {
      if (_isSingleFileMode) {
        await _playSceneFromSingleFile(sceneType);
      } else {
        await _playSceneFromMultipleFiles(sceneType);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error playing scene audio: $e');
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
          debugPrint('❌ No timestamp found for scene: $sceneType. Cannot play audio.');
        }
        _onSceneAudioComplete(sceneType);
        return;
      }

      if (kDebugMode) {
        debugPrint('🎵 Seeking to timestamp: $timestamp for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      }

      // For Scene 1 (Mission Briefing), if we're already at the beginning, just let it play
      if (sceneType == SceneType.missionBriefing && timestamp == Duration.zero) {
        if (kDebugMode) {
          debugPrint('🎵 Scene 1 (Mission Briefing) - starting audio from beginning');
        }
        // Start playback from the beginning
        await _audioPlayer.play();
        _setupSceneCompletionListener(sceneType);
        return;
      }

      // Pause current playback if it's playing
      if (_audioPlayer.playing) {
        if (kDebugMode) {
          debugPrint('🎵 Pausing current audio playback');
        }
        await _audioPlayer.pause();
      }

      // Seek to the scene timestamp
      await _audioPlayer.seek(timestamp);

      // Resume playback
      await _audioPlayer.play();

      if (kDebugMode) {
        debugPrint('🎵 Playing scene from single file: ${SceneTriggerService.getSceneTitle(sceneType)} at $timestamp');
      }

      // Set up a listener to automatically move to the next scene
      // when this scene's audio completes
      _setupSceneCompletionListener(sceneType);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error playing scene from single file: $e');
      }
      _onSceneAudioComplete(sceneType);
    }
  }

  void _setupSceneCompletionListener(SceneType sceneType) {
    // Remove any existing listeners
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (kDebugMode) {
          debugPrint('🎵 Scene audio completed: ${SceneTriggerService.getSceneTitle(sceneType)}');
        }
        _onSceneAudioComplete(sceneType);
      }
    });
  }

  Future<void> _playSceneFromMultipleFiles(SceneType sceneType) async {
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
      }
      
      final audioPath = _getAudioPathForScene(sceneType);
      if (audioPath == null) {
        if (kDebugMode) {
          debugPrint('❌ No audio path found for scene: $sceneType');
        }
        _onSceneAudioComplete(sceneType);
        return;
      }

      await _audioPlayer.setFilePath(audioPath);
      await _audioPlayer.play();
      
      if (kDebugMode) {
        debugPrint('🎵 Playing audio for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
        debugPrint('📁 Audio path: $audioPath');
      }
      
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _onSceneAudioComplete(sceneType);
        }
      });
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error playing scene audio: $e');
      }
      _onSceneAudioComplete(sceneType);
    }
  }

  Future<void> _handleBackgroundScene(SceneType sceneType) async {
    // Add to background queue
    _backgroundSceneQueue.add(sceneType);
    
    if (kDebugMode) {
      debugPrint('🔄 Scene queued for background: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
    
    // Show notification
    await _showSceneNotification(sceneType);
    
    // Try to play audio in background
    try {
      await _playSceneAudio(sceneType);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Background audio failed: $e');
      }
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
    
    while (_backgroundSceneQueue.isNotEmpty) {
      final sceneType = _backgroundSceneQueue.removeFirst();
      await _playSceneAudio(sceneType);
    }
  }

  String? _getAudioPathForScene(SceneType sceneType) {
    if (_isSingleFileMode) {
      // In single file mode, return the local path to the single audio file
      // Note: This method is called synchronously, so we can't await the download service
      // The local files should already be available after _initializeSingleAudioFile
      if (kDebugMode) {
        debugPrint('🎵 Single file mode: audio should already be loaded');
      }
      return null; // This will be handled by _playSceneFromSingleFile
    } else {
      // Legacy multiple files mode - this should not be used anymore
      if (kDebugMode) {
        debugPrint('⚠️ Multiple files mode is deprecated - use single audio file mode');
      }
      return null;
    }
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

    // If we're in single audio file mode, start playback from the beginning
    if (_isSingleFileMode && _isAudioLoaded) {
      if (kDebugMode) {
        debugPrint('🎵 Starting single audio file playback from beginning');
      }
      _startSingleAudioFilePlayback();
    } else if (kDebugMode) {
      debugPrint('⚠️ Cannot start audio: singleFileMode=$_isSingleFileMode, audioLoaded=$_isAudioLoaded');
    }
  }

  Future<void> _startSingleAudioFilePlayback() async {
    try {
      if (kDebugMode) {
        debugPrint('🎵 Starting single audio file playback from beginning');
      }

      // Seek to the beginning
      await _audioPlayer.seek(Duration.zero);

      // Start playback
      await _audioPlayer.play();

      if (kDebugMode) {
        debugPrint('✅ Single audio file playback started from beginning');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to start single audio file playback: $e');
      }
    }
  }

  void pause() {
    _isRunning = false;
    if (kDebugMode) {
      debugPrint('⏸️ Scene trigger service paused');
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

  // Cleanup
  void dispose() {
    _audioPlayer.dispose();
    if (kDebugMode) {
      debugPrint('🗑️ Scene trigger service disposed');
    }
  }

  // Legacy methods for compatibility with RunSessionManager
  void loadAudioFilesFromDatabase(List<String> audioFiles) {
    if (kDebugMode) {
      debugPrint('🎵 Loading audio files from database: $audioFiles');
      debugPrint('📊 Audio files count: ${audioFiles.length}');
    }
    
    // This method is kept for compatibility but single audio file mode
    // is handled automatically in the initialize method
    if (_isSingleFileMode) {
      if (kDebugMode) {
        debugPrint('🎵 Single audio file mode is already enabled');
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ Multiple audio files mode is deprecated');
      }
    }
  }

  Future<void> enableSingleAudioFileMode({
    required String audioFilePath,
    required Map<SceneType, Duration> sceneTimestamps,
  }) async {
    if (kDebugMode) {
      debugPrint('🎵 Enabling single audio file mode: $audioFilePath');
      debugPrint('🎵 Scene timestamps: $sceneTimestamps');
    }
    
    _isSingleFileMode = true;
    _episodeAudioFile = audioFilePath;
    _sceneTimestamps = sceneTimestamps;
    
    if (kDebugMode) {
      debugPrint('🎵 Single audio file mode enabled: $audioFilePath');
      debugPrint('🎵 Scene timestamps updated:');
      for (final entry in _sceneTimestamps.entries) {
        debugPrint('  ${entry.key}: ${entry.value}');
      }
    }
    
    // Initialize the single audio file
    await _initializeSingleAudioFile();
  }
}
