import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:runners_saga/shared/models/episode_model.dart';
import 'package:runners_saga/shared/services/audio/download_service.dart';
import 'package:runners_saga/shared/services/audio/audio_scheduler_service.dart';
import 'package:runners_saga/shared/services/settings/settings_service.dart';
import 'package:runners_saga/shared/models/run_enums.dart';

enum SceneType {
  scene1,
  scene2,
  scene3,
  scene4,
  scene5,
}

class SceneTriggerService {
  static const Map<SceneType, double> _sceneTriggerPercentages = {
    SceneType.scene1: 0.0,
    SceneType.scene2: 0.2,
    SceneType.scene3: 0.4,
    SceneType.scene4: 0.7,
    SceneType.scene5: 0.9,
  };

  static const Map<SceneType, String> _sceneTitles = {
    SceneType.scene1: 'Scene 1',
    SceneType.scene2: 'Scene 2',
    SceneType.scene3: 'Scene 3',
    SceneType.scene4: 'Scene 4',
    SceneType.scene5: 'Scene 5',
  };

  // Audio session and background handling
  audio_session.AudioSession? _audioSession;
  bool _isAudioSessionActive = false; // Track session state manually
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInBackground = false;

  // Core properties
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<SceneType> _playedScenes = <SceneType>{};
  SceneType? _currentScene;
  double _currentProgress = 0.0;
  Duration? _targetTime;
  double? _targetDistance;
  bool _isRunning = false;
  late final Ref _ref;

  // Interval-based triggering configuration
  ClipIntervalMode _clipIntervalMode = ClipIntervalMode.distance;
  double _clipIntervalDistanceKm = 0.4; // default 400 m
  double _clipIntervalMinutes = 3.0;    // default 3 minutes
  double _lastTriggerDistanceKm = 0.0;
  Duration _lastTriggerElapsed = Duration.zero;

  // Latest progress metrics
  Duration _currentElapsed = Duration.zero;
  double _currentDistanceKm = 0.0;

  // Audio file mode properties
  bool _isSingleFileMode = false;
  String? _episodeAudioFile;
  List<String> _episodeAudioFiles = [];
  Map<SceneType, Duration> _sceneTimestamps = {};
  final Map<SceneType, Duration> _sceneEndTimestamps = {}; // End timestamps
  bool _isAudioLoaded = false;
  EpisodeModel? _currentEpisode;
  final DownloadService _downloadService = DownloadService();
  
  // Timer-based auto-pause properties
  Timer? _sceneEndTimer;
  StreamSubscription<Duration>? _scenePositionSubscription;
  Duration? _activeSceneEnd;
  bool _autoPausedThisScene = false;

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
  bool get isAudioSessionActive => _isAudioSessionActive;

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

  /// Set the Riverpod ref for service access.
  void setRef(Ref ref) {
    _ref = ref;
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
    _currentProgress = 0.0;
    _playedScenes.clear();
    _currentScene = null;
    _isRunning = false;
    _currentEpisode = episode;

    // Load interval triggering configuration from settings
    try {
      final settings = SettingsService();
      final modeIdx = await settings.getClipIntervalModeIndex();
      _clipIntervalMode = modeIdx == 1 ? ClipIntervalMode.time : ClipIntervalMode.distance;
      _clipIntervalDistanceKm = await settings.getClipIntervalDistanceKm();
      _clipIntervalMinutes = await settings.getClipIntervalMinutes();
      _lastTriggerDistanceKm = 0.0;
      _lastTriggerElapsed = Duration.zero;
      if (kDebugMode) {
        debugPrint('🎯 Clip interval config: mode=${_clipIntervalMode.name}, dist=${_clipIntervalDistanceKm}km, time=${_clipIntervalMinutes}min');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load clip interval settings: $e');
      }
    }

    // ONLY use multiple audio files system - completely disable single file mode
    if (episode?.audioFiles != null && episode!.audioFiles.isNotEmpty) {
      _isSingleFileMode = false;
      _episodeAudioFiles = episode!.audioFiles;
      
      if (kDebugMode) {
        debugPrint('🎵 Episode uses multiple audio files mode (audioFiles)');
        debugPrint('🎵 Audio files count: ${_episodeAudioFiles.length}');
        debugPrint('🎵 Audio files: $_episodeAudioFiles');
      }
    } else {
      // NO SINGLE FILE MODE - force multiple files mode or disable
      _isSingleFileMode = false;
      _episodeAudioFiles = [];
      
      if (kDebugMode) {
        debugPrint('❌ Episode has no audioFiles - single file mode completely disabled');
        debugPrint('❌ Episode will not play audio - only multiple files mode supported');
      }
    }

    await _initializeBackgroundAudio();
    await _initializeNotifications();

    // Initialize audio files based on mode
    if (_isSingleFileMode) {
      await _initializeSingleAudioFile();
    } else {
      await _initializeMultipleAudioFiles();
    }
  }

