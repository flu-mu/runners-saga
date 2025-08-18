import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_providers.dart';

class ProgressMonitorService {
  // Timer and monitoring state
  Timer? _progressTimer;
  bool _isMonitoring = false;
  bool _timersStopped = false; // Flag to prevent timer restart
  bool _globallyStopped = false; // Global flag to prevent any restart
  bool _forceStopped = false; // Additional force stop flag
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
  
  // Targets
  Duration _targetTime = Duration.zero;
  double _targetDistance = 0.0;
  
  // Tracking mode
  TrackingMode _trackingMode = TrackingMode.gps;
  
  // Callbacks
  Function(double distance)? onDistanceUpdate;
  Function(Duration time)? onTimeUpdate;
  Function(double pace)? onPaceUpdate;
  Function(double progress)? onProgressUpdate;
  Function(List<Position> route)? onRouteUpdate;
  
  // Getters
  bool get isMonitoring => _isMonitoring;
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
    Function(double distance)? onDistanceUpdate,
    Function(Duration time)? onTimeUpdate,
    Function(double pace)? onPaceUpdate,
    Function(double progress)? onProgressUpdate,
    Function(List<Position> route)? onRouteUpdate,
  }) {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
    _trackingMode = trackingMode;
    this.onDistanceUpdate = onDistanceUpdate;
    this.onTimeUpdate = onTimeUpdate;
    this.onPaceUpdate = onPaceUpdate;
    this.onProgressUpdate = onProgressUpdate;
    this.onRouteUpdate = onRouteUpdate;
    
    // Don't reset state here - it will be reset when start() is called
  }

  /// Start monitoring progress
  Future<void> start() async {
    if (_isMonitoring) return;
    
    // Don't start if globally stopped
    if (_globallyStopped) {
      print('🛑 ProgressMonitorService: Cannot start - globally stopped');
      return;
    }
    
    // Don't start if timers were explicitly stopped
    if (_timersStopped) {
      print('🛑 ProgressMonitorService: Cannot start - timers stopped');
      return;
    }
    
    // Double-check: if we're globally stopped, don't start
    if (_globallyStopped || _timersStopped) {
      print('🛑 ProgressMonitorService: Cannot start - stop flags are set (_globallyStopped=$_globallyStopped, _timersStopped=$_timersStopped)');
      return;
    }
    
    try {
      _startTime = DateTime.now();
      _isMonitoring = true;
      
      if (kDebugMode) {
        print('Progress monitor start time set to: $_startTime');
      }
      
      // Start progress timer immediately (don't wait for location)
      _startProgressTimer();
      
      // Don't add hardcoded fallback coordinates - wait for real GPS
      if (kDebugMode) {
        print('📍 ProgressMonitorService: Waiting for real GPS position...');
      }
      
      // Try to start location tracking (but don't fail if it doesn't work)
      try {
        // Check location permissions
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested != LocationPermission.whileInUse && 
              requested != LocationPermission.always) {
            // Don't throw, just log and continue without location
            if (kDebugMode) {
              print('Location permission denied, continuing without location tracking');
            }
          } else {
            // Start location tracking
            _startLocationTracking();
          }
        } else {
          // Start location tracking
          _startLocationTracking();
        }
      } catch (locationError) {
        // Don't fail the entire start process if location fails
        if (kDebugMode) {
          print('Location tracking failed, continuing without it: $locationError');
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
    
    // Don't reset state if we're globally stopped - this prevents restart
    if (!_globallyStopped) {
      _resetState();
    }
    
    print('🛑 ProgressMonitorService: stop() called - _isMonitoring set to false');
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
    
    // Don't resume if timers were explicitly stopped
    if (_timersStopped) return;
    
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
    // Ensure location services are enabled
    Geolocator.isLocationServiceEnabled().then((enabled) async {
      if (!enabled) {
        if (kDebugMode) {
          print('⚠️ Location services disabled. Prompting user to enable.');
        }
        await Geolocator.openLocationSettings();
      }
    });

    // Get initial position
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 10),
    ).then((position) {
      _lastPosition = position;
      _route.add(position);
      onRouteUpdate?.call(_route);
    }).catchError((e) {
      if (kDebugMode) {
        print('Error getting initial position: $e');
      }
    });
    
    // Start position stream
    final settings = const LocationSettings(
      // Highest feasible accuracy for navigation use-case
      accuracy: LocationAccuracy.bestForNavigation,
      // Request very frequent updates for reliable tracking
      distanceFilter: 1,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      if (kDebugMode) {
        print('📍 Position update: lat=${position.latitude}, lon=${position.longitude}, speed=${position.speed} m/s');
      }
      _onPositionUpdate(position);
    });
  }

  /// Stop location tracking
  void _stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Start progress timer
  void _startProgressTimer() {
    if (_timersStopped || _globallyStopped || _forceStopped) return; // Don't restart if timers were stopped
    
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
    if (_forceStopped || _globallyStopped || _timersStopped) return;
    
    // Use a completely different approach - no recursive timers
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // IMMEDIATE stop check - if any flag is set, cancel and return
      if (_forceStopped || _globallyStopped || _timersStopped || !_isMonitoring) {
        if (kDebugMode) {
          print('☢️ Timer tick but stopped - IMMEDIATE CANCELLATION');
          print('☢️ _forceStopped=$_forceStopped, _globallyStopped=$_globallyStopped, _timersStopped=$_timersStopped, _isMonitoring=$_isMonitoring');
        }
        
        // Force cancel the timer
        timer.cancel();
        _progressTimer = null;
        
        // Exit immediately
        return;
      }
      
      // Only proceed if ALL checks pass
      _updateElapsedTime();
      _updateProgress();

      // Web simulation: synthesize tiny movement and distance increments so map and stats progress
      // Only run simulation when explicitly requested
      if (kIsWeb && _trackingMode == TrackingMode.simulate) {
        // 1.4 meters per tick (~3:00 min/km) - more frequent updates for better route visibility
        const meters = 1.4;
        final last = _route.isNotEmpty
            ? _route.last
            : Position(
                latitude: 40.6829,
                longitude: 14.7681,
                timestamp: DateTime.now(),
                accuracy: 5,
                altitude: 0,
                heading: 0,
                speed: 2.8,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
        final dLat = (meters / 111000.0);
        final dLon = dLat / (_cosApprox(last.latitude * 3.1415926535 / 180.0));
        final next = Position(
          latitude: last.latitude + dLat,
          longitude: last.longitude + dLon,
          timestamp: DateTime.now(),
          accuracy: last.accuracy,
          altitude: last.altitude,
          heading: last.heading,
          speed: last.speed,
          speedAccuracy: last.speedAccuracy,
          altitudeAccuracy: last.altitudeAccuracy,
          headingAccuracy: last.headingAccuracy ?? 0,
        );
        _onPositionUpdate(next);
      }
      
      if (kDebugMode) {
        print('Simple timer tick: elapsedTime=${_elapsedTime.inSeconds}s, progress=${(_calculateProgress() * 100).toStringAsFixed(1)}%');
      }
    });
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
    
    // Set all stop flags to prevent any timer from running
    _isMonitoring = false;
    _globallyStopped = true;
    _timersStopped = true;
    
    print('🛑 ProgressMonitorService: All stop flags set to prevent timer restart');
  }
  
  /// Public method to stop the progress timer
  void stopTimer() {
    _timersStopped = true; // Prevent timer from being restarted
    _stopProgressTimer();
  }
  
  /// Public method to force stop monitoring
  void forceStopMonitoring() {
    _forceStopped = true; // Set force stop flag
    _globallyStopped = true; // Set global flag to prevent any restart
    _isMonitoring = false;
    _timersStopped = true; // Also set timers stopped flag
    
    // Use aggressive timer stopping
    _forceStopProgressTimer();
    
    // Clear all callbacks to prevent further updates
    onDistanceUpdate = null;
    onTimeUpdate = null;
    onPaceUpdate = null;
    onProgressUpdate = null;
    onRouteUpdate = null;
    
    // Reset all state
    _resetState();
    
    print('🛑 ProgressMonitorService: _isMonitoring forced to false');
    print('🛑 ProgressMonitorService: _globallyStopped set to true');
    print('🛑 ProgressMonitorService: _timersStopped set to true');
    print('🛑 ProgressMonitorService: _forceStopped set to true');
    print('🛑 ProgressMonitorService: All callbacks cleared and state reset');
  }
  
  /// Nuclear option: completely kill all timers
  void nuclearStop() {
    _forceStopped = true;
    _globallyStopped = true;
    _isMonitoring = false;
    _timersStopped = true;
    
    // Cancel any existing timer
    if (_progressTimer != null) {
      _progressTimer!.cancel();
      _progressTimer = null;
    }
    
    // Clear all callbacks
    onDistanceUpdate = null;
    onTimeUpdate = null;
    onPaceUpdate = null;
    onProgressUpdate = null;
    onRouteUpdate = null;
    
    // Reset state
    _resetState();
    
    print('☢️ ProgressMonitorService: NUCLEAR STOP - All timers killed');
  }

  /// Handle position updates
  void _onPositionUpdate(Position position) {
    if (kDebugMode) {
      print('📍 ProgressMonitorService: GPS position received: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
    }
    
    if (!_isMonitoring || _lastPosition == null) {
      _lastPosition = position;
      _route.add(position);
      if (kDebugMode) {
        print('📍 ProgressMonitorService: First GPS position added to route');
      }
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
      final timeDiff = position.timestamp.difference(_lastPosition!.timestamp);
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
    
    // Update last position and route
    _lastPosition = position;
    _route.add(position);
    
    if (kDebugMode) {
      print('📍 ProgressMonitorService: Position added to route. Total points: ${_route.length}');
    }
    
    // Notify listeners
    onDistanceUpdate?.call(_currentDistance);
    onPaceUpdate?.call(_currentPace);
    onRouteUpdate?.call(_route);
  }

  /// Update elapsed time
  void _updateElapsedTime() {
    // Don't update if monitoring is stopped
    if (!_isMonitoring || _globallyStopped || _timersStopped || _forceStopped) {
      if (kDebugMode) {
        print('🛑 _updateElapsedTime: Skipping update - monitoring stopped');
        print('🛑 _isMonitoring=$_isMonitoring, _globallyStopped=$_globallyStopped, _timersStopped=$_timersStopped, _forceStopped=$_forceStopped');
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
    if (!_isMonitoring || _globallyStopped || _timersStopped || _forceStopped) {
      if (kDebugMode) {
        print('🛑 _updateProgress: Skipping update - monitoring stopped');
        print('🛑 _isMonitoring=$_isMonitoring, _globallyStopped=$_globallyStopped, _timersStopped=$_timersStopped, _forceStopped=$_forceStopped');
      }
      return;
    }
    
    final progress = _calculateProgress();
    onProgressUpdate?.call(progress);
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

  /// Reset the service state
  void _resetState() {
    _currentDistance = 0.0;
    _elapsedTime = Duration.zero;
    _currentPace = 0.0;
    _averagePace = 0.0;
    _maxPace = 0.0;
    _minPace = double.infinity;
    _route.clear();
    _lastPosition = null;
    _startTime = null;
    _pauseTime = null;
    _totalPausedTime = Duration.zero;
  }

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
  bool get isStopped => _globallyStopped || _timersStopped;

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

  /// Dispose resources
  void dispose() {
    stop();
  }
}

double _cosApprox(double x) {
  final x2 = x * x;
  final x4 = x2 * x2;
  final x6 = x4 * x2;
  return 1 - (x2 / 2) + (x4 / 24) - (x6 / 720);
}
