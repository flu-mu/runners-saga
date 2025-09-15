import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/run_enums.dart';
import '../story/scene_trigger_service.dart';
import 'coach_service.dart';
import '../../providers/coach_providers.dart';
import '../../models/run_stats_model.dart';

class ProgressMonitorService {
  // Timer and monitoring state
  Timer? _progressTimer;
  bool _isMonitoring = false;
  bool _isPaused = false; // Add missing paused state
  bool _timersStopped = false; // Flag to prevent timer restart
  bool _globallyStopped = false; // Global flag to prevent any restart
  bool _forceStopped = false; // Additional force stop flag
  late final Ref _ref;

  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _totalPausedTime = Duration.zero;
  
  // Progress tracking
  double _currentDistance = 0.0;
  Duration _elapsedTime = Duration.zero;
  double _currentPace = 0.0;
  double _averagePace = 0.0;
  double _maxPace = 0.0;
  double _minPace = double.infinity;
  
  // Location tracking
  Position? _lastPosition;
  List<Position> _route = [];
  StreamSubscription<Position>? _positionStream;
  Timer? _gpsBackupTimer;
  
  // App lifecycle tracking
  bool _isAppInBackground = false;
  DateTime? _lastGpsUpdate;
  
  // Scene trigger integration
  SceneTriggerService? _sceneTriggerService;
  Timer? _backgroundProgressTimer;

  // Coach readout tracking
  Duration _lastReadoutTime = Duration.zero;
  double _lastReadoutDistance = 0.0;
  
  // Targets
  Duration _targetTime = Duration.zero;
  double _targetDistance = 0.0;

  // Tracking configuration
  TrackingMode _trackingMode = TrackingMode.gps;
  double _strideMeters = 1.0; // meters per step for step-counting
  double _simulatePaceMinPerKm = 6.0; // minutes per kilometer for simulated runs
  bool _trackingEnabled = true;
  int _steps = 0; // simple accumulator; real step events should update this
  
  // Callbacks
  Function(double distance)? onDistanceUpdate;
  Function(Duration time)? onTimeUpdate;
  Function(double pace)? onPaceUpdate;
  Function(double progress, Duration elapsedTime, double distance)? onProgressUpdate;
  Function(List<Position> route)? onRouteUpdate;
  
  // Getters
  bool get isMonitoring => _isMonitoring;
  bool get isPaused => _isPaused;
  double get currentDistance => _currentDistance;
  Duration get elapsedTime => _elapsedTime;
  double get currentPace => _currentPace;
  double get averagePace => _averagePace;
  double get maxPace => _maxPace;
  double get minPace => _minPace;
  List<Position> get route => List.unmodifiable(_route);
  double get progress => _calculateProgress();

  /// Initialize the progress monitor with targets
  void initialize({
    required Duration targetTime,
    required double targetDistance,
    TrackingMode trackingMode = TrackingMode.gps,
    double strideMeters = 1.0,
    double simulatePaceMinPerKm = 6.0,
    bool trackingEnabled = true,
    Function(double distance)? onDistanceUpdate,
    Function(Duration time)? onTimeUpdate,
    Function(double pace)? onPaceUpdate,
    Function(double progress, Duration elapsedTime, double distance)? onProgressUpdate,
    Function(List<Position> route)? onRouteUpdate,
  }) {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
    _trackingMode = trackingMode;
    _strideMeters = strideMeters;
    _simulatePaceMinPerKm = simulatePaceMinPerKm;
    _trackingEnabled = trackingEnabled;
    this.onDistanceUpdate = onDistanceUpdate;
    this.onTimeUpdate = onTimeUpdate;
    this.onPaceUpdate = onPaceUpdate;
    this.onProgressUpdate = onProgressUpdate;
    this.onRouteUpdate = onRouteUpdate;
    
    // Don't reset state here - it will be reset when start() is called
  }

  /// Set the Riverpod ref for service access.
  void setRef(Ref ref) {
    _ref = ref;
  }