  Map<SceneType, Duration> _parseSceneTimestamps(List<Map<String, dynamic>> timestamps) {
    final Map<SceneType, Duration> result = {};
    _sceneEndTimestamps.clear(); // Clear end timestamps too
    
    for (final timestamp in timestamps) {
      try {
        final sceneTypeStr = timestamp['sceneType'] as String;
        final startSeconds = timestamp['startSeconds'] as int;
        final endSeconds = timestamp['endSeconds'] as int; // Extract end timestamp too
        
        SceneType? sceneType;
        switch (sceneTypeStr) {
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
          _sceneEndTimestamps[sceneType] = Duration(seconds: endSeconds); // Store end timestamp
          
          if (kDebugMode) {
            debugPrint('🎯 [DEBUG] Parsed scene $sceneType: start=${startSeconds}s, end=${endSeconds}s');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error parsing scene timestamp: $e');
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('🎵 Scene timestamps: $result');
      debugPrint('🎵 Scene end timestamps: $_sceneEndTimestamps');
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

      // Set the audio file path with enhanced error handling and background audio support
      try {
        // Create MediaItem for background audio notifications
        final mediaItem = MediaItem(
          id: _currentEpisode?.id ?? 'unknown',
          album: 'Runner\'s Saga',
          title: _currentEpisode?.title ?? 'Episode',
          artist: 'Runner\'s Saga',
          duration: Duration.zero, // Will be set automatically
          //artUri: Uri.parse('https://example.com/artwork.jpg'), // Optional: add actual artwork
        );
        
        // Create AudioSource with MediaItem for background support
        final audioSource = AudioSource.file(
          localFilePath,
          tag: mediaItem,
        );
        
        // Set the audio source
        await _audioPlayer.setAudioSource(audioSource);
        
        if (kDebugMode) {
          debugPrint('🎵 Audio file path set successfully: $localFilePath');
          debugPrint('🎵 MediaItem configured for background audio: ${mediaItem.title}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to set audio file path: $e');
          debugPrint('🎵 File exists: ${await _downloadService.fileExists(localFilePath)}');
        }
        return;
      }

      // Set up audio player listeners with enhanced debugging
      _audioPlayer.playerStateStream.listen((state) {
        if (kDebugMode) {
          debugPrint('🎵 Audio player state: ${state.processingState}');
          // Check for error state
          if (state.processingState == ProcessingState.idle && state.playing == false) {
            debugPrint('❌ Audio player may have encountered an error');
          }
        }

        if (state.processingState == ProcessingState.completed) {
          if (kDebugMode) {
            debugPrint('🎵 Single audio file playback completed');
          }
        }
      });

      // Optimize position logging - only log every 5 seconds to reduce spam
      Duration? _lastLoggedPosition;
      _audioPlayer.positionStream.listen((position) {
        if (kDebugMode) {
          // Only log position changes every 5 seconds to reduce log spam
          if (_lastLoggedPosition == null || 
              (position.inSeconds - _lastLoggedPosition!.inSeconds).abs() >= 5) {
            debugPrint('🎵 Audio position: ${position.inSeconds}s');
            _lastLoggedPosition = position;
          }
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

  Future<void> _initializeMultipleAudioFiles() async {
    if (_isSingleFileMode || _episodeAudioFiles.isEmpty) return;

    try {
      if (kDebugMode) {
        debugPrint('🎵 Initializing multiple audio files: ${_episodeAudioFiles.length} files');
        debugPrint('🎵 Audio files: $_episodeAudioFiles');
      }

      // Get the local file paths for the audio files
      final localFiles = await _downloadService.getLocalEpisodeFiles(_currentEpisode?.id ?? '');
      if (localFiles.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ No local audio files found for multiple audio files mode');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('🎵 Found ${localFiles.length} local audio files');
        for (int i = 0; i < localFiles.length; i++) {
          debugPrint('  File $i: ${localFiles[i]}');
        }
      }

      // Set up audio player listeners with enhanced debugging
      _audioPlayer.playerStateStream.listen((state) {
        if (kDebugMode) {
          debugPrint('🎵 Audio player state: ${state.processingState}');
          // Check for error state
          if (state.processingState == ProcessingState.idle && state.playing == false) {
            debugPrint('❌ Audio player may have encountered an error');
          }
        }

        if (state.processingState == ProcessingState.completed) {
          if (kDebugMode) {
            debugPrint('🎵 Audio file playback completed');
          }
        }
      });

      // Optimize position logging - only log every 5 seconds to reduce spam
      Duration? _lastLoggedPosition;
      _audioPlayer.positionStream.listen((position) {
        if (kDebugMode) {
          // Only log position changes every 5 seconds to reduce log spam
          if (_lastLoggedPosition == null || 
              (position.inSeconds - _lastLoggedPosition!.inSeconds).abs() >= 5) {
            debugPrint('🎵 Audio position: ${position.inSeconds}s');
            _lastLoggedPosition = position;
          }
        }
      });

      _isAudioLoaded = true;

      if (kDebugMode) {
        debugPrint('✅ Multiple audio files initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize multiple audio files: $e');
      }
    }
  }

  Future<void> _initializeBackgroundAudio() async {
    try {
      _audioSession = await audio_session.AudioSession.instance;
      
      // Attach debug listeners to observe focus/interruptions and device changes
      try {
        _audioSession!.interruptionEventStream.listen((event) {
          if (kDebugMode) {
            debugPrint('🎧 [AudioSession] Interruption: begin=${event.begin}, type=${event.type}');
          }
        });
      } catch (_) {}
      try {
        _audioSession!.becomingNoisyEventStream.listen((_) {
          if (kDebugMode) {
            debugPrint('📉 [AudioSession] Becoming noisy (e.g., headphones unplugged)');
          }
        });
      } catch (_) {}
      try {
        _audioSession!.devicesChangedEventStream.listen((event) {
          if (kDebugMode) {
            debugPrint('📱 [AudioSession] Devices changed');
          }
        });
      } catch (_) {}
      
      // Enhanced configuration for full background audio support with ducking
      final config = audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        // Mix with others and duck other audio during scene playback (iOS)
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.mixWithOthers |
            audio_session.AVAudioSessionCategoryOptions.duckOthers |
            audio_session.AVAudioSessionCategoryOptions.allowBluetooth |
            audio_session.AVAudioSessionCategoryOptions.allowAirPlay,
        avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: audio_session.AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.music,
          flags: audio_session.AndroidAudioFlags.none,
          usage: audio_session.AndroidAudioUsage.media,
        ),
        // Request transient may-duck focus (Android)
        androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      );

      // First set session inactive if it was active
      try {
        if (_isAudioSessionActive) {
          await _audioSession!.setActive(false);
          _isAudioSessionActive = false; // Track state
        }
      } catch (e) {
        // Ignore deactivation errors
        if (kDebugMode) {
          debugPrint('🎵 Audio session deactivation skipped: $e');
        }
      }

      // Configure the new session
      await _audioSession!.configure(config);
      
      // Activate the session
      await _audioSession!.setActive(true);
      _isAudioSessionActive = true; // Track state
      
      if (kDebugMode) {
        debugPrint('🎵 Background audio system initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize background audio: $e');
        debugPrint('🎵 Audio session state: $_isAudioSessionActive');
      }
      
      // Try to recover by using default configuration
      try {
        if (_audioSession != null) {
          await _audioSession!.setActive(true);
          _isAudioSessionActive = true; // Track state
          if (kDebugMode) {
            debugPrint('🎵 Recovered audio session with default configuration');
          }
        }
      } catch (recoveryError) {
        if (kDebugMode) {
          debugPrint('❌ Audio session recovery failed: $recoveryError');
        }
      }
    }
  }

  // Enable ducking by activating the audio session configured above
  Future<void> _enableDucking() async {
    try {
      if (_audioSession == null) {
        await _initializeBackgroundAudio();
      }
      if (_audioSession != null && !_isAudioSessionActive) {
        await _audioSession!.setActive(true);
        _isAudioSessionActive = true;
      }
      if (kDebugMode) {
        debugPrint('🔇 Ducking enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to enable ducking: $e');
      }
    }
  }

  // Disable ducking by releasing audio focus
  Future<void> _disableDucking() async {
    try {
      if (_audioSession != null && _isAudioSessionActive) {
        // On iOS, notify others on deactivation so external apps restore volume
        await _audioSession!.setActive(
          false,
          avAudioSessionSetActiveOptions: audio_session.AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        );
        _isAudioSessionActive = false;
      }
      if (kDebugMode) {
        debugPrint('🔊 Ducking disabled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to disable ducking: $e');
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
    
    // Handle audio session during lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground - ensure audio session is active
      _ensureAudioSessionActive();
    } else if (state == AppLifecycleState.paused) {
      // App going to background - audio should continue playing
      if (kDebugMode) {
        debugPrint('🎵 App going to background - audio will continue playing');
      }
    }
  }

  /// Ensure audio session is active for playback
  Future<void> _ensureAudioSessionActive() async {
    try {
      if (_audioSession != null && !_isAudioSessionActive) {
        await _audioSession!.setActive(true);
        _isAudioSessionActive = true; // Track state
        if (kDebugMode) {
          debugPrint('🎵 Audio session reactivated after app resume');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to reactivate audio session: $e');
      }
    }
  }

  /// Check if audio is currently playing (works in background)
  bool get isAudioPlaying => _audioPlayer.playing;

  /// Get current audio position (works in background)
  Duration get currentAudioPosition => _audioPlayer.position;

  /// Manually pause current scene audio (works in background)
  Future<void> pauseCurrentScene() async {
    if (_audioPlayer.playing) {
      try {
        await _audioPlayer.pause();
        if (kDebugMode) {
          debugPrint('🎵 Scene audio manually paused');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to pause scene audio: $e');
        }
      }
    }
  }

  /// Resume current scene audio from where it was paused (works in background)
  Future<void> resumeCurrentScene() async {
    if (!_audioPlayer.playing && _autoPausedThisScene) {
      try {
        await _audioPlayer.play();
        if (kDebugMode) {
          debugPrint('🎵 Scene audio resumed from pause');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to resume scene audio: $e');
        }
      }
    }
  }

  // Progress tracking
  void updateProgress({double? progress, Duration? elapsedTime, double? distance}) {
    if (!_isRunning) return;

    // capture latest metrics for interval markers and debug
    if (elapsedTime != null) _currentElapsed = elapsedTime;
    if (distance != null) _currentDistanceKm = distance;

    if (progress != null) {
      _currentProgress = progress.clamp(0.0, 1.0);
    } else if (_targetTime != null && elapsedTime != null) {
      _currentProgress = (elapsedTime.inMilliseconds / _targetTime!.inMilliseconds).clamp(0.0, 1.0);
    } else if (_targetDistance != null && distance != null) {
      _currentProgress = (distance / _targetDistance!).clamp(0.0, 1.0);
    }

    _checkSceneTriggers();

    // Interval-based triggering works alongside milestone triggers
    _checkIntervalTrigger(elapsedTime: elapsedTime, distanceKm: distance);
  }

  void _checkSceneTriggers() {
    for (final sceneType in SceneType.values) {
      final triggerPercentage = getSceneTriggerPercentage(sceneType);
      if (_currentProgress >= triggerPercentage && !_playedScenes.contains(sceneType)) {
        _triggerScene(sceneType);
      }
    }
  }

  /// Check if we should trigger the next scene based on clip interval mode.
  void _checkIntervalTrigger({Duration? elapsedTime, double? distanceKm}) {
    // Determine next scene to trigger
    if (_playedScenes.length >= SceneType.values.length) return; // no more scenes
    final nextScene = SceneType.values[_playedScenes.length];

    // If next scene would be scene1 and none played yet, rely on milestone (0%) instead
    if (nextScene == SceneType.scene1 && _playedScenes.isEmpty) return;

    bool shouldTrigger = false;
    if (_clipIntervalMode == ClipIntervalMode.distance) {
      if (distanceKm != null) {
        final since = distanceKm - _lastTriggerDistanceKm;
        if (since >= _clipIntervalDistanceKm - 1e-6) {
          shouldTrigger = true;
          _lastTriggerDistanceKm = distanceKm;
        }
      }
    } else {
      if (elapsedTime != null) {
        final since = elapsedTime - _lastTriggerElapsed;
        final threshold = Duration(milliseconds: (_clipIntervalMinutes * 60000).round());
        if (since >= threshold) {
          shouldTrigger = true;
          _lastTriggerElapsed = elapsedTime;
        }
      }
    }

    if (shouldTrigger) {
      if (kDebugMode) {
        debugPrint('⏱️ Interval trigger -> next scene: ${getSceneTitle(nextScene)}');
      }
      _triggerScene(nextScene);
    }
  }

  /// Reload clip-interval configuration from Settings mid-run.
  Future<void> refreshClipIntervalFromSettings() async {
    try {
      final settings = SettingsService();
      final modeIdx = await settings.getClipIntervalModeIndex();
      final dist = await settings.getClipIntervalDistanceKm();
      final mins = await settings.getClipIntervalMinutes();
      setClipInterval(
        modeIdx == 1 ? ClipIntervalMode.time : ClipIntervalMode.distance,
        distanceKm: dist,
        minutes: mins,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to refresh clip interval settings: $e');
      }
    }
  }

  /// Directly set clip-interval configuration mid-run.
  void setClipInterval(ClipIntervalMode mode, {double? distanceKm, double? minutes}) {
    _clipIntervalMode = mode;
    if (distanceKm != null) _clipIntervalDistanceKm = distanceKm;
    if (minutes != null) _clipIntervalMinutes = minutes;
    // Reset baselines to avoid immediate trigger spikes
    _lastTriggerDistanceKm = _currentDistanceKm;
    _lastTriggerElapsed = _currentElapsed;
    if (kDebugMode) {
      debugPrint('🔧 Clip interval updated: mode=${_clipIntervalMode.name}, dist=${_clipIntervalDistanceKm}km, time=${_clipIntervalMinutes}min');
    }
  }

  Future<void> _triggerScene(SceneType sceneType) async {
    if (_playedScenes.contains(sceneType)) return;
    
    await _stopCurrentScene();
    _playedScenes.add(sceneType);
    _currentScene = sceneType;

    // Reset interval baselines at start of each scene
    _lastTriggerDistanceKm = _currentDistanceKm;
    _lastTriggerElapsed = _currentElapsed;
    
    if (kDebugMode) {
      debugPrint('🎬 Scene triggered: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('📊 Played scenes: $_playedScenes');
    }
    
    onSceneStart?.call(sceneType);

    final audioScheduler = _ref.read(audioSchedulerServiceProvider);

    // Create a normal-priority audio request for the story scene
    final request = AudioRequest(
      priority: AudioPriority.normal,
      playFunction: () async {
        // This is where the original logic to play the audio goes.
        await _playSceneAudio(sceneType);
      },
    );

    // Add the request to the scheduler's queue
    audioScheduler.add(request);
  }

  Future<void> _playSceneAudio(SceneType sceneType) async {
    if (kDebugMode) {
      debugPrint('🔧 [DEBUG] _playSceneAudio called for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('🔧 [DEBUG] _isSingleFileMode: $_isSingleFileMode');
    }
    
    try {
      // ONLY use multiple files mode - single file mode completely disabled
      if (kDebugMode) {
        debugPrint('🔧 [DEBUG] Calling _playSceneFromMultipleFiles for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      }
      await _playSceneFromMultipleFiles(sceneType);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error playing scene audio: $e');
      }
      _onSceneAudioComplete(sceneType);
    }
  }

  Future<void> _playSceneFromSingleFile(SceneType sceneType) async {
    if (kDebugMode) {
      debugPrint('🔧 [DEBUG] _playSceneFromSingleFile entered for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('🔧 [DEBUG] _isAudioLoaded: $_isAudioLoaded');
      debugPrint('🔧 [DEBUG] _episodeAudioFile: ${_episodeAudioFile != null ? 'loaded' : 'null'}');
    }
    
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

      // Get the actual end timestamp for this scene from Firebase data
      final sceneEnd = _sceneEndTimestamps[sceneType];
      if (kDebugMode) {
        debugPrint('🎯 [DEBUG] Scene start: $timestamp, end: ${sceneEnd?.toString() ?? 'unknown'}');
      }
      
      if (sceneEnd == null) {
        if (kDebugMode) {
          debugPrint('❌ [DEBUG] No end timestamp found for scene: $sceneType. Cannot determine pause point.');
        }
        _onSceneAudioComplete(sceneType);
        return;
      }

      // Ensure audio session active before playback (enables ducking)
      try {
        if (_audioSession != null) {
          await _enableDucking();
          if (kDebugMode) {
            debugPrint('🎵 Audio session activated successfully');
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ No audio session available, attempting to initialize');
          }
          await _initializeBackgroundAudio();
        }
        
        // Log audio session status for debugging
        if (kDebugMode) {
          debugPrint('🎵 Audio session status: active=$_isAudioSessionActive');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to activate audio session: $e');
        }
        // Continue with playback attempt anyway
      }

      // Cancel any previous end timer
      _sceneEndTimer?.cancel();
      _sceneEndTimer = null;

      // If already playing, pause before seeking
      if (_audioPlayer.playing) {
        if (kDebugMode) {
          debugPrint('🎵 [DEBUG] Pausing current audio before seek');
        }
        await _audioPlayer.pause();
      }

      // Seek to scene start and play with enhanced error handling
      try {
        if (kDebugMode) {
          debugPrint('🎵 [DEBUG] Seeking to timestamp: $timestamp');
        }
        await _audioPlayer.seek(timestamp);
        if (kDebugMode) {
          debugPrint('✅ [DEBUG] Seek completed');
        }
        
        // Check audio player state before playing
        final playerState = _audioPlayer.playerState;
        if (kDebugMode) {
          debugPrint('🎵 Audio player state before play: ${playerState.processingState}');
        }
        
        // Play the scene audio
        await _audioPlayer.play();
        if (kDebugMode) {
          debugPrint('✅ [DEBUG] Play command sent for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
        }
        
        // Set up auto-pause timer for scene end (works in background)
        if (kDebugMode) {
          debugPrint('🔧 [DEBUG] About to call _setupSceneAutoPause for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
          debugPrint('🔧 [DEBUG] Scene end timestamp: $sceneEnd');
          debugPrint('🔧 [DEBUG] Current audio position: ${_audioPlayer.position.inSeconds}s');
        }
        _setupSceneAutoPause(sceneType, sceneEnd);
        if (kDebugMode) {
          debugPrint('🔧 [DEBUG] _setupSceneAutoPause call completed');
        }
        
        // Keep positionStream listener for additional monitoring (but not primary auto-pause)
        _scenePositionSubscription?.cancel();
        _scenePositionSubscription = _audioPlayer.positionStream.listen((pos) {
          if (kDebugMode) {
            debugPrint('🎵 [DEBUG] Position update: ${pos.inSeconds}s');
          }
        });

        // Set completion listener (when entire file ends)
        _setupSceneCompletionListener(sceneType);
        
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [DEBUG] Error during audio playback: $e');
          debugPrint('🎵 Audio player state: ${_audioPlayer.playerState.processingState}');
        }
        _onSceneAudioComplete(sceneType);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DEBUG] Error in _playSceneFromSingleFile: $e');
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
        await _enableDucking();
      }
      
      // Map scene type to audio file index
      final sceneOrder = [
        SceneType.scene1,
        SceneType.scene2,
        SceneType.scene3,
        SceneType.scene4,
        SceneType.scene5,
      ];
      
      final sceneIndex = sceneOrder.indexOf(sceneType);
      if (sceneIndex < 0 || sceneIndex >= _episodeAudioFiles.length) {
        if (kDebugMode) {
          debugPrint('❌ No audio file found for scene: $sceneType (index: $sceneIndex, files: ${_episodeAudioFiles.length})');
        }
        _onSceneAudioComplete(sceneType);
        return;
      }

      final audioFileUrl = _episodeAudioFiles[sceneIndex];
      if (kDebugMode) {
        debugPrint('🎵 Multiple files mode: scene $sceneType maps to index $sceneIndex');
        debugPrint('🎵 Audio file URL: $audioFileUrl');
      }

      // Create MediaItem for background audio notifications
      final mediaItem = MediaItem(
        id: '${_currentEpisode?.id ?? 'unknown'}_${sceneType.name}',
        album: 'Runner\'s Saga',
        title: '${_currentEpisode?.title ?? 'Episode'} - ${SceneTriggerService.getSceneTitle(sceneType)}',
        artist: 'Runner\'s Saga',
        duration: Duration.zero, // Will be set automatically
        //artUri: Uri.parse('https://example.com/artwork.jpg'), // Optional: add actual artwork
      );
      
      // Create AudioSource with MediaItem for background support
      final audioSource = AudioSource.uri(
        Uri.parse(audioFileUrl),
        tag: mediaItem,
      );
      
      // Set the audio source and play
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      
      if (kDebugMode) {
        debugPrint('🎵 Playing audio for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
        debugPrint('🎵 Audio file URL: $audioFileUrl');
        debugPrint('🎵 MediaItem configured for background audio: ${mediaItem.title}');
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
      // Multiple files mode - we need to get the local file path, not the URL
      // Since this method is called synchronously, we can't await the download service
      // The local files should already be available after _initializeMultipleAudioFiles
      if (kDebugMode) {
        debugPrint('🎵 Multiple files mode: local files should already be loaded');
        debugPrint('🎵 Episode ID: ${_currentEpisode?.id}');
      }
      
      // Return null here - the actual local file path resolution will be handled
      // in _playSceneFromMultipleFiles by using the download service
      return null;
    }
  }

  void _onSceneAudioComplete(SceneType sceneType) {
    if (kDebugMode) {
      debugPrint('✅ Scene audio completed: ${SceneTriggerService.getSceneTitle(sceneType)}');
    }
    
    // Notify the scheduler that playback is complete
    _ref.read(audioSchedulerServiceProvider).playbackComplete();

    onSceneComplete?.call(sceneType);
    _currentScene = null;
    // Release ducking so external music returns to normal
    _disableDucking();
    
    // DO NOT auto-progress to next scene
    // Scenes should only be triggered by progress milestones (0%, 20%, 40%, 70%, 90%)
    // The next scene will be triggered when progress reaches the appropriate percentage
  }
  
  void _autoProgressToNextScene(SceneType completedScene) {
    if (!_isRunning) return;
    
    // Find the next scene in sequence
    final sceneOrder = [
      SceneType.scene1,
      SceneType.scene2,
      SceneType.scene3,
      SceneType.scene4,
      SceneType.scene5,
    ];
    
    final currentIndex = sceneOrder.indexOf(completedScene);
    if (currentIndex >= 0 && currentIndex < sceneOrder.length - 1) {
      final nextScene = sceneOrder[currentIndex + 1];
      
      if (!_playedScenes.contains(nextScene)) {
        if (kDebugMode) {
          debugPrint('🔄 Auto-progressing to next scene: ${SceneTriggerService.getSceneTitle(nextScene)}');
        }
        
        // Small delay to ensure current scene cleanup is complete
        Timer(Duration(milliseconds: 500), () {
          _triggerScene(nextScene);
        });
      } else if (kDebugMode) {
        debugPrint('⚠️ Next scene ${SceneTriggerService.getSceneTitle(nextScene)} already played');
      }
    } else if (kDebugMode) {
      debugPrint('🏁 All scenes completed for this episode');
    }
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
    _sceneEndTimer?.cancel();
    _scenePositionSubscription?.cancel();
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
  


  /// Set up automatic pause when scene ends (works in background)
  void _setupSceneAutoPause(SceneType sceneType, Duration sceneEnd) {
    // Cancel any existing timer
    _sceneEndTimer?.cancel();
    
    // Store active scene bounds for the periodic timer to use
    _activeSceneEnd = sceneEnd;
    _autoPausedThisScene = false;
    
    if (kDebugMode) {
      debugPrint('🎵 Setting up auto-pause for scene: ${SceneTriggerService.getSceneTitle(sceneType)}');
      debugPrint('🎵 Scene end time: ${sceneEnd.inSeconds}s');
      debugPrint('🎵 Will auto-pause at: ${sceneEnd.inSeconds}s');
    }
    
    // Calculate exactly when this scene should pause based on its end timestamp
    // No need to check current position - we know exactly when to pause
    _sceneEndTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (_activeSceneEnd != null && !_autoPausedThisScene) {
        final currentPos = _audioPlayer.position;
        
        if (kDebugMode) {
          debugPrint('🎯 [DEBUG] Timer check - Position: ${currentPos.inSeconds}s, Target end: ${_activeSceneEnd!.inSeconds}s');
        }
        
        if (currentPos >= _activeSceneEnd!) {
          _autoPausedThisScene = true;
          timer.cancel();
          
          if (kDebugMode) {
            debugPrint('⏸️ [DEBUG] Auto-pausing at scene end by timer: ${SceneTriggerService.getSceneTitle(sceneType)}');
            debugPrint('⏸️ [DEBUG] Current position: ${currentPos.inMilliseconds}ms (${currentPos.inSeconds}s)');
            debugPrint('⏸️ [DEBUG] Target end time: ${_activeSceneEnd!.inMilliseconds}ms (${_activeSceneEnd!.inSeconds}s)');
          }
          
          try {
            await _audioPlayer.pause();
            if (kDebugMode) {
              debugPrint('✅ [DEBUG] Pause command executed successfully');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ [DEBUG] Failed to pause audio: $e');
            }
          }
          _onSceneAudioComplete(sceneType);
        }
      }
    });
  }

  // Cleanup
  void dispose() {
    // Deactivate audio session
    try {
      if (_audioSession != null && _isAudioSessionActive) {
        _audioSession!.setActive(false);
        _isAudioSessionActive = false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error deactivating audio session during dispose: $e');
      }
    }
    
    _audioPlayer.dispose();
    _sceneEndTimer?.cancel();
    _scenePositionSubscription?.cancel();
    if (kDebugMode) {
      debugPrint('🗑️ Scene trigger service disposed');
    }
  }

  // Methods for compatibility with RunSessionManager
  void loadAudioFilesFromDatabase(List<String> audioFiles) {
    if (kDebugMode) {
      debugPrint('🎵 Loading audio files from database: $audioFiles');
      debugPrint('📊 Audio files count: ${audioFiles.length}');
    }
    
    // Update the audio files list for multiple files mode
    if (!_isSingleFileMode) {
      _episodeAudioFiles = audioFiles;
      if (kDebugMode) {
        debugPrint('🎵 Multiple audio files mode - updated audio files list');
        debugPrint('🎵 Audio files: $_episodeAudioFiles');
      }
    } else {
      if (kDebugMode) {
        debugPrint('🎵 Single audio file mode is already enabled - ignoring audioFiles');
      }
    }
  }

  Future<void> enableSingleAudioFileMode({
    required String audioFilePath,
    required Map<SceneType, Duration> sceneTimestamps,
  }) async {
    // SINGLE FILE MODE COMPLETELY DISABLED
    if (kDebugMode) {
      debugPrint('❌ Single audio file mode is completely disabled');
      debugPrint('❌ Only multiple files mode is supported');
    }
    
    // Do nothing - single file mode is disabled
  }
  
  void setSingleAudioFile(String audioFilePath) {
    // SINGLE FILE MODE COMPLETELY DISABLED
    if (kDebugMode) {
      debugPrint('❌ Single audio file mode is completely disabled');
      debugPrint('❌ Only multiple files mode is supported');
    }
    // Do nothing - single file mode is disabled
  }

  void updateSceneTimestamps(Map<SceneType, Duration> sceneTimestamps) {
    if (kDebugMode) {
      debugPrint('🎵 [DEBUG] Updating scene timestamps: $sceneTimestamps');
    }
    _sceneTimestamps = sceneTimestamps;
  }
  
  void resume() {
    _isRunning = true;
    if (kDebugMode) {
      debugPrint('▶️ Scene trigger service resumed');
    }
  }
}
