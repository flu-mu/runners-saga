import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';
import '../models/run_model.dart';
import '../models/run_target_model.dart';
import '../services/firebase/firestore_service.dart';
import '../services/story/scene_trigger_service.dart';
import 'firebase_providers.dart';

// Provider for current run state
final currentRunProvider = StateNotifierProvider<RunTrackingNotifier, RunModel?>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return RunTrackingNotifier(firestoreService);
});

// Provider for run statistics (distance, time, pace)
final runStatsProvider = Provider<RunStats>((ref) {
  final currentRun = ref.watch(currentRunProvider);
  if (currentRun == null) return RunStats.initial();
  
  return RunStats(
    distance: currentRun.totalDistance,
    elapsedTime: currentRun.totalTime,
    averagePace: currentRun.averagePace,
    currentPace: _calculateCurrentPaceFromRoute(currentRun.route ?? []),
    maxPace: currentRun.maxPace,
    minPace: currentRun.minPace,
    progress: 0.0, // Default progress
    playedScenes: [], // No scenes for this provider
    currentScene: null, // No current scene
    route: currentRun.route ?? [], // Include the route (empty list if null)
  );
});

// Provider for location permission status
final locationPermissionProvider = StateProvider<PermissionStatus>((ref) {
  return PermissionStatus.denied;
});

// Provider for GPS service status
final gpsServiceProvider = StateProvider<geolocator.ServiceStatus>((ref) {
  return geolocator.ServiceStatus.disabled;
});

// Provider for Firestore service - lazy initialization with Firebase readiness check
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  try {
    // Check if Firebase is ready before creating the service
    final firebaseStatus = ref.watch(firebaseStatusProvider);
    
    if (firebaseStatus == FirebaseStatus.ready) {
      print('✅ firestoreServiceProvider: Firebase ready, creating FirestoreService');
      return FirestoreService();
    } else if (firebaseStatus == FirebaseStatus.initializing) {
      print('⏳ firestoreServiceProvider: Firebase still initializing, waiting...');
      throw Exception('Firebase still initializing');
    } else {
      print('❌ firestoreServiceProvider: Firebase failed to initialize');
      throw Exception('Firebase failed to initialize');
    }
  } catch (e) {
    print('❌ firestoreServiceProvider: Error creating FirestoreService: $e');
    rethrow;
  }
});

// Provider for user's run history - waits for Firebase to be ready
final userRunsProvider = StreamProvider<List<RunModel>>((ref) {
  try {
    // Wait for Firebase to be ready
    final firebaseStatus = ref.watch(firebaseStatusProvider);
    
    if (firebaseStatus == FirebaseStatus.ready) {
      print('✅ userRunsProvider: Firebase ready, loading runs');
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.getUserRunsStream().map((runs) {
        final sortedRuns = [...runs]..sort((a, b) => b.startTime.compareTo(a.startTime));
        return sortedRuns;
      }).handleError((error, stackTrace) {
        print('⚠️ userRunsProvider: Error loading runs: $error');
        print('⚠️ userRunsProvider: Stack trace: $stackTrace');
        // Return empty list instead of crashing
        return <RunModel>[];
      });
    } else if (firebaseStatus == FirebaseStatus.initializing) {
      print('⏳ userRunsProvider: Firebase still initializing, waiting...');
      // Return empty stream while Firebase initializes
      return Stream.value(<RunModel>[]);
    } else {
      print('❌ userRunsProvider: Firebase failed to initialize');
      // Return empty stream on Firebase failure
      return Stream.value(<RunModel>[]);
    }
  } catch (e, stackTrace) {
    print('❌ userRunsProvider: Error initializing provider: $e');
    print('❌ userRunsProvider: Stack trace: $stackTrace');
    // Return empty list on initialization error
    return Stream.value(<RunModel>[]);
  }
});

// Provider for user's completed runs only
final userCompletedRunsProvider = StreamProvider<List<RunModel>>((ref) {
  try {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getCompletedRunsStream().handleError((error, stackTrace) {
      print('⚠️ userCompletedRunsProvider: Error loading completed runs: $error');
      print('⚠️ userCompletedRunsProvider: Stack trace: $stackTrace');
      // Return empty list instead of crashing
      return <RunModel>[];
    });
  } catch (e, stackTrace) {
    print('❌ userCompletedRunsProvider: Error initializing provider: $e');
    print('❌ userCompletedRunsProvider: Stack trace: $stackTrace');
    // Return empty list on initialization error
    return Stream.value(<RunModel>[]);
  }
});

// Provider for user's run statistics
final userRunStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserRunStats();
});

// Provider for selected run target (time or distance)
final selectedRunTargetProvider = StateProvider<RunTarget?>((ref) {
  return null;
});

