# Runner's Saga Optimization Implementation Guide

## 🎯 Overview
This guide provides step-by-step implementation instructions for optimizing the Runner's Saga Flutter app. Follow the phases in order for best results.

## 📋 Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart 3.8.1 or higher
- Firebase project configured
- Android Studio / VS Code with Flutter extensions

---

## 🚀 Phase 1: Critical Dependencies & Cleanup (Week 1)

### Step 1.1: Update pubspec.yaml

**File:** `runners_saga/pubspec.yaml`

**Action:** Replace your current dependencies section with:

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  
  # State Management - Riverpod
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  
  # Code Generation and Data Classes
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  
  # GPS Tracking and Location Services
  geolocator: ^12.0.0
  permission_handler: ^11.3.1
  background_locator_2: ^2.1.3  # NEW: Background location
  
  # Maps and Route Display
  flutter_map: ^7.0.2
  latlong2: ^0.9.0
  
  # Audio Playback - REMOVE audioplayers, keep only just_audio
  just_audio: ^0.10.4
  just_audio_background: ^0.0.1-beta.8  # NEW: Background audio
  
  # Firebase Backend Integration
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.4.3
  firebase_storage: ^12.3.3
  firebase_crashlytics: ^4.1.3  # NEW: Crash reporting
  firebase_analytics: ^11.3.3   # NEW: Analytics
  
  # Google Sign-In
  google_sign_in: ^6.1.6
  
  # Navigation and Routing
  go_router: ^14.2.7
  
  # UI Components and Utilities
  flutter_svg: ^2.0.10+1
  cached_network_image: ^3.4.1
  shared_preferences: ^2.3.3
  
  # Image processing
  image: ^3.3.0
  
  # Background Processing
  workmanager: ^0.5.2
  
  # Device Info and Platform Detection
  device_info_plus: ^10.1.0
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Networking and Utilities
  google_fonts: ^6.2.1
  http: ^1.2.2
  dio: ^5.7.0  # NEW: Better HTTP client
  path_provider: ^2.1.4
  path: ^1.9.0
  
  # Performance and Caching
  flutter_cache_manager: ^3.4.1  # NEW: Asset caching
  
  # GPS and Data Processing
  xml: ^6.5.0
  
  # Sensors and Hardware
  sensors_plus: ^6.0.1  # NEW: Motion detection
  wakelock_plus: ^1.2.8  # NEW: Screen wake control
  
  # Error Handling and Logging
  logger: ^2.4.0  # NEW: Better logging
  
  # Connectivity
  connectivity_plus: ^6.0.5  # NEW: Network monitoring

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  
  # Code Generation
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  hive_generator: ^2.0.1
  
  # Testing
  mockito: ^5.4.4
  integration_test:
    sdk: flutter
```

**Commands to run:**
```bash
cd runners_saga
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Step 1.2: Project Structure Reorganization

**Action:** Create the following folder structure in `lib/`:

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   ├── error/
│   └── services/
├── data/
│   ├── models/
│   ├── repositories/
│   └── data_sources/
│       ├── local/
│       ├── remote/
│       └── sensors/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/
│       ├── run/
│       ├── story/
│       └── user/
└── presentation/
    ├── pages/
    ├── widgets/
    ├── providers/
    └── routes/
```

**Commands to run:**
```bash
# Create folder structure
mkdir -p lib/core/{constants,theme,utils,error,services}
mkdir -p lib/data/{models,repositories,data_sources/{local,remote,sensors}}
mkdir -p lib/domain/{entities,repositories,use_cases/{run,story,user}}
mkdir -p lib/presentation/{pages,widgets,providers,routes}
```

### Step 1.3: Core Constants Setup

**File:** `lib/core/constants/app_constants.dart`

```dart
class AppConstants {
  // App Info
  static const String appName = 'Runner\'s Saga';
  static const String appVersion = '1.0.0';
  
  // Database
  static const int hiveTypeIdRunSession = 0;
  static const int hiveTypeIdLocationPoint = 1;
  static const int hiveTypeIdStoryEpisode = 2;
  static const int hiveTypeIdStoryProgress = 3;
  static const int hiveTypeIdUserProfile = 4;
  
