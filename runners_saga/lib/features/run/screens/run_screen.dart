import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/providers/firebase_providers.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/providers/story_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/providers/run_config_providers.dart';
import '../../../shared/models/run_enums.dart';
import '../../../shared/models/run_target_model.dart';
import '../../../shared/models/run_model.dart';

import '../../../shared/providers/audio_providers.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/settings/settings_service.dart';
import '../../../shared/services/story/scene_trigger_service.dart';
import '../../../shared/services/run/run_session_manager.dart';
import '../../../shared/services/background_service_manager.dart';


import '../../../shared/models/episode_model.dart';
import '../../../core/constants/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../widgets/run_map_panel.dart';
import '../widgets/scene_hud.dart';
import '../widgets/scene_progress_indicator.dart';
import '../../../shared/widgets/ui/skeleton_loader.dart';
import '../../../shared/services/firebase/firestore_service.dart';
import '../../../shared/services/run/run_completion_service.dart';
import '../../../shared/services/local/local_run_storage_service.dart';
import '../../../shared/services/local/local_to_firebase_upload_service.dart';
import '../../../shared/services/local/background_upload_service.dart';
import '../../../shared/providers/run_completion_providers.dart';
import '../../../shared/models/run_model.dart';
import '../../../shared/services/background_service_manager.dart';
import '../../../shared/services/background_timer_manager.dart';






class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> with WidgetsBindingObserver {
  bool _isInitializing = true;
  bool _timerStopped = false; // Flag to prevent timer restart
  bool _disposed = false; // Flag to prevent state updates after disposal
  
  // Simple, controllable timer
  Timer? _simpleTimer;
  bool _isTimerRunning = false;
  bool _isPaused = false;
  Duration _elapsedTime = Duration.zero;
  Duration _pausedTime = Duration.zero; // Time when paused
  DateTime? _startTime;
  Duration _totalPausedTime = Duration.zero;
  
  // GPS tracking for real distance calculation
  List<Position> _gpsRoute = [];
  double _totalDistance = 0.0;
  
  // SIMPLE GPS SAVING - Direct approach that won't get cleared
  List<Map<String, dynamic>> _simpleGpsData = [];
  StreamSubscription<Position>? _gpsSubscription;
  Position? _lastGpsPosition;
  
  // GPS signal loss handling
  DateTime? _lastGpsUpdate;
  bool _isGpsSignalLost = false;
  Duration _gpsSignalLossDuration = Duration.zero;
  double _estimatedDistanceDuringSignalLoss = 0.0;
  double _averagePaceBeforeSignalLoss = 0.0; // km/h
  Timer? _gpsSignalLossTimer;
  
  // Real-time pace and speed calculation
  List<Position> _recentGpsPoints = []; // Last 30 seconds of GPS data
  double _currentPace = 0.0; // Current pace in min/km
  double _currentSpeed = 0.0; // Current speed in km/h
  double _previousPace = 0.0; // Previous pace for trend analysis
  String _paceTrend = 'steady'; // 'improving', 'declining', 'steady'
  Timer? _paceCalculationTimer;
  
  // Error handling and user feedback
  bool _isLoading = false;
  String? _currentErrorMessage;
  bool _showErrorToast = false;
  Timer? _errorToastTimer;
  bool _isNetworkAvailable = true;
  Timer? _networkCheckTimer;
  
