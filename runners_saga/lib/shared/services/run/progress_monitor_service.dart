import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

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
  Timer? _gpsBackupTimer;
  
  // Targets
  Duration _targetTime = Duration.zero;
  double _targetDistance = 0.0;
  
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
    Function(double distance)? onDistanceUpdate,
    Function(Duration time)? onTimeUpdate,
    Function(double pace)? onPaceUpdate,
    Function(double progress)? onProgressUpdate,
    Function(List<Position> route)? onRouteUpdate,
  }) {
    _targetTime = targetTime;
    _targetDistance = targetDistance;
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
    
    // Simple check - only start if not already monitoring
    print('🚀 ProgressMonitorService: Starting progress monitor...');
    
    try {
      _startTime = DateTime.now();
      _isMonitoring = true;
      
      if (kDebugMode) {
        print('Progress monitor start time set to: $_startTime');
      }
      
      // Start progress timer immediately (don't wait for location)
      _startProgressTimer();
      
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
      _updateProgress();
      
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
    
    // Update last position
    _lastPosition = position;
    
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
}