  // GPS Settings
  static const double gpsAccuracyThreshold = 30.0; // meters
  static const int locationUpdateInterval = 5000; // milliseconds
  static const double stationaryDistanceFilter = 20.0; // meters
  static const double activeDistanceFilter = 5.0; // meters
  
  // Audio Settings
  static const double defaultStoryVolume = 1.0;
  static const double defaultSfxVolume = 0.8;
  static const int maxPreloadedEpisodes = 2;
  
  // Performance
  static const int maxRoutePoints = 10000; // Prevent memory issues
  static const Duration cacheDuration = Duration(hours: 24);
  static const double lowFpsThreshold = 45.0;
  
  // Background Tasks
  static const Duration syncInterval = Duration(hours: 6);
  static const Duration cleanupInterval = Duration(days: 7);
}
```

**File:** `lib/core/constants/asset_paths.dart`

```dart
class AssetPaths {
  // Audio
  static const String audioPath = 'assets/audio/';
  static const String storiesPath = 'assets/stories/';
  
  // Images
  static const String imagesPath = 'assets/images/';
  static const String iconsPath = 'assets/icons/';
  
  // GPS Data
  static const String gpsPath = 'assets/gps/';
  
  // Sound Effects
  static const String startRunSfx = '${audioPath}start_run.mp3';
  static const String pauseRunSfx = '${audioPath}pause_run.mp3';
  static const String milestoneSfx = '${audioPath}milestone.mp3';
}
```

---

## 🏗️ Phase 2: Data Layer Implementation (Week 2)

### Step 2.1: Data Models with Hive

**File:** `lib/data/models/location_point.dart`

```dart
import 'package:hive/hive.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_point.freezed.dart';
part 'location_point.g.dart';

@freezed
@HiveType(typeId: 1)
class LocationPoint with _$LocationPoint {
  const factory LocationPoint({
    @HiveField(0) required double latitude,
    @HiveField(1) required double longitude,
    @HiveField(2) required DateTime timestamp,
    @HiveField(3) @Default(0.0) double altitude,
    @HiveField(4) @Default(0.0) double accuracy,
    @HiveField(5) @Default(0.0) double speed, // m/s
    @HiveField(6) @Default(0.0) double heading,
  }) = _LocationPoint;

  factory LocationPoint.fromJson(Map<String, dynamic> json) =>
      _$LocationPointFromJson(json);
}
```

**File:** `lib/data/models/run_session.dart`

```dart
import 'package:hive/hive.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'location_point.dart';

part 'run_session.freezed.dart';
part 'run_session.g.dart';

@freezed
@HiveType(typeId: 0)
class RunSession with _$RunSession {
  const factory RunSession({
    @HiveField(0) required String id,
    @HiveField(1) required DateTime startTime,
    @HiveField(2) required DateTime endTime,
    @HiveField(3) required List<LocationPoint> route,
    @HiveField(4) required double totalDistance, // in km
    @HiveField(5) required Duration totalDuration,
    @HiveField(6) required double averagePace, // min/km
    @HiveField(7) String? episodeId,
    @HiveField(8) @Default([]) List<String> completedEpisodes,
    @HiveField(9) @Default(0) int calories,
    @HiveField(10) @Default(0.0) double elevationGain,
    @HiveField(11) @Default(false) bool synced,
  }) = _RunSession;

  factory RunSession.fromJson(Map<String, dynamic> json) =>
      _$RunSessionFromJson(json);
}
```

**Commands to run after creating models:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 2.2: Hive Service Implementation

**File:** `lib/data/data_sources/local/hive_service.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/run_session.dart';
import '../../models/location_point.dart';
import '../../models/story_episode.dart';
import '../../models/story_progress.dart';
import '../../models/user_profile.dart';

class HiveService {
  static const String runSessionBox = 'runSessions';
  static const String storyProgressBox = 'storyProgress';
  static const String storyEpisodesBox = 'storyEpisodes';
  static const String userProfileBox = 'userProfile';
  static const String cacheBox = 'cache';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(RunSessionAdapter());
    Hive.registerAdapter(LocationPointAdapter());
    Hive.registerAdapter(StoryEpisodeAdapter());
    Hive.registerAdapter(StoryProgressAdapter());
    Hive.registerAdapter(UserProfileAdapter());
    