// Helper function to calculate current pace from route
double _calculateCurrentPaceFromRoute(List<LocationPoint> route) {
  if (route.length < 2) return 0.0;
  
  final lastPoint = route.last;
  final secondLastPoint = route[route.length - 2];
  
  final distance = geolocator.Geolocator.distanceBetween(
    secondLastPoint.latitude,
    secondLastPoint.longitude,
    lastPoint.latitude,
    lastPoint.longitude,
  ) / 1000; // Convert to kilometers
  
  // Calculate time difference using elapsed seconds
  final timeDiff = Duration(seconds: lastPoint.elapsedSeconds - secondLastPoint.elapsedSeconds);
  final timeInMinutes = timeDiff.inSeconds / 60;
  
  if (distance > 0 && timeInMinutes > 0) {
    return timeInMinutes / distance;
  }
  
  return 0.0;
}

// Run tracking notifier
class RunTrackingNotifier extends StateNotifier<RunModel?> {
  RunTrackingNotifier(this._firestoreService) : super(null);
  
  final FirestoreService _firestoreService;
  Timer? _statsTimer;
  StreamSubscription<geolocator.Position>? _positionStream;
  
  // Start a new run
  Future<void> startRun({
    required String userId,
    required String seasonId,
    required String missionId,
    required RunTarget runTarget,
  }) async {
    // Check permissions first
    final permissionStatus = await _checkLocationPermission();
    if (permissionStatus != PermissionStatus.granted) {
      throw Exception('Location permission not granted');
    }
    
    // Check if GPS is enabled
    final isGpsEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      throw Exception('GPS service is disabled');
    }
    
    // Create new run
    final newRun = RunModel(
      userId: userId,
      startTime: DateTime.now(),
      route: [],
      totalDistance: 0.0,
      totalTime: Duration.zero,
      averagePace: 0.0,
      maxPace: 0.0,
      minPace: 0.0,
      seasonId: seasonId,
      missionId: missionId,
      status: RunStatus.inProgress,
      runTarget: runTarget,
    );
    
    // Save run to Firestore and get the ID
    final runId = await _firestoreService.saveRun(newRun);
    
    // Update run with the Firestore ID
    final savedRun = newRun.copyWith(id: runId);
    state = savedRun;
    
    // Start location tracking
    await _startLocationTracking();
    