  @override
  void initState() {
    super.initState();
    _isInitializing = true;
    
    // Start the run session automatically when screen loads
    // User already selected "Start Run" on home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRun();
    });
    
    // Listen for app lifecycle changes to handle background processing
    WidgetsBinding.instance.addObserver(this);
  }
  
  /// Get episode ID from query parameters
  String? _getEpisodeIdFromQuery() {
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    return uri.queryParameters['episodeId'];
  }
  

  
  @override
  void dispose() {
    try {
      // Use comprehensive cleanup
      _stopAllTimersAndServices();
      
      // Remove lifecycle observer
      WidgetsBinding.instance.removeObserver(this);
      
    } catch (e) {
      // Log error but don't let it prevent disposal
    } finally {
      super.dispose();
    }
  }
  
  // App lifecycle management for background processing
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }
  
  /// Handle app resumed (brought to foreground)
  void _onAppResumed() {
    if (_disposed) return;
    
    
    // Ensure GPS tracking is still active
    if (_isTimerRunning && !_isPaused && _gpsSubscription == null) {
      _startGpsTracking();
    }
    
    // Update UI to reflect current state
    if (mounted) {
      setState(() {});
    }
  }
  
  /// Handle app inactive (transitioning between states)
  void _onAppInactive() {
    if (_disposed) return;
    
    // Keep everything running during transitions
  }
  
  /// Handle app paused (minimized/background)
  void _onAppPaused() {
    if (_disposed) return;
    
    
    // Start background service if available
    if (_isTimerRunning && !_isPaused) {
      _startBackgroundService();
    }
    
    // Keep timers and GPS running - they will continue in background
    // The existing Timer.periodic calls will keep working
  }
  
  /// Handle app detached (about to be terminated)
  void _onAppDetached() {
    if (_disposed) return;
    
    
    // Save current run state to persistent storage
    if (_isTimerRunning) {
      _saveRunStateForBackground();
    }
  }
  
  /// Handle app hidden (Android specific)
  void _onAppHidden() {
    if (_disposed) return;
    
    // Similar to paused - keep everything running
  }
  
  /// Start background service for enhanced background processing
  void _startBackgroundService() async {
    try {
      if (!_isTimerRunning || _isPaused) return;
      
      // Get current episode info for background service
      final currentEpisode = ref.read(currentEpisodeProvider);
      if (currentEpisode == null) return;
      
      final success = await BackgroundServiceManager.instance.startBackgroundService(
        runId: DateTime.now().millisecondsSinceEpoch.toString(),
        episodeTitle: currentEpisode.title,
        targetTime: Duration(milliseconds: currentEpisode.targetTime),
        targetDistance: currentEpisode.targetDistance,
      );
      
      if (success) {
      } else {
      }
    } catch (e) {
    }
  }
  
  /// Save run state for background processing
  void _saveRunStateForBackground() {
    // This will be handled by the existing timer and GPS tracking
    // The Timer.periodic calls will continue running in background
  }
  
  /// Start GPS tracking for real distance calculation
  void _startGpsTracking() async {
    try {
      
      // Get initial position
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      // Store initial position
      _lastGpsPosition = initialPosition;
      _gpsRoute.add(initialPosition);
      
      // SIMPLE GPS SAVING - Add initial position to _simpleGpsData
      _simpleGpsData.add({
        'latitude': initialPosition.latitude,
        'longitude': initialPosition.longitude,
        'accuracy': initialPosition.accuracy,
        'altitude': initialPosition.altitude,
        'speed': initialPosition.speed,
        'heading': initialPosition.heading,
        'timestamp': initialPosition.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'elapsedSeconds': _elapsedTime.inSeconds,
      });
      
      _totalDistance = 0.0;
      
      
      // Start continuous GPS tracking with background-friendly settings
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters
          timeLimit: Duration(seconds: 30), // Allow longer timeouts for background
        ),
      ).listen(
        (position) {
          _onGpsPositionUpdate(position);
        },
        onError: (error) {
          // Don't cancel the subscription on error - let it retry
        },
        cancelOnError: false, // Keep GPS tracking alive even on errors
      );
      
      
    } catch (e) {
    }
  }
  
  /// Start GPS signal loss detection
  void _startGpsSignalLossDetection() {
    // Cancel any existing timer
    _gpsSignalLossTimer?.cancel();
    
    // Check for GPS signal loss every 5 seconds
    _gpsSignalLossTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_disposed || !_isTimerRunning || _isPaused) {
        timer.cancel();
        return;
      }
      
      _checkGpsSignalLoss();
    });
    
  }
  
  /// Check if GPS signal has been lost
  void _checkGpsSignalLoss() {
    if (_lastGpsUpdate == null) return;
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastGpsUpdate!);
    final signalLossThreshold = const Duration(seconds: 15); // Consider signal lost after 15 seconds
    
    if (timeSinceLastUpdate > signalLossThreshold && !_isGpsSignalLost) {
      _handleGpsSignalLoss();
    }
  }
  
  /// Handle GPS signal loss
  void _handleGpsSignalLoss() {
    _isGpsSignalLost = true;
    _gpsSignalLossDuration = Duration.zero;
    _estimatedDistanceDuringSignalLoss = 0.0;
    
    // Calculate average pace before signal loss (if we have enough data)
    if (_gpsRoute.length > 1 && _elapsedTime.inSeconds > 0) {
      _averagePaceBeforeSignalLoss = _totalDistance / (_elapsedTime.inHours);
    }
    
    
    // Start estimating distance during signal loss
    _startDistanceEstimationDuringSignalLoss();
    
    // Update UI to show signal loss status
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  /// Start estimating distance during GPS signal loss
  void _startDistanceEstimationDuringSignalLoss() {
    // Cancel any existing timer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || !_isTimerRunning || _isPaused || !_isGpsSignalLost) {
        timer.cancel();
        return;
      }
      
      // Update signal loss duration
      _gpsSignalLossDuration += const Duration(seconds: 1);
      
              // Estimate distance based on average pace
        if (_averagePaceBeforeSignalLoss > 0) {
          final estimatedDistance = _averagePaceBeforeSignalLoss * (_gpsSignalLossDuration.inHours);
          _estimatedDistanceDuringSignalLoss = estimatedDistance;
          
          // Update total distance with estimated distance (but don't add to GPS route)
          // We need to calculate the total as: original_distance + new_estimated_distance
          final originalDistance = _totalDistance - _estimatedDistanceDuringSignalLoss;
          _totalDistance = originalDistance + estimatedDistance;
          
          
          // Update UI
          if (mounted && !_disposed) {
            setState(() {});
          }
        }
    });
  }
  
  
  /// Start real-time pace calculation
  void _startPaceCalculation() {
    // Cancel any existing timer
    _paceCalculationTimer?.cancel();
    
    // Calculate pace every 5 seconds for real-time updates
    _paceCalculationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_disposed || !_isTimerRunning || _isPaused) {
        timer.cancel();
        return;
      }
      
      _calculateCurrentPace();
    });
    
  }
  
  /// Calculate current pace based on recent GPS data
  void _calculateCurrentPace() {
    if (_gpsRoute.length < 2) return;
    
    // Keep only GPS points from last 30 seconds
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 30));
    _recentGpsPoints = _gpsRoute.where((position) => 
      position.timestamp != null && 
      position.timestamp!.isAfter(cutoffTime)
    ).toList();
    
    if (_recentGpsPoints.length < 2) return;
    
    // Calculate total distance and time for recent points
    double recentDistance = 0.0;
    Duration recentTime = Duration.zero;
    
    for (int i = 1; i < _recentGpsPoints.length; i++) {
      final prev = _recentGpsPoints[i - 1];
      final curr = _recentGpsPoints[i];
      
      // Calculate distance between consecutive points
      final distance = Geolocator.distanceBetween(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      ) / 1000; // Convert to kilometers
      
      recentDistance += distance;
      
      // Calculate time difference
      if (prev.timestamp != null && curr.timestamp != null) {
        final timeDiff = curr.timestamp!.difference(prev.timestamp!);
        recentTime += timeDiff;
      }
    }
    
    // Calculate current pace and speed
    if (recentDistance > 0 && recentTime.inSeconds > 0) {
      _previousPace = _currentPace;
      
      // Current pace in min/km
      _currentPace = (recentTime.inMinutes / recentDistance);
      
      // Current speed in km/h
      _currentSpeed = (recentDistance / recentTime.inHours);
      
      // Analyze pace trend
      _analyzePaceTrend();
      
      
      // Update UI
      if (mounted && !_disposed) {
        setState(() {});
      }
    }
  }
  
  /// Analyze pace trend based on current vs previous pace
  void _analyzePaceTrend() {
    if (_previousPace == 0.0) {
      _paceTrend = 'steady';
      return;
    }
    
    final paceDifference = _currentPace - _previousPace;
    final threshold = 0.1; // 0.1 min/km threshold for trend detection
    
    if (paceDifference < -threshold) {
      _paceTrend = 'improving'; // Getting faster (lower pace)
    } else if (paceDifference > threshold) {
      _paceTrend = 'declining'; // Getting slower (higher pace)
    } else {
      _paceTrend = 'steady';
    }
  }
  
  /// Get pace zone based on current pace
  String _getPaceZone(double pace) {
    if (pace <= 4.0) return 'very_hard';
    if (pace <= 5.0) return 'hard';
    if (pace <= 6.0) return 'moderate';
    if (pace <= 7.0) return 'easy';
    return 'very_easy';
  }
  
  /// Get pace zone color
  Color _getPaceZoneColor(String zone) {
    switch (zone) {
      case 'very_hard':
        return Colors.red;
      case 'hard':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow.shade700;
      case 'easy':
        return Colors.green;
      case 'very_easy':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  /// Get pace zone description
  String _getPaceZoneDescription(String zone) {
    switch (zone) {
      case 'very_hard':
        return 'Very Hard';
      case 'hard':
        return 'Hard';
      case 'moderate':
        return 'Moderate';
      case 'easy':
        return 'Easy';
      case 'very_easy':
        return 'Very Easy';
      default:
        return 'Unknown';
    }
  }
  
  /// Build current pace display with trend indicator
  Widget _buildCurrentPaceDisplay() {
    if (_currentPace == 0.0) {
      return const Text('--:--', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    }
    
    final paceZone = _getPaceZone(_currentPace);
    final zoneColor = _getPaceZoneColor(paceZone);
    
    return FutureBuilder<String>(
      future: _formatPaceWithUnits(_currentPace),
      builder: (context, snapshot) {
        return Column(
          children: [
            Text(
              snapshot.data ?? '${_currentPace.toStringAsFixed(1)} min/km',
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: zoneColor,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPaceTrendIcon(),
                  size: 12,
                  color: _getPaceTrendColor(),
                ),
                const SizedBox(width: 4),
                Text(
                  _getPaceZoneDescription(paceZone),
                  style: TextStyle(
                    fontSize: 10,
                    color: zoneColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  
  /// Get pace trend icon
  IconData _getPaceTrendIcon() {
    switch (_paceTrend) {
      case 'improving':
        return Icons.trending_down; // Down arrow = getting faster
      case 'declining':
        return Icons.trending_up; // Up arrow = getting slower
      case 'steady':
      default:
        return Icons.remove; // Horizontal line = steady
    }
  }
  
  /// Get pace trend color
  Color _getPaceTrendColor() {
    switch (_paceTrend) {
      case 'improving':
        return Colors.green;
      case 'declining':
        return Colors.red;
      case 'steady':
      default:
        return Colors.grey;
    }
  }
  
  /// Build pace zone indicator
  Widget _buildPaceZoneIndicator() {
    if (!_isTimerRunning || _currentPace == 0.0) return const SizedBox.shrink();
    
    final paceZone = _getPaceZone(_currentPace);
    final zoneColor = _getPaceZoneColor(paceZone);
    final zoneDescription = _getPaceZoneDescription(paceZone);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: zoneColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: zoneColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getPaceZoneIcon(paceZone),
            color: zoneColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Effort Level',
                  style: TextStyle(
                    color: zoneColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  zoneDescription,
                  style: TextStyle(
                    color: zoneColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: zoneColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPace.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Get pace zone icon
  IconData _getPaceZoneIcon(String zone) {
    switch (zone) {
      case 'very_hard':
        return Icons.fitness_center;
      case 'hard':
        return Icons.directions_run;
      case 'moderate':
        return Icons.directions_walk;
      case 'easy':
        return Icons.emoji_emotions;
      case 'very_easy':
        return Icons.airline_seat_flat;
      default:
        return Icons.help_outline;
    }
  }
  
  /// Start network availability monitoring
  void _startNetworkMonitoring() {
    _networkCheckTimer?.cancel();
    
    // Check network every 10 seconds
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      
      _checkNetworkAvailability();
    });
    
  }
  
  /// Check network availability
  void _checkNetworkAvailability() async {
    try {
      // Simple network check - try to access a reliable endpoint
      final result = await InternetAddress.lookup('google.com');
      final wasNetworkAvailable = _isNetworkAvailable;
      _isNetworkAvailable = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      
      // If network status changed, update UI
      if (wasNetworkAvailable != _isNetworkAvailable) {
        if (mounted && !_disposed) {
          setState(() {});
        }
        
        if (!_isNetworkAvailable) {
          _showToast('Network connection lost. Some features may be limited.', isError: true);
        } else {
          _showToast('Network connection restored!', isError: false);
        }
      }
    } catch (e) {
      final wasNetworkAvailable = _isNetworkAvailable;
      _isNetworkAvailable = false;
      
      if (wasNetworkAvailable && mounted && !_disposed) {
        setState(() {});
        _showToast('Network connection lost. Some features may be limited.', isError: true);
      }
    }
  }
  
  /// Show toast notification
  void _showToast(String message, {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    _currentErrorMessage = message;
    _showErrorToast = true;
    
    // Auto-hide toast after duration
    _errorToastTimer?.cancel();
    _errorToastTimer = Timer(duration, () {
      if (mounted && !_disposed) {
        setState(() {
          _showErrorToast = false;
          _currentErrorMessage = null;
        });
      }
    });
    
    // Update UI immediately
    if (mounted && !_disposed) {
      setState(() {});
    }
    
  }
  
  
  
  
  /// Handle GPS position updates and calculate distance
  void _onGpsPositionUpdate(Position position) {
    print('📍 RunScreen: GPS position update received: (${position.latitude}, ${position.longitude})');
    
    if (_lastGpsPosition != null) {
      // Calculate distance from last position
      final distance = Geolocator.distanceBetween(
        _lastGpsPosition!.latitude,
        _lastGpsPosition!.longitude,
        position.latitude,
        position.longitude,
      ) / 1000; // Convert to kilometers
      
      // Add to total distance
      _totalDistance += distance;
      
    }
    
    // Store the new position
    _lastGpsPosition = position;
    _gpsRoute.add(position);
    
    // SIMPLE GPS SAVING - Also store in simple format that won't get cleared
    _simpleGpsData.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'heading': position.heading,
      'timestamp': position.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'elapsedSeconds': _elapsedTime.inSeconds,
    });
    
    

    
    // Update UI if mounted
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  /// Start a simple, controllable timer
  void _startSimpleTimer() async {
    
    // Initialize start time if not already set
    if (_startTime == null) {
      _startTime = DateTime.now();
    }
    
    // Start the actual simple timer
    _simpleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isTimerRunning || _isPaused) {
        timer.cancel();
        _simpleTimer = null;
        return;
      }
      
      // Update elapsed time
      if (_startTime != null) {
        _elapsedTime = DateTime.now().difference(_startTime!) - _totalPausedTime;
        _updateElapsedTime();
      }
    });
    
    // Start GPS tracking for real distance calculation
    _startGpsTracking();
    
    // Start GPS signal loss detection
    _startGpsSignalLossDetection();
    
    // Start real-time pace calculation
    _startPaceCalculation();
    
    // Start network monitoring
    _startNetworkMonitoring();
    
    // Audio will be handled by the background session (SceneTriggerService)
    
    // Set timer state for UI
    _isTimerRunning = true;
    _isPaused = false;
    
    // Start listening to elapsed time updates from ProgressMonitorService
    _startListeningToServiceUpdates();
    
  }
  
  /// Start listening to updates from ProgressMonitorService
  void _startListeningToServiceUpdates() {
    // Get the run session manager to access ProgressMonitorService
    final runSessionManager = ref.read(runSessionControllerProvider.notifier);
    
    // Listen for time updates from the service
    // This will be called every second by ProgressMonitorService
    runSessionManager.onTimeUpdated = (Duration elapsedTime) {
      if (_disposed) return;
      
      _elapsedTime = elapsedTime;
      
      // Update UI if mounted
      if (mounted) {
        setState(() {});
      }
    };
    
  }
  
  
  /// Pause the simple timer
  void _pauseSimpleTimer() async {
    if (_isTimerRunning && !_isPaused) {
      _isPaused = true;
      _pausedTime = _elapsedTime; // Store current time
      
      if (_simpleTimer != null) {
        _simpleTimer!.cancel();
        _simpleTimer = null;
      }
      
      // Pause audio when pausing timer
      try {
        // Pause the background session (this will pause the scene trigger audio)
        ref.read(runSessionControllerProvider.notifier).pauseSession();
        
        // Also directly pause all audio from our audio manager
        final audioManager = ref.read(audioManagerProvider);
        await audioManager.pauseAll();
        
      } catch (e) {
      }
      
      if (mounted && !_disposed) {
        setState(() {});
      }
    }
  }
  
  /// Stop the simple timer completely
  void _stopSimpleTimer() {
    _isTimerRunning = false;
    _isPaused = false;
    _pausedTime = Duration.zero; // Reset paused time
    
    if (_simpleTimer != null) {
      _simpleTimer!.cancel();
      _simpleTimer = null;
    }
    
    // Clear the callback to prevent further updates from ProgressMonitorService
    _clearServiceCallbacks();
    
    // Only call setState if the widget is still mounted and not disposed
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  /// Stop ALL timers and services - comprehensive cleanup for hot reload
  void _stopAllTimersAndServices() {
    print('🛑 RunScreen: Starting comprehensive timer cleanup...');
    
    // Set all flags to stop state IMMEDIATELY
    _disposed = true;
    _isTimerRunning = false;
    _isPaused = false;
    _timerStopped = true;
    
    // Stop all defined timers
    if (_simpleTimer != null) {
      _simpleTimer!.cancel();
      _simpleTimer = null;
      print('🛑 RunScreen: _simpleTimer stopped');
    }
    
    if (_gpsSignalLossTimer != null) {
      _gpsSignalLossTimer!.cancel();
      _gpsSignalLossTimer = null;
      print('🛑 RunScreen: _gpsSignalLossTimer stopped');
    }
    
    if (_paceCalculationTimer != null) {
      _paceCalculationTimer!.cancel();
      _paceCalculationTimer = null;
      print('🛑 RunScreen: _paceCalculationTimer stopped');
    }
    
    if (_errorToastTimer != null) {
      _errorToastTimer!.cancel();
      _errorToastTimer = null;
      print('🛑 RunScreen: _errorToastTimer stopped');
    }
    
    if (_networkCheckTimer != null) {
      _networkCheckTimer!.cancel();
      _networkCheckTimer = null;
      print('🛑 RunScreen: _networkCheckTimer stopped');
    }
    
    // Stop GPS tracking
    if (_gpsSubscription != null) {
      _gpsSubscription!.cancel();
      _gpsSubscription = null;
      print('🛑 RunScreen: GPS subscription stopped');
    }
    
    // Clear service callbacks
    _clearServiceCallbacks();
    
    print('🛑 RunScreen: All timers and services stopped successfully');
  }

  /// Test method to verify all timers are stopped (for debugging hot reload)
  void testTimerCleanup() {
    print('🧪 RunScreen: Testing timer cleanup...');
    print('🧪 _simpleTimer: ${_simpleTimer == null ? "STOPPED" : "RUNNING"}');
    print('🧪 _gpsSignalLossTimer: ${_gpsSignalLossTimer == null ? "STOPPED" : "RUNNING"}');
    print('🧪 _paceCalculationTimer: ${_paceCalculationTimer == null ? "STOPPED" : "RUNNING"}');
    print('🧪 _errorToastTimer: ${_errorToastTimer == null ? "STOPPED" : "RUNNING"}');
    print('🧪 _networkCheckTimer: ${_networkCheckTimer == null ? "STOPPED" : "RUNNING"}');
    print('🧪 _gpsSubscription: ${_gpsSubscription == null ? "STOPPED" : "RUNNING"}');
    print('🧪 _isTimerRunning: $_isTimerRunning');
    print('🧪 _disposed: $_disposed');
    print('🧪 _timerStopped: $_timerStopped');
  }
  
  /// Update elapsed time
  void _updateElapsedTime() {
    if (_startTime != null) {
      _elapsedTime = DateTime.now().difference(_startTime!) - _totalPausedTime;
    }
  }


  /// Clear all callbacks to prevent further updates from services
  void _clearServiceCallbacks() {
    try {
      // Check if widget is disposed or not mounted before accessing ref
      if (_disposed || !mounted) {
        return;
      }
      
      final runSessionController = ref.read(runSessionControllerProvider.notifier);
      
      // Clear the onTimeUpdated callback through the controller's setter
      runSessionController.onTimeUpdated = null;
      
      // Force stop all services to prevent them from continuing to run
      runSessionController.nuclearStop();
      
    } catch (e) {
    }
  }
  
  // Note: _saveRunCompletion method removed to prevent duplicate run saving
  // Run completion is now handled by RunCompletionService
  
  
  
  String _getTimerDisplayText() {
    if (_isPaused) return 'Timer Paused';
    return 'Simple Timer';
  }
  
  IconData _getTimerDisplayIcon() {
    if (_timerStopped) return Icons.timer_off;
    if (_isPaused) return Icons.pause_circle;
    return Icons.timer;
  }
  
  /// Build the control buttons based on timer state
  Widget _buildControlButtons() {
    if (_isPaused) {
      // Timer paused - show resume and finish buttons
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: _resumeTimer,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _finishRun,
            icon: const Icon(Icons.flag),
            label: const Text('Finish Run'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kElectricAqua,
              foregroundColor: kMidnightNavy,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      );
    } else {
      // Timer running - show pause and finish buttons
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pauseTimer,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                print('🚨 BUTTON CLICKED: Finish Run button pressed!');
                _finishRun();
              },
              icon: const Icon(Icons.flag),
              label: const Text('Finish Run'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kElectricAqua,
                foregroundColor: kMidnightNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
        ],
      );
    }
  }
  
  /// REAL GPS TRACKING with accurate distance calculation
  

  /// Calculate calories burned based on distance and time
  int _calculateCalories(double distance, Duration time) {
    // Simple calorie calculation based on MET values
    final minutes = time.inSeconds / 60.0;
    if (minutes <= 0) return 0;
    
    // Assume average weight of 70kg for calculation
    final weightKg = 70.0;
    
    // Calculate pace (min/km) and speed (km/h)
    final pace = distance > 0 ? minutes / distance : 0.0;
    final speedKmh = pace > 0 ? 60.0 / pace : 9.0;
    
    // Determine MET value based on speed
    double met;
    if (speedKmh < 6) met = 6.0;      // Walking
    else if (speedKmh < 8) met = 8.3;  // Jogging
    else if (speedKmh < 9.7) met = 9.8; // Running
    else if (speedKmh < 11.3) met = 11.0; // Fast running
    else met = 12.8;                   // Sprinting
    
    // Calculate calories: MET * 3.5 * weight(kg) / 200 * time(minutes)
    final kcal = met * 3.5 * weightKg / 200.0 * minutes;
    return kcal.round();
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Location Services (GPS)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await Geolocator.openLocationSettings();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Open Settings to grant access.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await Geolocator.openAppSettings();
        return false;
      }

      final hasPermission =
          permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  void _startRun() async {
    // Ensure GPS permission and service availability
    final permitted = await _ensureLocationPermission();
    if (!permitted) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Don't start if timer was explicitly stopped
    if (_timerStopped) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Don't start if there's already an active session
    final isSessionActive = ref.read(runSessionControllerProvider.notifier).isSessionActive;
    if (isSessionActive) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Debug: Check what target data is available
    final userRunTarget = ref.read(userRunTargetProvider);
    
    if (userRunTarget != null) {
      if (userRunTarget.targetDistance > 0) {
      } else if (userRunTarget.targetTime.inMinutes > 0) {
      }
    } else {
    }
    
    // Get episode ID from query parameters and load episode data
    final episodeId = _getEpisodeIdFromQuery();
    
    EpisodeModel? currentEpisode;
    if (episodeId != null) {
      // Load episode data directly from the story service
      try {
        final episodeAsync = ref.read(episodeByIdProvider(episodeId));
        episodeAsync.whenData((episode) {
          if (episode != null) {
            currentEpisode = episode;
          }
        });
      } catch (e) {
      }
    }
    
    // If no episode loaded, create a fallback episode with audio files
    if (currentEpisode == null) {
      currentEpisode = EpisodeModel(
        id: 'S01E01',
        seasonId: 'S01',
        title: 'Fallback Episode',
        description: 'Fallback episode for testing',
        status: 'unlocked',
        order: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        objective: 'Complete your run',
        targetDistance: 5.0,
        targetTime: 1800000, // 30 minutes
        audioFiles: [
          // Audio files should come from episode data, not hardcoded
        ],
        requirements: {},
        rewards: {},
      );
    }
    
    try {
      // Get the user's selected run target from the provider
      // User selects either distance OR time, not both
      Duration? targetTime;
      double? targetDistance;
      
      if (userRunTarget != null) {
        // User selected a target - use their selection
        if (userRunTarget.targetDistance > 0) {
          // User selected distance target
          targetDistance = userRunTarget.targetDistance;
          targetTime = null; // No time target - user only selected distance
        } else if (userRunTarget.targetTime.inMinutes > 0) {
          // User selected time target
          targetTime = userRunTarget.targetTime;
          targetDistance = null; // No distance target - user only selected time
        } else {
        }
      }
      // No fallback to database - only show user selection
      
      
      // Only start if user has selected a target AND timer wasn't stopped
      if ((targetTime != null || targetDistance != null) && !_timerStopped) {
        // Check if the run session manager can start a session
        final canStart = ref.read(runSessionControllerProvider.notifier).canStartSession();
        if (canStart) {
          final trackingMode = ref.read(trackingModeProvider);
          // Force debug logging for testing
          
          
          // Set up time update callback BEFORE starting the session
          // This ensures we don't miss any time updates
          _startListeningToServiceUpdates();
          
          await ref.read(runSessionControllerProvider.notifier).startSession(
            currentEpisode!,
            userTargetTime: targetTime ?? const Duration(minutes: 30),
            userTargetDistance: targetDistance ?? 5.0,
            trackingMode: trackingMode ?? TrackingMode.gps,
          );
          
          // Hook route updates to force map refresh via provider changes
          ref.read(runSessionControllerProvider.notifier).state.onRouteUpdated = (route) {
            setState(() {});
          };
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot start session - please try again'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (_timerStopped) {
      } else {
      }
      
      setState(() {
        _isInitializing = false;
      });
      
      // Note: Timer callback is now set up before starting the session
      // No need to call _startSimpleTimer() here
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting run: $e')),
        );
      }
    }
  }
  

  
  void _pauseTimer() {
    
    try {
      // Pause our simple timer first (this we can control)
      _pauseSimpleTimer();
      
      // Also pause the background session
      ref.read(runSessionControllerProvider.notifier).pauseSession();
      
      // Update UI to show timer is paused
      setState(() {});
      
      // Show confirmation to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timer paused'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pausing timer: $e'),
          ),
        );
      }
    }
  }
  
  // Method to resume timer from pause
  void _resumeTimer() async {
    
    // Resume the background session and audio
    try {
      // Resume the background session (this will resume the scene trigger audio)
      ref.read(runSessionControllerProvider.notifier).resumeSession();
      
      // Also directly resume all audio from our audio manager
      final audioManager = ref.read(audioManagerProvider);
      await audioManager.resumeAll();
      
    } catch (e) {
    }
    
    // Resume the timer state and restart the simple timer
    _isPaused = false;
    _isTimerRunning = true;
    
    // Restart the simple timer
    _startSimpleTimer();
    
    // Restart listening to service updates
    _startListeningToServiceUpdates();
    
    setState(() {
      _isInitializing = false;
    });
    
  }
  
  // _resetTimer method removed - unnecessary complexity

  @override
  Widget build(BuildContext context) {
    final currentEpisode = ref.watch(currentEpisodeProvider);

    // Show loading screen while initializing
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: kMidnightNavy,
        appBar: AppBar(
          title: const Text('Starting Run', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header skeleton
                SkeletonLoader(height: 32, width: 200, margin: const EdgeInsets.only(bottom: 16)),
                SkeletonLoader(height: 16, width: 150, margin: const EdgeInsets.only(bottom: 32)),
                
                // Stats skeleton
                Row(
                  children: [
                    Expanded(
                      child: SkeletonCard(
                        height: 100,
                        children: [
                          SkeletonLoader(height: 24, width: 60, margin: const EdgeInsets.only(bottom: 8)),
                          SkeletonLoader(height: 32, width: 80, margin: const EdgeInsets.only(bottom: 4)),
                          SkeletonLoader(height: 14, width: 100),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SkeletonCard(
                        height: 100,
                        children: [
                          SkeletonLoader(height: 24, width: 60, margin: const EdgeInsets.only(bottom: 8)),
                          SkeletonLoader(height: 32, width: 80, margin: const EdgeInsets.only(bottom: 4)),
                          SkeletonLoader(height: 14, width: 100),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Map skeleton
                SkeletonCard(
                  height: 200,
                  children: [
                    SkeletonLoader(height: 20, width: 120, margin: const EdgeInsets.only(bottom: 16)),
                    SkeletonLoader(height: 140, width: double.infinity),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Scene skeleton
                SkeletonCard(
                  height: 80,
                  children: [
                    SkeletonLoader(height: 16, width: 100, margin: const EdgeInsets.only(bottom: 8)),
                    SkeletonLoader(height: 20, width: 150, margin: const EdgeInsets.only(bottom: 8)),
                    Row(
                      children: [
                        SkeletonLoader(height: 6, width: 6, margin: const EdgeInsets.only(right: 4)),
                        SkeletonLoader(height: 6, width: 6, margin: const EdgeInsets.only(right: 4)),
                        SkeletonLoader(height: 6, width: 6),
                      ],
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Loading indicator
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kElectricAqua),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preparing your adventure...',
                        style: TextStyle(
                          color: kTextHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Compact metrics header (ZRX-style)
            _buildCompactHeader(currentEpisode),

            // Expanded map fills the remaining space
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: RunMapPanel(expanded: true),
              ),
            ),

            // Bottom controls bar
            _buildBottomControlsBar(),
          ],
        ),
      ),
    );
  }

  /// Compact top header with distance/time/pace and subtle progress
  Widget _buildCompactHeader(EpisodeModel? episode) {
    final theme = Theme.of(context);
    final stats = ref.watch(currentRunStatsProvider);
    final progress = ref.watch(currentRunProgressProvider);

    final title = episode?.title ?? 'Your Run';
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withOpacity(0.22),
            surface.withOpacity(0.10),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top row: title + close
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: theme.colorScheme.onSurface,
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Thin progress bar under title
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.dividerColor.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 12),
          // Big distance centered
          FutureBuilder<String>(
            future: _formatDistanceWithUnits(stats?.distance ?? 0.0),
            builder: (context, snapshot) {
              return Column(
                children: [
                  Text(
                    snapshot.data ?? (stats?.distance ?? 0.0).toStringAsFixed(2),
                    style: theme.textTheme.headlineLarge?.copyWith(fontSize: 44),
                  ),
                  Text('Distance', style: theme.textTheme.labelMedium),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Time and pace row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '${_elapsedTime.inMinutes}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Text('Time', style: theme.textTheme.labelMedium),
                ],
              ),
              Column(
                children: [
                  FutureBuilder<String>(
                    future: _formatPaceWithUnits(stats?.averagePace ?? 0.0),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? _formatPace(stats?.averagePace, stats?.distance),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Text('Pace', style: theme.textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom controls styled as a compact sticky bar
  Widget _buildBottomControlsBar() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: _buildControlButtons(),
      ),
    );
  }

  Widget _buildEpisodeStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Build GPS status indicator
  Widget _buildGpsStatusIndicator() {
    if (!_isTimerRunning) return const SizedBox.shrink();
    
    final statusColor = _isGpsSignalLost ? Colors.orange : Colors.green;
    final statusIcon = _isGpsSignalLost ? Icons.gps_off : Icons.gps_fixed;
    final statusText = _isGpsSignalLost 
        ? 'GPS Signal Lost - Estimating Distance'
        : 'GPS Signal Strong';
    
    return Column(
      children: [
        // GPS Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_isGpsSignalLost) ...[
                const SizedBox(width: 8),
                Text(
                  '${_gpsSignalLossDuration.inSeconds}s',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Network Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isNetworkAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isNetworkAvailable ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isNetworkAvailable ? Icons.wifi : Icons.wifi_off,
                color: _isNetworkAvailable ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _isNetworkAvailable ? 'Network Connected' : 'Network Offline',
                style: TextStyle(
                  color: _isNetworkAvailable ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          if (value is String)
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          else if (value is Widget)
            value
          else
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }





  // Format pace defensively when distance is zero to avoid NaN/inf
  String _formatPace(double? paceMinPerKm, double? distanceKm) {
    if ((distanceKm ?? 0) <= 0 || paceMinPerKm == null || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
      return '0.0';
    }
    return paceMinPerKm.toStringAsFixed(1);
  }

  // Format speed in km/h based on distance and time
  String _formatSpeed(double? distanceKm, Duration? elapsedTime) {
    if ((distanceKm ?? 0) <= 0 || elapsedTime == null || elapsedTime.inSeconds <= 0) {
      return '0.0';
    }
    final hours = elapsedTime.inSeconds / 3600.0;
    final speedKmh = distanceKm! / hours;
    return speedKmh.toStringAsFixed(1);
  }

  // Format distance with units using settings service
  Future<String> _formatDistanceWithUnits(double distanceInKm) async {
    final settingsService = SettingsService();
    return await settingsService.formatDistance(distanceInKm);
  }

  // Format speed with units using settings service
  Future<String> _formatSpeedWithUnits(double speedInKmh) async {
    final settingsService = SettingsService();
    return await settingsService.formatSpeed(speedInKmh);
  }

  // Format pace with units using settings service
  Future<String> _formatPaceWithUnits(double paceInMinPerKm) async {
    final settingsService = SettingsService();
    return await settingsService.formatPace(paceInMinPerKm);
  }

  // Format energy with units using settings service
  Future<String> _formatEnergyWithUnits(double energyInKcal) async {
    final settingsService = SettingsService();
    return await settingsService.formatEnergy(energyInKcal);
  }

  void _finishRun() async {
  print('🚨 RunScreen: _finishRun() method called!');

  // Set up loading state for UI
  setState(() {
    _isLoading = true; // You can add a loading indicator to the UI
  });

  // IMMEDIATELY stop all data collection to get the final state
  try {
    _stopAllTimersAndServices();
    ref.read(runSessionControllerProvider.notifier).nuclearStop();
    _clearServiceCallbacks();
  } catch (e) {
    print('❌ RunScreen: Error stopping services: $e');
  }

  try {
    // 1. Get the final, complete GPS data and stats from the session manager
    final runSessionManager = ref.read(runSessionControllerProvider);
    final gpsPositions = runSessionManager.progressMonitor.route;
    final managerStats = ref.read(runSessionControllerProvider.notifier).getCurrentStats();
    
    // Check if there is any data to save
    if (gpsPositions.isEmpty) {
      print('⚠️ RunScreen: No GPS data to save. Navigating to summary.');
      _showToast('No run data to save.', isError: true);
      if (mounted) {
        context.go('/run/summary');
      }
      return;
    }
    
    print('📍 RunScreen: Finalizing run with ${gpsPositions.length} GPS points');
    
    // 2. Use the dedicated RunCompletionService to handle all saving logic
    final runCompletionService = RunCompletionService(ProviderScope.containerOf(context));
    
    // Pass all necessary data to the service
    final summaryData = await runCompletionService.completeRunWithData(
      gpsPositions,
      duration: managerStats?.elapsedTime ?? _elapsedTime,
      distance: managerStats?.distance ?? _totalDistance,
      episodeId: _getEpisodeIdFromQuery() ?? 'unknown',
    );

    // 3. Wait for the service to complete successfully
    if (summaryData != null) {
      print('✅ RunScreen: Run completed successfully and saved!');
      _showToast('Run saved successfully!', isError: false);
      
      // 4. Navigate to the summary screen with the summary data
      if (mounted) {
        // You might want to pass the summary data to the next screen for display
        context.go('/run/summary', extra: summaryData);
      }
    } else {
      // Handle the case where the service returns null, indicating a failure
      print('❌ RunScreen: Run completion failed. Summary data is null.');
      _showToast('Error saving run data. Try again later.', isError: true);
      
      // Navigate to summary anyway, but let the user know something went wrong
      if (mounted) {
        context.go('/run/summary');
      }
    }
    
  } catch (e) {
    print('❌ RunScreen: Unhandled error in _finishRun: $e');
    _showToast('An unexpected error occurred. Data might not be saved.', isError: true);
    
    if (mounted) {
      context.go('/run/summary');
    }
  } finally {
    // Hide the loading indicator
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
}