    // Open boxes
    await Future.wait([
      Hive.openBox<RunSession>(runSessionBox),
      Hive.openBox<StoryProgress>(storyProgressBox),
      Hive.openBox<StoryEpisode>(storyEpisodesBox),
      Hive.openBox<UserProfile>(userProfileBox),
      Hive.openBox(cacheBox),
    ]);
  }

  // Run Session operations
  static Future<void> saveRunSession(RunSession session) async {
    final box = Hive.box<RunSession>(runSessionBox);
    await box.put(session.id, session);
  }

  static Future<List<RunSession>> getAllRunSessions() async {
    final box = Hive.box<RunSession>(runSessionBox);
    return box.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  static Future<RunSession?> getRunSession(String id) async {
    final box = Hive.box<RunSession>(runSessionBox);
    return box.get(id);
  }

  static Future<void> deleteRunSession(String id) async {
    final box = Hive.box<RunSession>(runSessionBox);
    await box.delete(id);
  }

  // Add other methods as needed...
}
```

### Step 2.3: Location Service Implementation

**File:** `lib/data/data_sources/sensors/location_service.dart`

```dart
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

@Riverpod(keepAlive: true)
LocationService locationService(LocationServiceRef ref) {
  return LocationService();
}

class LocationService {
  StreamController<Position>? _locationController;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<AccelerometerEvent>? _motionSubscription;
  
  bool _isStationary = false;
  DateTime _lastSignificantMovement = DateTime.now();
  
  LocationSettings get _currentSettings => _isStationary 
    ? _stationarySettings 
    : _activeSettings;
  
  static const LocationSettings _activeSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );
  
  static const LocationSettings _stationarySettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 20,
  );

  Stream<Position> startLocationTracking() {
    if (_locationController != null) {
      return _locationController!.stream;
    }
    
    _locationController = StreamController<Position>.broadcast();
    _startMotionDetection();
    _startGPSTracking();
    
    return _locationController!.stream;
  }

  void _startMotionDetection() {
    _motionSubscription = accelerometerEventStream().listen((event) {
      double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z
      );
      
      if (magnitude > 12.0) {
        if (_isStationary) {
          _isStationary = false;
          _restartGPSWithNewSettings();
        }
        _lastSignificantMovement = DateTime.now();
      } else if (!_isStationary && 
                 DateTime.now().difference(_lastSignificantMovement).inSeconds > 30) {
        _isStationary = true;
        _restartGPSWithNewSettings();
      }
    });
  }

  void _startGPSTracking() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: _currentSettings,
    )
    .where(_isAccuratePosition)
    .listen(
      (position) => _locationController?.add(position),
      onError: (error) => _locationController?.addError(error),
    );
  }

  bool _isAccuratePosition(Position position) {
    return position.accuracy < 30.0;
  }

  void _restartGPSWithNewSettings() {
    _locationSubscription?.cancel();
    _startGPSTracking();
  }

  Future<void> stopLocationTracking() async {
    await _locationSubscription?.cancel();
    await _motionSubscription?.cancel();
    await _locationController?.close();
    
    _locationSubscription = null;
    _motionSubscription = null;
    _locationController = null;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  static double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  static double calculatePace(double distanceKm, Duration time) {
    if (distanceKm <= 0) return 0;
    return time.inMinutes / distanceKm;
  }
}
```

**Commands to run:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 🎵 Phase 3: Audio Service Implementation (Week 2 continued)

### Step 3.1: Audio Service

**File:** `lib/data/data_sources/sensors/audio_service.dart`

```dart
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

part 'audio_service.g.dart';

@Riverpod(keepAlive: true)
AudioService audioService(AudioServiceRef ref) {
  return AudioService();
}

class AudioService {
  late final AudioPlayer _player;
  late final AudioPlayer _sfxPlayer;
  final CacheManager _cacheManager = DefaultCacheManager();
  