  /// Start monitoring progress
  Future<void> start() async {
    if (_isMonitoring) return;
    
    // Simple check - only start if not already monitoring
    print('🚀 ProgressMonitorService: Starting progress monitor...');
    
    try {
      _startTime = DateTime.now();
      _isMonitoring = true;
      _lastReadoutTime = Duration.zero;
      _lastReadoutDistance = 0.0;
      
      if (kDebugMode) {
        print('Progress monitor start time set to: $_startTime');
      }
      
      // Start progress timer immediately (don't wait for location)
      _startProgressTimer();
      
      // Start appropriate tracking based on mode
      if (_trackingMode == TrackingMode.gps && _trackingEnabled) {
        // Try to start location tracking (but don't fail if it doesn't work)
        try {
          // Check location permissions
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            final requested = await Geolocator.requestPermission();
            if (requested != LocationPermission.whileInUse &&
                requested != LocationPermission.always) {
              if (kDebugMode) {
                print('Location permission denied, continuing without location tracking');
              }
            } else {
              _startLocationTracking();
            }
          } else {
            _startLocationTracking();
          }
        } catch (locationError) {
          if (kDebugMode) {
            print('Location tracking failed, continuing without it: $locationError');
          }
        }
      } else {
        // Step counting or simulate modes do not start GPS
        if (kDebugMode) {
          print('ProgressMonitorService: Using ${_trackingMode.name} mode - GPS not started');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error starting progress monitor: $e');
      }
      rethrow;
    }
  }

  /// Stop monitoring progress
  void stop() {
    _isMonitoring = false;
    _stopLocationTracking();
    _stopProgressTimer();
    
    // DON'T reset state - keep the route data!
    print('🛑 ProgressMonitorService: stop() called - _isMonitoring set to false - route data preserved');
  }

