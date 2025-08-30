import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:runners_saga/shared/models/story_segment_model.dart';
import 'package:runners_saga/shared/services/audio/audio_manager.dart';

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

  static const Map<SceneType, String> _sceneAudioFiles = {
    SceneType.missionBriefing: 'scene_1_mission_briefing.wav',
    SceneType.theJourney: 'scene_2_the_journey.wav',
    SceneType.firstContact: 'scene_3_first_contact.wav',
    SceneType.theCrisis: 'scene_4_the_crisis.wav',
    SceneType.extractionDebrief: 'scene_5_extraction_debrief.wav',
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
    return _sceneAudioFiles[sceneType] ?? '';
  }

  // Initialization
  Future<void> initialize({
    Duration? targetTime,
    double? targetDistance,
  }) async {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
    _currentProgress = 0.0;
    _playedScenes.clear();
    _currentScene = null;
    _isRunning = false;

    await _initializeBackgroundAudio();
    await _initializeNotifications();
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
      debugPrint('�� Scene triggered: ${SceneTriggerService.getSceneTitle(sceneType)}');
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
    final audioFile = getSceneAudioFile(sceneType);
    if (audioFile.isEmpty) return null;
    
    // This would typically come from your asset management system
    // For now, returning a placeholder path
    return 'assets/audio/$audioFile';
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

  // Cleanup
  void dispose() {
    _audioPlayer.dispose();
    if (kDebugMode) {
      debugPrint('🗑️ Scene trigger service disposed');
    }
  }
}