  ConcatenatingAudioSource? _currentPlaylist;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.yourapp.runners_saga.audio',
      androidNotificationChannelName: 'Runner\'s Saga Audio',
      androidNotificationOngoing: true,
    );
    
    _player = AudioPlayer();
    _sfxPlayer = AudioPlayer();
    
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: []),
    );
    
    _isInitialized = true;
  }

  Future<void> loadStoryEpisode({
    required String episodeId,
    required List<String> audioUrls,
    bool preload = false,
  }) async {
    await initialize();
    
    List<AudioSource> sources = [];
    
    for (String url in audioUrls) {
      final cachedFile = await _cacheManager.getSingleFile(url);
      sources.add(
        AudioSource.file(
          cachedFile.path,
          tag: MediaItem(
            id: episodeId,
            title: 'Runner\'s Saga Episode',
            artist: 'Runner\'s Saga',
          ),
        ),
      );
    }
    
    _currentPlaylist = ConcatenatingAudioSource(children: sources);
    
    if (!preload) {
      await _player.setAudioSource(_currentPlaylist!);
    }
  }

  Future<void> preloadNextEpisodes(List<String> episodeIds) async {
    for (String episodeId in episodeIds.take(2)) {
      unawaited(_preloadEpisodeInBackground(episodeId));
    }
  }

  Future<void> _preloadEpisodeInBackground(String episodeId) async {
    try {
      final audioUrls = await _getEpisodeAudioUrls(episodeId);
      
      for (String url in audioUrls) {
        await _cacheManager.getSingleFile(url);
      }
    } catch (e) {
      print('Failed to preload episode $episodeId: $e');
    }
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();
  Future<void> stop() async => await _player.stop();
  Future<void> seekTo(Duration position) async => await _player.seek(position);

  Future<void> playSoundEffect(String assetPath) async {
    try {
      await _sfxPlayer.setAsset(assetPath);
      await _sfxPlayer.play();
    } catch (e) {
      print('Failed to play sound effect: $e');
    }
  }

  Future<void> setStoryVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setSFXVolume(double volume) async {
    await _sfxPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> duckAudio({
    double duckLevel = 0.3, 
    Duration duration = const Duration(seconds: 2)
  }) async {
    final originalVolume = _player.volume;
    await _player.setVolume(duckLevel);
    
    Timer(duration, () async {
      await _player.setVolume(originalVolume);
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Future<void> saveProgress(String episodeId, Duration position) async {
    // Implement with your local storage
  }

  Future<Duration?> getProgress(String episodeId) async {
    // Implement with your local storage
    return null;
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _sfxPlayer.dispose();
  }

  Future<List<String>> _getEpisodeAudioUrls(String episodeId) async {
    throw UnimplementedError('Implement based on your story data structure');
  }
}
```

---

## 🎮 Phase 4: State Management with Riverpod (Week 3)

### Step 4.1: Run State Provider

**File:** `lib/presentation/providers/run_provider.dart`

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../data/models/run_session.dart';
import '../../data/models/location_point.dart';
import '../../data/data_sources/sensors/location_service.dart';
import '../../data/data_sources/sensors/audio_service.dart';

part 'run_provider.freezed.dart';
part 'run_provider.g.dart';

@freezed
class RunState with _$RunState {
  const factory RunState({
    @Default(false) bool isRunning,
    @Default(false) bool isPaused,
    @Default([]) List<LocationPoint> route,
    @Default(Duration.zero) Duration elapsedTime,
    @Default(0.0) double totalDistance,
    @Default(0.0) double currentPace,
    @Default(0.0) double averagePace,
    Position? currentLocation,
    String? currentEpisodeId,
    DateTime? startTime,
  }) = _RunState;
}

@Riverpod(keepAlive: true)
class RunNotifier extends _$RunNotifier {
  Timer? _timer;
  StreamSubscription<Position>? _locationSubscription;

  @override
  RunState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _locationSubscription?.cancel();
    });
    
    return const RunState();
  }

  Future<void> startRun({String? episodeId}) async {
    final locationService = ref.read(locationServiceProvider);
    
    final permission = await _requestLocationPermission();
    if (!permission) return;

    _locationSubscription = locationService.startLocationTracking().listen(
      _onLocationUpdate,
      onError: _onLocationError,
    );

    _startTimer();

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      startTime: DateTime.now(),
      currentEpisodeId: episodeId,
    );

    if (episodeId != null) {
      ref.read(audioServiceProvider).loadStoryEpisode(
        episodeId: episodeId,
        audioUrls: [], // Get from story repository
      );
    }
  }

  void pauseRun() {
    _timer?.cancel();
    _locationSubscription?.pause();
    
    state = state.copyWith(isPaused: true);
    ref.read(audioServiceProvider).pause();
  }

  void resumeRun() {
    _startTimer();
    _locationSubscription?.resume();
    
    state = state.copyWith(isPaused: false);
    ref.read(audioServiceProvider).play();
  }

  Future<void> stopRun() async {
    _timer?.cancel();
    await _locationSubscription?.cancel();
    
    await _saveRunSession();
    await ref.read(audioServiceProvider).stop();
    
    state = const RunState();
  }

  void _onLocationUpdate(Position position) {
    final newPoint = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
    );

    final updatedRoute = [...state.route, newPoint];
    final newDistance = _calculateTotalDistance(updatedRoute);
    final currentPace = _calculateCurrentPace(updatedRoute);
    final averagePace = _calculateAveragePace(newDistance, state.elapsedTime);

    state = state.copyWith(
      currentLocation: position,
      route: updatedRoute,
      totalDistance: newDistance,
      currentPace: currentPace,
      averagePace: averagePace,
    );
  }

  void _onLocationError(error) {
    print('Location error: $error');
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isPaused) {
        state = state.copyWith(
          elapsedTime: state.elapsedTime + const Duration(seconds: 1),
        );
      }
    });
  }

  double _calculateTotalDistance(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;
    
    double total = 0.0;
    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];
      
      total += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
    }
    
    return total / 1000; // Convert to kilometers
  }

  double _calculateCurrentPace(List<LocationPoint> route) {
    if (route.length < 10) return 0.0;
    
    final recent = route.takeLast(10).toList();
    final distance = _calculateTotalDistance(recent);
    final timeDiff = recent.last.timestamp.difference(recent.first.timestamp);
    
    if (distance <= 0 || timeDiff.inSeconds <= 0) return 0.0;
    
    return timeDiff.inMinutes / distance;
  }

  double _calculateAveragePace(double distance, Duration time) {
    if (distance <= 0) return 0.0;
    return time.inMinutes / distance;
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }

  Future<void> _saveRunSession() async {
    if (state.route.isEmpty) return;
    
    final session = RunSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: state.startTime!,
      endTime: DateTime.now(),
      route: state.route,
      totalDistance: state.totalDistance,
      totalDuration: state.elapsedTime,
      averagePace: state.averagePace,
      episodeId: state.currentEpisodeId,
    );
    
    // Save to local storage
    await HiveService.saveRunSession(session);
  }
}
```

---

## 📱 Phase 5: Main App Setup (Week 3 continued)

### Step 5.1: Main App Entry Point

**File:** `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'data/data_sources/local/hive_service.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Initialize local storage
  await HiveService.initialize();
  
  // Initialize background audio
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.yourapp.runners_saga.audio',
    androidNotificationChannelName: 'Runner\'s Saga Audio',
    androidNotificationOngoing: true,
  );
  
  // Create provider container
  final container = ProviderContainer();
  
  // Initialize services
  await container.read(backgroundServiceProvider).initialize();
  await container.read(notificationServiceProvider).initialize();
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RunnersSagaApp(),
    ),
  );
}
```

**File:** `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/analytics_service.dart';

class RunnersSagaApp extends ConsumerWidget {
  const RunnersSagaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    // Track app launch
    ref.read(analyticsServiceProvider).trackAppLaunch();
    
    return MaterialApp.router(
      title: 'Runner\'s Saga',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### Step 5.2: App Theme

**File:** `lib/core/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightColorScheme,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightColorScheme.surface,
        foregroundColor: AppColors.lightColorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.darkColorScheme,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkColorScheme.surface,
        foregroundColor: AppColors.darkColorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
```

**File:** `lib/core/theme/colors.dart`

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary colors for running theme
  static const Color primaryGreen = Color(0xFF2E7D57);
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color accentOrange = Color(0xFFFF6B35);
  
  // Neutral colors
  static const Color darkGrey = Color(0xFF2D2D2D);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryGreen,
    onPrimary: white,
    secondary: primaryBlue,
    onSecondary: white,
    tertiary: accentOrange,
    onTertiary: white,
    error: error,
    onError: white,
    surface: white,
    onSurface: darkGrey,
    background: lightGrey,
    onBackground: darkGrey,
  );
  
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryGreen,
    onPrimary: white,
    secondary: primaryBlue,
    onSecondary: white,
    tertiary: accentOrange,
    onTertiary: white,
    error: error,
    onError: white,
    surface: Color(0xFF1E1E1E),
    onSurface: white,
    background: darkGrey,
    onBackground: white,
  );
}
```

---

## 🛣️ Phase 6: Navigation & Routing (Week 3 continued)

### Step 6.1: App Router Setup

**File:** `lib/presentation/routes/app_router.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../pages/home/home_page.dart';
import '../pages/run/run_setup_page.dart';
import '../pages/run/active_run_page.dart';
import '../pages/run/run_summary_page.dart';
import '../pages/story/story_library_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/auth/login_page.dart';
import 'route_names.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: RouteNames.home,
    routes: [
      // Auth Routes
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      
      // Main App Routes
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      
      // Run Routes
      GoRoute(
        path: RouteNames.runSetup,
        name: 'runSetup',
        builder: (context, state) => const RunSetupPage(),
      ),
      GoRoute(
        path: RouteNames.activeRun,
        name: 'activeRun',
        builder: (context, state) {
          final episodeId = state.uri.queryParameters['episodeId'];
          return ActiveRunPage(episodeId: episodeId);
        },
      ),
      GoRoute(
        path: '${RouteNames.runSummary}/:runId',
        name: 'runSummary',
        builder: (context, state) {
          final runId = state.pathParameters['runId']!;
          return RunSummaryPage(runId: runId);
        },
      ),
      
      // Story Routes
      GoRoute(
        path: RouteNames.storyLibrary,
        name: 'storyLibrary',
        builder: (context, state) => const StoryLibraryPage(),
      ),
      
      // Profile Routes
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('The page you\'re looking for doesn\'t exist.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**File:** `lib/presentation/routes/route_names.dart`

```dart
class RouteNames {
  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  
  // Main
  static const String home = '/';
  static const String profile = '/profile';
  static const String settings = '/settings';
  
  // Run
  static const String runSetup = '/run-setup';
  static const String activeRun = '/active-run';
  static const String runSummary = '/run-summary';
  static const String runHistory = '/run-history';
  
  // Story
  static const String storyLibrary = '/stories';
  static const String episodeDetail = '/episode';
  
  // Utils
  static String runSummaryWithId(String runId) => '$runSummary/$runId';
  static String episodeDetailWithId(String episodeId) => '$episodeDetail/$episodeId';
}
```

---

## 📱 Phase 7: Core UI Pages (Week 4)

### Step 7.1: Home Page

**File:** `lib/presentation/pages/home/home_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/run_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/run/run_stats_widget.dart';
import '../routes/route_names.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runNotifierProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runner\'s Saga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push(RouteNames.profile),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, Runner!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ready for your next adventure?',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Quick stats
              const RunStatsWidget(),
              
              const SizedBox(height: 32),
              
              // Main action buttons
              if (!runState.isRunning) ...[
                CustomButton(
                  text: 'Start New Run',
                  icon: Icons.play_arrow,
                  onPressed: () => context.push(RouteNames.runSetup),
                  isPrimary: true,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Browse Stories',
                  icon: Icons.headphones,
                  onPressed: () => context.push(RouteNames.storyLibrary),
                  isPrimary: false,
                ),
              ] else ...[
                CustomButton(
                  text: 'Resume Active Run',
                  icon: Icons.directions_run,
                  onPressed: () => context.push(RouteNames.activeRun),
                  isPrimary: true,
                ),
              ],
              
              const SizedBox(height: 16),
              
              CustomButton(
                text: 'View Run History',
                icon: Icons.history,
                onPressed: () => context.push(RouteNames.runHistory),
                isPrimary: false,
              ),
              
              const Spacer(),
              
              // Quick tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tip of the day',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            'Try interval running with story episodes for better pacing!',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Step 7.2: Active Run Page

**File:** `lib/presentation/pages/run/active_run_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/run_provider.dart';
import '../../widgets/run/run_stats_widget.dart';
import '../../widgets/run/map_widget.dart';
import '../../widgets/story/audio_player_widget.dart';
import '../../widgets/common/custom_button.dart';
import '../routes/route_names.dart';

class ActiveRunPage extends ConsumerWidget {
  final String? episodeId;
  
  const ActiveRunPage({
    super.key,
    this.episodeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runNotifierProvider);
    final runNotifier = ref.read(runNotifierProvider.notifier);
    
    return WillPopScope(
      onWillPop: () async {
        // Prevent accidental back navigation during run
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Run?'),
            content: const Text('Are you sure you want to end your current run?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continue Running'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('End Run'),
              ),
            ],
          ),
        );
        
        if (shouldPop == true) {
          await runNotifier.stopRun();
        }
        
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Run'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () => _showStopRunDialog(context, runNotifier),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Map view
              Expanded(
                flex: 2,
                child: MapWidget(route: runState.route),
              ),
              
              // Stats section
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Main stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          title: 'Time',
                          value: _formatDuration(runState.elapsedTime),
                          icon: Icons.timer,
                        ),
                        _StatCard(
                          title: 'Distance',
                          value: '${runState.totalDistance.toStringAsFixed(2)} km',
                          icon: Icons.straighten,
                        ),
                        _StatCard(
                          title: 'Pace',
                          value: '${runState.currentPace.toStringAsFixed(1)} min/km',
                          icon: Icons.speed,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Audio player (if episode is playing)
                    if (runState.currentEpisodeId != null)
                      const AudioPlayerWidget(),
                    
                    const SizedBox(height: 20),
                    
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: runState.isPaused ? 'Resume' : 'Pause',
                            icon: runState.isPaused ? Icons.play_arrow : Icons.pause,
                            onPressed: runState.isPaused 
                              ? runNotifier.resumeRun 
                              : runNotifier.pauseRun,
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Finish',
                            icon: Icons.stop,
                            onPressed: () => _showStopRunDialog(context, runNotifier),
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _showStopRunDialog(
    BuildContext context, 
    RunNotifier runNotifier,
  ) async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Run'),
        content: const Text('Are you ready to finish your run and save your progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish Run'),
          ),
        ],
      ),
    );

    if (shouldStop == true) {
      await runNotifier.stopRun();
      if (context.mounted) {
        context.go(RouteNames.home);
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🧪 Phase 8: Testing & Deployment (Week 4)

### Step 8.1: Widget Testing Setup

**File:** `test/widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runners_saga/main.dart';

void main() {
  group('App Widget Tests', () {
    testWidgets('App starts and shows home page', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: RunnersSagaApp(),
        ),
      );

      // Verify that the home page is displayed
      expect(find.text('Runner\'s Saga'), findsOneWidget);
      expect(find.text('Welcome back, Runner!'), findsOneWidget);
    });

    testWidgets('Navigation to story library works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: RunnersSagaApp(),
        ),
      );

      // Tap the browse stories button
      await tester.tap(find.text('Browse Stories'));
      await tester.pumpAndSettle();

      // Verify navigation to story library
      expect(find.text('Story Library'), findsOneWidget);
    });
  });
}
```

### Step 8.2: Unit Testing

**File:** `test/unit/location_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runners_saga/data/data_sources/sensors/location_service.dart';