    // Start stats update timer
    _startStatsTimer();
  }
  
  // Pause the current run
  Future<void> pauseRun() async {
    if (state != null && state!.status == RunStatus.inProgress) {
      final pausedRun = state!.copyWith(status: RunStatus.paused);
      state = pausedRun;
      
      // Update run in Firestore
      if (pausedRun.id != null) {
        await _firestoreService.updateRun(pausedRun.id!, pausedRun);
      }
      
      _stopLocationTracking();
    }
  }
  
  // Resume the current run
  Future<void> resumeRun() async {
    if (state != null && state!.status == RunStatus.paused) {
      final resumedRun = state!.copyWith(status: RunStatus.inProgress);
      state = resumedRun;
      
      // Update run in Firestore
      if (resumedRun.id != null) {
        await _firestoreService.updateRun(resumedRun.id!, resumedRun);
      }
      
      await _startLocationTracking();
    }
  }
  
  // Stop and complete the current run
  Future<void> stopRun() async {
    if (state != null) {
      final endTime = DateTime.now();
      final totalTime = endTime.difference(state!.startTime);
      
      // Calculate final statistics
      final finalRun = state!.copyWith(
        endTime: endTime,
        totalTime: totalTime,
        status: RunStatus.completed,
      );
      
      // Stop tracking
      await _stopLocationTracking();
      _stopStatsTimer();
      
      // Note: Run completion is now handled by RunCompletionService
      // Don't save here to avoid duplicates
      
      // Update local state
      state = finalRun;
      debugPrint('Run stopped and marked as completed locally');
    }
  }
  
  // Cancel the current run
  Future<void> cancelRun() async {
    if (state != null) {
      final cancelledRun = state!.copyWith(status: RunStatus.cancelled);
      state = cancelledRun;
      
      // Update run in Firestore
      if (cancelledRun.id != null) {
        await _firestoreService.updateRun(cancelledRun.id!, cancelledRun);
      }
      
      _stopLocationTracking();
      _stopStatsTimer();
    }
  }
  
  // Check location permission
  Future<PermissionStatus> _checkLocationPermission() async {
    PermissionStatus permission = await Permission.location.status;
    
    if (permission == PermissionStatus.denied) {
      permission = await Permission.location.request();
    }
    
    if (permission == PermissionStatus.permanentlyDenied) {
      // Show dialog to open app settings
      // TODO: Implement settings dialog
    }
    
    return permission;
  }
  
  // Start location tracking
  Future<void> _startLocationTracking() async {
    try {
      // Configure location settings
      const locationSettings = geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
        timeLimit: Duration(seconds: 10), // Timeout after 10 seconds
      );
      
      // Start listening to position updates
      _positionStream = geolocator.Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen(
        (geolocator.Position position) {
          _onLocationUpdate(position);
        },
        onError: (error) {
          debugPrint('Location tracking error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to start location tracking: $e');
      rethrow;
    }
  }
  
  // Stop location tracking
  Future<void> _stopLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
  
  // Handle location updates
  void _onLocationUpdate(geolocator.Position position) {
    if (state != null && state!.status == RunStatus.inProgress) {
      final locationPoint = position.toLocationPoint();
      final currentRoute = state!.route ?? [];
      final updatedRoute = [...currentRoute, locationPoint];
      
      // Calculate new distance
      final newDistance = _calculateTotalDistance(updatedRoute);
      
      // Update state
      final updatedRun = state!.copyWith(
        route: updatedRoute,
        totalDistance: newDistance,
        averagePace: _calculateAveragePace(updatedRoute),
        maxPace: _calculateMaxPace(updatedRoute),
        minPace: _calculateMinPace(updatedRoute),
      );
      
      state = updatedRun;
      
      // Periodically save run updates to Firestore (every 10 location updates)
      if (updatedRoute.length % 10 == 0 && updatedRun.id != null) {
        _firestoreService.updateRun(updatedRun.id!, updatedRun).catchError((error) {
          debugPrint('Failed to save run update: $error');
        });
      }
    }
  }
  
  // Start stats update timer
  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state != null && state!.status == RunStatus.inProgress) {
        final currentTime = DateTime.now();
        final totalTime = currentTime.difference(state!.startTime);
        
        state = state!.copyWith(totalTime: totalTime);
      }
    });
  }
  
  // Stop stats update timer
  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }
  
  // Calculate total distance from route
  double _calculateTotalDistance(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 1; i < route.length; i++) {
      totalDistance += geolocator.Geolocator.distanceBetween(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
    }
    
    return totalDistance / 1000; // Convert to kilometers
  }
  
  // Calculate average pace
  double _calculateAveragePace(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;
    
    final totalDistance = _calculateTotalDistance(route);
    if (totalDistance == 0) return 0.0;
    
    // Calculate time difference using elapsed seconds
    final totalTime = Duration(seconds: route.last.elapsedSeconds - route.first.elapsedSeconds);
    final totalTimeInMinutes = totalTime.inSeconds / 60;
    
    return totalTimeInMinutes / totalDistance;
  }
  
  // Calculate maximum pace
  double _calculateMaxPace(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;
    
    double maxPace = 0.0;
    for (int i = 1; i < route.length; i++) {
      final pace = _calculatePaceBetweenPoints(route[i - 1], route[i]);
      if (pace > maxPace) maxPace = pace;
    }
    
    return maxPace;
  }
  
  // Calculate minimum pace
  double _calculateMinPace(List<LocationPoint> route) {
    if (route.length < 2) return double.infinity;
    
    double minPace = double.infinity;
    for (int i = 1; i < route.length; i++) {
      final pace = _calculatePaceBetweenPoints(route[i - 1], route[i]);
      if (pace > 0 && pace < minPace) minPace = pace;
    }
    
    return minPace == double.infinity ? 0.0 : minPace;
  }
  
  // Calculate pace between two points
  double _calculatePaceBetweenPoints(LocationPoint point1, LocationPoint point2) {
    final distance = geolocator.Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.longitude,
      point2.latitude,
    ) / 1000; // Convert to kilometers
    
    // Calculate time difference using elapsed seconds
    final timeDiff = Duration(seconds: point2.elapsedSeconds - point1.elapsedSeconds);
    final timeInMinutes = timeDiff.inSeconds / 60;
    
    if (distance > 0 && timeInMinutes > 0) {
      return timeInMinutes / distance;
    }
    
    return 0.0;
  }
  
  @override
  void dispose() {
    _stopLocationTracking();
    _stopStatsTimer();
    super.dispose();
  }
}

// Run statistics data class
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
  
  const RunStats({
    required this.distance,
    required this.elapsedTime,
    required this.currentPace,
    required this.averagePace,
    required this.maxPace,
    required this.minPace,
    required this.progress,
    required this.playedScenes,
    required this.currentScene,
    required this.route,
  });
  
  factory RunStats.initial() => const RunStats(
    distance: 0.0,
    elapsedTime: Duration.zero,
    currentPace: 0.0,
    averagePace: 0.0,
    maxPace: 0.0,
    minPace: 0.0,
    progress: 0.0,
    playedScenes: [],
    currentScene: null,
    route: [],
  );
  
  // Format time as MM:SS
  String get formattedTime {
    final minutes = elapsedTime.inMinutes;
    final seconds = elapsedTime.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Format distance as X.XX km
  String get formattedDistance => distance.toStringAsFixed(2);
  
  // Format pace as M:SS /km
  String get formattedCurrentPace {
    if (currentPace == 0) return '0:00';
    final minutes = currentPace.floor();
    final seconds = ((currentPace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Format average pace as M:SS /km
  String get formattedAveragePace {
    if (averagePace == 0) return '0:00';
    final minutes = averagePace.floor();
    final seconds = ((averagePace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