  /// Pause monitoring progress
  void pause() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _pauseTime = DateTime.now();
    _stopLocationTracking();
    _stopProgressTimer();
  }

  /// Resume monitoring progress
  void resume() {
    if (_isMonitoring) return;
    
    // Simple check - only resume if not already monitoring
    
    if (_pauseTime != null) {
      _totalPausedTime += DateTime.now().difference(_pauseTime!);
      _pauseTime = null;
    }
    
    _isMonitoring = true;
    _startLocationTracking();
    _startProgressTimer();
  }

  /// Start location tracking
  void _startLocationTracking() {
    print('📍 ProgressMonitorService: Starting GPS location tracking...');
    
    // Get initial position
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    ).then((position) {
      _lastPosition = position;
      _route.add(position);
      print('📍 ProgressMonitorService: Initial position captured: (${position.latitude}, ${position.longitude})');
      onRouteUpdate?.call(_route);
    }).catchError((e) {
      if (kDebugMode) {
        print('Error getting initial position: $e');
      }
    });
    
    // Start position stream with minimal distance filter for continuous tracking
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Capture ALL positions, even stationary
      ),
    ).listen((position) {
      _onPositionUpdate(position);
    });
    
    // Start backup timer to ensure we get positions even when stationary
    _startGpsBackupTimer();
  }

  /// Stop location tracking
  void _stopLocationTracking() {
    print('📍 ProgressMonitorService: Stopping GPS location tracking...');
    print('📍 ProgressMonitorService: Route contains ${_route.length} GPS points before stopping');
    _positionStream?.cancel();
    _positionStream = null;
    _stopGpsBackupTimer();
  }
  
  /// Start backup GPS timer to ensure regular position capture
  void _startGpsBackupTimer() {
    _gpsBackupTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isMonitoring) {
        return;
      }
      
      try {
        // Get current position manually as backup
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        
        // Add with timestamp and logging
        print('📍 GPS Backup Timer: Adding position (${position.latitude}, ${position.longitude})');
        _onPositionUpdate(position);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ GPS Backup Timer: Failed to get position: $e');
        }
      }
    });
  }
  
  /// Stop backup GPS timer
  void _stopGpsBackupTimer() {
    _gpsBackupTimer?.cancel();
    _gpsBackupTimer = null;
  }

  /// Start progress timer
  void _startProgressTimer() {
    if (!_isMonitoring) return; // Don't start if not monitoring
    
    if (kDebugMode) {
      print('Starting progress timer');
      print('_isMonitoring: $_isMonitoring');
      print('_startTime: $_startTime');
    }
    
    // Use a simple, controllable timer instead of Timer.periodic
    _startSimpleTimer();
  }
  
  /// Start a simple timer that's easier to control
  void _startSimpleTimer() {
    if (!_isMonitoring) return; // Only check if monitoring is active
    
    // Use a completely different approach - no recursive timers
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simple stop check - only check if monitoring is active
      if (!_isMonitoring) {
        if (kDebugMode) {
          print('🛑 Timer tick but monitoring stopped - cancelling timer');
        }
        
        // Cancel the timer
        timer.cancel();
        _progressTimer = null;
        
        // Exit immediately
        return;
      }
      
      // Only proceed if monitoring is active
      _updateElapsedTime();
      _updateDistanceForNonGps();
      _updateProgress();

      _checkForCoachReadout();
      
      if (kDebugMode) {
        print('Simple timer tick: elapsedTime=${_elapsedTime.inSeconds}s, progress=${(_calculateProgress() * 100).toStringAsFixed(1)}%');
      }
    });
  }

  /// Update distance for non-GPS tracking modes on each tick
  void _updateDistanceForNonGps() {
    if (!_trackingEnabled) {
      // Explicitly disabled tracking; keep distance 0
      return;
    }
    if (_trackingMode == TrackingMode.simulate) {
      // pace: minutes per km
      final minutes = _elapsedTime.inSeconds / 60.0;
      final distance = _simulatePaceMinPerKm > 0 ? minutes / _simulatePaceMinPerKm : 0.0;
      if ((distance - _currentDistance).abs() > 1e-6) {
        _currentDistance = distance;
        onDistanceUpdate?.call(_currentDistance);
      }
    } else if (_trackingMode == TrackingMode.steps) {
      // Distance from steps; expects _steps to be updated by a step-counting service
      final distance = (_steps * _strideMeters) / 1000.0; // km
      if ((distance - _currentDistance).abs() > 1e-6) {
        _currentDistance = distance;
        onDistanceUpdate?.call(_currentDistance);
      }
    }
  }

  /// External API to feed step counts (to be connected to a pedometer service)
  void addSteps(int stepDelta) {
    if (stepDelta <= 0) return;
    _steps += stepDelta;
    if (_trackingMode == TrackingMode.steps) {
      _updateDistanceForNonGps();
    }
  }

  /// Stop progress timer
  void _stopProgressTimer() {
    if (_progressTimer != null) {
      _progressTimer!.cancel();
      _progressTimer = null;
      print('🛑 ProgressMonitorService: Progress timer stopped');
    }
  }
  
  /// Force stop progress timer (more aggressive)
  void _forceStopProgressTimer() {
    // Cancel multiple times to ensure it's stopped
    if (_progressTimer != null) {
      _progressTimer!.cancel();
      _progressTimer = null;
      print('🛑 ProgressMonitorService: Progress timer force stopped');
    }
    
    // Also check if there are any other timers running
    // This is a safety measure
    if (_progressTimer != null) {
      print('🛑 ProgressMonitorService: WARNING - timer still exists after cancel');
      _progressTimer!.cancel();
      _progressTimer = null;
    }
    
    // Don't set stop flags - just stop the timer
    print('🛑 ProgressMonitorService: Timer stopped without setting stop flags');
  }
  
  /// Public method to stop the progress timer
  void stopTimer() {
    _stopProgressTimer();
  }
  
  /// Public method to force stop monitoring
  void forceStopMonitoring() {
    print('🛑 ProgressMonitorService: forceStopMonitoring() called - Route had ${_route.length} GPS points');
    _isMonitoring = false; // Just stop monitoring, don't set aggressive flags
    
    // Use simple timer stopping
    _forceStopProgressTimer();
    
    // Clear all callbacks to prevent further updates
    onDistanceUpdate = null;
    onTimeUpdate = null;
    onPaceUpdate = null;
    onProgressUpdate = null;
    onRouteUpdate = null;
    
    // DON'T reset state - keep the route data!
    print('🛑 ProgressMonitorService: _isMonitoring set to false - route data preserved');
  }
  


  /// Nuclear option: completely kill all timers
  void nuclearStop() {
    _isMonitoring = false; // Just stop monitoring, don't set aggressive flags
    
    // Cancel any existing timer
    if (_progressTimer != null) {
      _progressTimer!.cancel();
      _progressTimer = null;
    }
    
    // Stop GPS tracking and backup timer
    _stopLocationTracking();
    
    // Clear all callbacks
    onDistanceUpdate = null;
    onTimeUpdate = null;
    onPaceUpdate = null;
    onProgressUpdate = null;
    onRouteUpdate = null;
    
    // DON'T reset state - keep the route data!
    print('☢️ ProgressMonitorService: NUCLEAR STOP - All timers killed - route data preserved');
  }

  /// Handle position updates
  void _onPositionUpdate(Position position) {
    if (!_isMonitoring) {
      return; // Don't process if not monitoring
    }
    
    // Always add the position to route first
    _route.add(position);
    
    if (kDebugMode) {
      print('📍 Position added to route: (${position.latitude}, ${position.longitude}) - Total points: ${_route.length}');
      print('📍 Route now contains ${_route.length} GPS points');
    }
    
    // If this is the first position, just store it and return
    if (_lastPosition == null) {
      _lastPosition = position;
      onRouteUpdate?.call(_route);
      return;
    }
    
    // Calculate distance from last position
    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    ) / 1000; // Convert to kilometers
    
    // Update total distance
    _currentDistance += distance;
    
    // Calculate current pace (minutes per kilometer)
    if (distance > 0) {
      // Calculate time difference using elapsed seconds or current time
      final timeDiff = _lastPosition != null 
          ? Duration(seconds: 5) // Assume 5 seconds between GPS updates
          : Duration.zero;
      if (timeDiff.inSeconds > 0) {
        _currentPace = timeDiff.inMinutes / distance;
        
        // Update pace statistics
        if (_currentPace > 0) {
          _averagePace = (_averagePace * (_route.length - 1) + _currentPace) / _route.length;
          if (_currentPace > _maxPace) _maxPace = _currentPace;
          if (_currentPace < _minPace) _minPace = _currentPace;
        }
      }
    }
    
    // Update last position
    _lastPosition = position;
    _lastGpsUpdate = DateTime.now(); // Update last GPS update time
    
    // Notify listeners
    onDistanceUpdate?.call(_currentDistance);
    onPaceUpdate?.call(_currentPace);
    onRouteUpdate?.call(_route);
  }

  /// Update elapsed time
  void _updateElapsedTime() {
    // Don't update if monitoring is stopped
    if (!_isMonitoring) {
      if (kDebugMode) {
        print('🛑 _updateElapsedTime: Skipping update - monitoring stopped');
      }
      return;
    }
    
    if (kDebugMode) {
      print('_updateElapsedTime called: _startTime=$_startTime, _isMonitoring=$_isMonitoring');
    }
    
    if (_startTime == null) {
      if (kDebugMode) {
        print('ERROR: _startTime is null in _updateElapsedTime - but monitoring is stopped, not setting start time');
      }
      return;
    }
    
    _elapsedTime = DateTime.now().difference(_startTime!) - _totalPausedTime;
    
    if (kDebugMode) {
      print('Time update: startTime=$_startTime, now=${DateTime.now()}, elapsedTime=$_elapsedTime');
    }
    
    onTimeUpdate?.call(_elapsedTime);
  }

  /// Update progress
  void _updateProgress() {
    // Don't update if monitoring is stopped
    if (!_isMonitoring) {
      if (kDebugMode) {
        print('🛑 _updateProgress: Skipping update - monitoring stopped');
      }
      return;
    }
    
    final progress = _calculateProgress();
    onProgressUpdate?.call(progress, _elapsedTime, _currentDistance);
  }

  /// Calculate current progress
  double _calculateProgress() {
    double timeProgress = _elapsedTime.inSeconds / _targetTime.inSeconds;
    double distanceProgress = _currentDistance / _targetDistance;
    
    if (kDebugMode) {
      print('Progress calc: elapsedTime=${_elapsedTime.inSeconds}s, targetTime=${_targetTime.inSeconds}s, timeProgress=${(timeProgress * 100).toStringAsFixed(1)}%');
    }
    
    // Use the higher progress value
    return (timeProgress > distanceProgress ? timeProgress : distanceProgress).clamp(0.0, 1.0);
  }

  // _resetState() method removed - we don't want to clear route data

  /// Get current run statistics
  Map<String, dynamic> getRunStats() {
    return {
      'distance': _currentDistance,
      'elapsedTime': _elapsedTime,
      'currentPace': _currentPace,
      'averagePace': _averagePace,
      'maxPace': _maxPace,
      'minPace': _minPace == double.infinity ? 0.0 : _minPace,
      'progress': _calculateProgress(),
      'route': _route,
    };
  }
  
  /// Check if monitoring is stopped
  bool get isStopped => !_isMonitoring;

  /// Manually update distance (for testing or external tracking)
  void updateDistance(double distance) {
    _currentDistance = distance;
    onDistanceUpdate?.call(_currentDistance);
    _updateProgress();
  }

  /// Manually update time (for testing or external tracking)
  void updateTime(Duration time) {
    _elapsedTime = time;
    onTimeUpdate?.call(_elapsedTime);
    _updateProgress();
  }
  
  // updateRoute method removed - it was clearing the real GPS data unnecessarily

  /// Dispose resources
  void dispose() {
    stop();
  }

  /// Handle app lifecycle changes
  void onAppLifecycleChanged(bool isInBackground) {
    if (_isAppInBackground == isInBackground) return;
    
    _isAppInBackground = isInBackground;
    
    if (isInBackground) {
      _handleAppBackgrounded();
    } else {
      _handleAppForegrounded();
    }
    
    debugPrint('📱 ProgressMonitorService: App ${isInBackground ? 'backgrounded' : 'foregrounded'}');
  }
  
  /// Handle app going to background
  void _handleAppBackgrounded() {
    debugPrint('📱 ProgressMonitorService: App backgrounded, ensuring GPS continues...');
    
    // Ensure GPS tracking continues in background
    if (_isMonitoring && !_isPaused) {
      _ensureGpsTrackingActive();
      _persistCurrentState();
      
      // Start background progress monitoring for scene triggers
      _startBackgroundProgressMonitoring();
    }
  }
  
  /// Handle app coming to foreground
  void _handleAppForegrounded() {
    debugPrint('📱 ProgressMonitorService: App foregrounded, checking GPS continuity...');
    
    // Check if GPS tracking continued while in background
    _validateGpsContinuity();
    
    // Stop background progress monitoring
    _stopBackgroundProgressMonitoring();
    
    // Restore real-time updates
    if (_isMonitoring && !_isPaused) {
      _startLocationTracking();
    }
  }
  
  /// Ensure GPS tracking is active in background
  void _ensureGpsTrackingActive() {
    if (_positionStream?.isPaused == true) {
      _positionStream?.resume();
      debugPrint('📍 ProgressMonitorService: GPS stream resumed for background');
    }
    
    // Ensure backup timer is running
    if (_gpsBackupTimer?.isActive != true) {
      _startGpsBackupTimer();
    }
  }
  
  /// Validate GPS continuity after app returns from background
  void _validateGpsContinuity() {
    if (_lastGpsUpdate == null) return;
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastGpsUpdate!);
    if (timeSinceLastUpdate > const Duration(minutes: 2)) {
      debugPrint('⚠️ ProgressMonitorService: GPS update gap detected: $timeSinceLastUpdate');
      
      // Try to get a fresh position immediately
      _getImmediatePosition();
    }
  }
  
  /// Get immediate position to fill any gaps
  void _getImmediatePosition() {
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    ).then((position) {
      _onPositionUpdate(position);
      debugPrint('📍 ProgressMonitorService: Immediate position captured after background gap');
    }).catchError((e) {
      debugPrint('❌ ProgressMonitorService: Failed to get immediate position: $e');
    });
  }
  
  /// Persist current state to SharedPreferences
  Future<void> _persistCurrentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_monitoringStateKey, _isMonitoring.toString());
      if (_startTime != null) {
        await prefs.setString(_startTimeKey, _startTime!.toIso8601String());
      }
      
      debugPrint('💾 ProgressMonitorService: Monitoring state persisted');
    } catch (e) {
      debugPrint('❌ ProgressMonitorService: Failed to persist monitoring state: $e');
    }
  }

  // Background GPS persistence
  static const String _routeKey = 'gps_route';
  static const String _lastPositionKey = 'last_position';
  static const String _monitoringStateKey = 'monitoring_state';
  static const String _startTimeKey = 'monitor_start_time';

  /// NEW: Persist GPS data for background survival
  Future<void> _persistGpsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save route data every 10 GPS points
      final routeJson = _route.map((pos) => {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'timestamp': pos.timestamp?.toIso8601String(),
        'speed': pos.speed,
        'heading': pos.heading,
        'altitude': pos.altitude,
      }).toList();
      
      await prefs.setString('gps_route_${DateTime.now().millisecondsSinceEpoch}', 
                           jsonEncode(routeJson));
      
      if (kDebugMode) {
        print('💾 GPS route persisted: ${_route.length} points, Distance: ${_currentDistance.toStringAsFixed(3)}km');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to persist GPS data: $e');
      }
    }
  }

  /// Set the scene trigger service for background integration
  void setSceneTriggerService(SceneTriggerService service) {
    _sceneTriggerService = service;
    if (kDebugMode) {
      print('🎬 ProgressMonitorService: Scene trigger service connected for background integration');
    }
  }
  
  /// Start background progress monitoring for scene triggers
  void _startBackgroundProgressMonitoring() {
    if (_backgroundProgressTimer != null) return;
    
    debugPrint('🎬 ProgressMonitorService: Starting background progress monitoring for scene triggers...');
    
    // Monitor progress every 5 seconds in background to check scene triggers
    _backgroundProgressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isMonitoring || _isPaused) {
        timer.cancel();
        _backgroundProgressTimer = null;
        return;
      }
      
      // Update progress and check scene triggers
      _updateProgressForBackground();
    });
  }
  
  /// Stop background progress monitoring
  void _stopBackgroundProgressMonitoring() {
    if (_backgroundProgressTimer != null) {
      _backgroundProgressTimer!.cancel();
      _backgroundProgressTimer = null;
      debugPrint('🎬 ProgressMonitorService: Background progress monitoring stopped');
    }
  }
  
  /// Update progress for background scene trigger checking
  void _updateProgressForBackground() {
    if (!_isMonitoring || _isPaused) return;
    
    // Calculate current progress
    final progress = _calculateProgress();
    
    // Update scene trigger service if available
    if (_sceneTriggerService != null) {
      try {
        // Update scene trigger service with current progress and elapsed time
        _sceneTriggerService!.updateProgress(
          progress: progress,
          elapsedTime: _elapsedTime,
          distance: _currentDistance,
        );
        
        if (kDebugMode) {
          print('🎬 Background progress update: ${(progress * 100).toStringAsFixed(1)}%, elapsedTime: ${_elapsedTime.inSeconds}s');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Background scene trigger update failed: $e');
        }
      }
    }
  }
}