void main() {
  group('LocationService Tests', () {
    test('calculateDistance returns correct distance', () {
      final pos1 = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      
      final pos2 = Position(
        latitude: 37.7849,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final distance = LocationService.calculateDistance(pos1, pos2);
      
      // Should be approximately 1111 meters (1 degree ≈ 111km)
      expect(distance, greaterThan(1000));
      expect(distance, lessThan(1200));
    });

    test('calculatePace returns correct pace', () {
      const distance = 5.0; // 5km
      const time = Duration(minutes: 25); // 25 minutes
      
      final pace = LocationService.calculatePace(distance, time);
      
      expect(pace, equals(5.0)); // 5 min/km
    });
  });
}
```

### Step 8.3: Integration Testing

**File:** `integration_test/app_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:runners_saga/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('Complete run flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Start from home page
      expect(find.text('Start New Run'), findsOneWidget);
      
      // Navigate to run setup
      await tester.tap(find.text('Start New Run'));
      await tester.pumpAndSettle();
      
      // Should be on run setup page
      expect(find.text('Run Setup'), findsOneWidget);
      
      // Start run without story
      await tester.tap(find.text('Start Run'));
      await tester.pumpAndSettle();
      
      // Should be on active run page
      expect(find.text('Active Run'), findsOneWidget);
      expect(find.text('00:00:00'), findsOneWidget); // Initial time
      
      // Wait a bit for timer to update
      await tester.pump(const Duration(seconds: 2));
      
      // Time should have updated
      expect(find.text('00:00:01'), findsOneWidget);
    });
  });
}
```

---

## 📋 Deployment Checklist

### Step 9.1: Android Configuration

**File:** `android/app/src/main/AndroidManifest.xml`

Add these permissions:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
```

### Step 9.2: Build Commands

**Development Build:**
```bash
flutter run --debug
```

**Release Build:**
```bash
flutter build apk --release
flutter build appbundle --release
```

**Testing Commands:**
```bash
# Unit tests
flutter test

# Widget tests
flutter test test/widget_test.dart

# Integration tests
flutter test integration_test/

# Code generation
dart run build_runner build --delete-conflicting-outputs

# Code analysis
flutter analyze

# Format code
dart format lib/ test/
```

---

## 🎯 Implementation Timeline

### Week 1: Foundation
- [ ] Update dependencies in pubspec.yaml
- [ ] Create folder structure
- [ ] Set up constants and themes
- [ ] Remove audioplayers dependency
- [ ] Test build with new dependencies

### Week 2: Data Layer
- [ ] Implement Hive data models
- [ ] Create location service with motion detection
- [ ] Implement audio service with caching
- [ ] Set up local storage with HiveService
- [ ] Test data persistence

### Week 3: State Management
- [ ] Implement Riverpod providers
- [ ] Create run state management
- [ ] Set up navigation with GoRouter
- [ ] Implement main app structure
- [ ] Test state management flow

### Week 4: UI & Polish
- [ ] Create core UI pages
- [ ] Implement custom widgets
- [ ] Add error handling and analytics
- [ ] Set up testing framework
- [ ] Optimize performance

---

## 🚨 Critical Notes for Cursor

1. **Always run code generation after creating/modifying models:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. **Test location permissions on real device** - emulator GPS can be unreliable

3. **Audio files must be cached locally** for offline playback during runs

4. **Background location requires special permissions** - test thoroughly on target devices

5. **Battery optimization is critical** - monitor GPS and audio usage

6. **Use proper error handling** - GPS and audio can fail unpredictably

7. **Test with airplane mode** to ensure offline functionality

---

## 📞 Support & Troubleshooting

### Common Issues:

**Build Runner Conflicts:**
```bash
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

**Location Permission Issues:**
- Check AndroidManifest.xml permissions
- Test on real device, not emulator
- Ensure background location permission for API 29+

**Audio Playback Issues:**
- Verify just_audio_background initialization
- Check notification permissions
- Test with cached files, not streaming URLs

**State Management Issues:**
- Ensure providers are properly annotated
- Run code generation after provider changes
- Check provider scope (keepAlive where needed)

This implementation guide provides a complete roadmap for optimizing your Runner's Saga app. Follow the phases in order and test thoroughly at each step!