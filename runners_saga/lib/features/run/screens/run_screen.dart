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

import '../../../shared/providers/audio_providers.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/story/scene_trigger_service.dart';
import '../../../shared/services/run/run_session_manager.dart';


import '../../../shared/models/episode_model.dart';
import '../../../core/constants/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import '../widgets/run_map_panel.dart';
import '../widgets/scene_hud.dart';
import '../widgets/scene_progress_indicator.dart';
import '../../../shared/widgets/ui/skeleton_loader.dart';
import '../../../shared/services/firebase/firestore_service.dart';
import '../../../shared/services/run/run_completion_service.dart';
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
  
  // GPS tracking for real distance calculation
  List<Position> _gpsRoute = [];
  double _totalDistance = 0.0;
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
      _disposed = true;
      _stopSimpleTimer();
      
      // Clean up GPS tracking
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
      
      // Clean up GPS signal loss detection
      _gpsSignalLossTimer?.cancel();
      _gpsSignalLossTimer = null;
      
      // Clean up pace calculation timer
      _paceCalculationTimer?.cancel();
      _paceCalculationTimer = null;
      
      // Clean up error handling timers
      _errorToastTimer?.cancel();
      _errorToastTimer = null;
      _networkCheckTimer?.cancel();
      _networkCheckTimer = null;
      
      // Remove lifecycle observer
      WidgetsBinding.instance.removeObserver(this);
      
    } catch (e) {
      // Log error but don't let it prevent disposal
      print('⚠️ RunScreen: Error during dispose: $e');
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
    
    print('📱 RunScreen: App resumed - continuing run tracking');
    
    // Ensure GPS tracking is still active
    if (_isTimerRunning && !_isPaused && _gpsSubscription == null) {
      print('📍 RunScreen: Restarting GPS tracking after resume');
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
    
    print('📱 RunScreen: App inactive - maintaining run state');
    // Keep everything running during transitions
  }
  
  /// Handle app paused (minimized/background)
  void _onAppPaused() {
    if (_disposed) return;
    
    print('📱 RunScreen: App paused - continuing background processing');
    
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
    
    print('📱 RunScreen: App detached - saving run state');
    
    // Save current run state to persistent storage
    if (_isTimerRunning) {
      _saveRunStateForBackground();
    }
  }
  
  /// Handle app hidden (Android specific)
  void _onAppHidden() {
    if (_disposed) return;
    
    print('📱 RunScreen: App hidden - maintaining background processing');
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
        print('✅ RunScreen: Background service started successfully');
      } else {
        print('⚠️ RunScreen: Background service not available (web/unsupported platform)');
      }
    } catch (e) {
      print('❌ RunScreen: Error starting background service: $e');
    }
  }
  
  /// Save run state for background processing
  void _saveRunStateForBackground() {
    // This will be handled by the existing timer and GPS tracking
    // The Timer.periodic calls will continue running in background
    print('💾 RunScreen: Run state preserved for background processing');
  }
  
  /// Start GPS tracking for real distance calculation
  void _startGpsTracking() async {
    try {
      print('📍 RunScreen: Starting GPS tracking for real distance calculation');
      
      // Get initial position
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      // Store initial position
      _lastGpsPosition = initialPosition;
      _gpsRoute.add(initialPosition);
      _totalDistance = 0.0;
      
      print('📍 RunScreen: Initial GPS position captured: (${initialPosition.latitude}, ${initialPosition.longitude})');
      print('📍 RunScreen: GPS route started with 1 point');
      
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
          print('❌ RunScreen: GPS stream error: $error');
          // Don't cancel the subscription on error - let it retry
        },
        cancelOnError: false, // Keep GPS tracking alive even on errors
      );
      
      print('📍 RunScreen: Continuous GPS tracking started - will continue in background');
      
    } catch (e) {
      print('❌ RunScreen: Failed to start GPS tracking: $e');
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
    
    print('🔍 RunScreen: GPS signal loss detection started');
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
    
    print('⚠️ RunScreen: GPS signal lost - Starting distance estimation');
    print('⚠️ RunScreen: Average pace before signal loss: ${_averagePaceBeforeSignalLoss.toStringAsFixed(2)} km/h');
    
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
          
          print('📍 RunScreen: Signal loss - Estimated distance: ${_estimatedDistanceDuringSignalLoss.toStringAsFixed(6)} km');
          print('📍 RunScreen: Signal loss - Total distance (with estimation): ${_totalDistance.toStringAsFixed(6)} km');
          
          // Update UI
          if (mounted && !_disposed) {
            setState(() {});
          }
        }
    });
  }
  
  /// Handle GPS signal recovery
  void _handleGpsSignalRecovery() {
    _isGpsSignalLost = false;
    
    // Calculate actual distance traveled during signal loss
    final actualDistanceTraveled = _estimatedDistanceDuringSignalLoss;
    
    print('✅ RunScreen: GPS signal recovered!');
    print('✅ RunScreen: Estimated distance during signal loss: ${_estimatedDistanceDuringSignalLoss.toStringAsFixed(6)} km');
    print('✅ RunScreen: Signal loss duration: ${_gpsSignalLossDuration.inSeconds} seconds');
    
    // Reset signal loss tracking
    _gpsSignalLossDuration = Duration.zero;
    _estimatedDistanceDuringSignalLoss = 0.0;
    _averagePaceBeforeSignalLoss = 0.0;
    
    // Update UI to show signal recovery
    if (mounted && !_disposed) {
      setState(() {});
    }
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
    
    print('⚡ RunScreen: Real-time pace calculation started');
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
      
      print('⚡ RunScreen: Current pace: ${_currentPace.toStringAsFixed(1)} min/km');
      print('⚡ RunScreen: Current speed: ${_currentSpeed.toStringAsFixed(1)} km/h');
      print('⚡ RunScreen: Pace trend: $_paceTrend');
      
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
    
    return Column(
      children: [
        Text(
          '${_currentPace.toStringAsFixed(1)} min/km',
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
    
    print('🌐 RunScreen: Network monitoring started');
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
    
    print('${isError ? '❌' : 'ℹ️'} RunScreen: Toast - $message');
  }
  
  /// Show loading state
  void _showLoading(String message) {
    _isLoading = true;
    _currentErrorMessage = message;
    
    if (mounted && !_disposed) {
      setState(() {});
    }
    
    print('⏳ RunScreen: Loading - $message');
  }
  
  /// Hide loading state
  void _hideLoading() {
    _isLoading = false;
    _currentErrorMessage = null;
    
    if (mounted && !_disposed) {
      setState(() {});
    }
    
    print('✅ RunScreen: Loading completed');
  }
  
  /// Handle errors with user-friendly feedback
  void _handleError(dynamic error, String operation, {bool showDialog = true, bool showToast = true, VoidCallback? onRetry}) {
    final errorMessage = _getUserFriendlyErrorMessage(error);
    final fullMessage = 'Failed to $operation. $errorMessage';
    
    print('❌ RunScreen: Error in $operation: $error');
    
    if (showToast) {
      _showToast(fullMessage, isError: true);
    }
    
    if (showDialog && onRetry != null) {
      _showErrorDialog(
        'Operation Failed',
        fullMessage,
        showRetry: true,
        onRetry: onRetry,
      );
    } else if (showDialog) {
      _showErrorDialog(
        'Operation Failed',
        fullMessage,
        showRetry: false,
      );
    }
    
    // Hide loading if it was showing
    _hideLoading();
  }
  
  /// Retry operation with exponential backoff
  Future<T?> _retryOperation<T>(Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int retryCount = 0;
    Duration delay = initialDelay;
    
    while (retryCount < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;
        
        if (retryCount >= maxRetries) {
          rethrow;
        }
        
        print('🔄 RunScreen: Retry $retryCount/$maxRetries failed: $e');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
    
    return null;
  }
  
  /// Handle GPS position updates and calculate distance
  void _onGpsPositionUpdate(Position position) {
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
      
      print('📍 RunScreen: GPS update - Position: (${position.latitude}, ${position.longitude})');
      print('📍 RunScreen: GPS update - Distance: ${distance.toStringAsFixed(6)} km, Total: ${_totalDistance.toStringAsFixed(6)} km');
      print('📍 RunScreen: GPS update - Accuracy: ${position.accuracy}m, Speed: ${position.speed}m/s');
    }
    
    // Store the new position
    _lastGpsPosition = position;
    _gpsRoute.add(position);
    
    print('📍 RunScreen: GPS route now has ${_gpsRoute.length} points');
    

    
    // Update UI if mounted
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  /// Start a simple, controllable timer
  void _startSimpleTimer() async {
    // Timer management now handled by ProgressMonitorService
    print('🚀 RunScreen: Timer management delegated to ProgressMonitorService');
    
    // Start GPS tracking for real distance calculation
    _startGpsTracking();
    
    // Start GPS signal loss detection
    _startGpsSignalLossDetection();
    
    // Start real-time pace calculation
    _startPaceCalculation();
    
    // Start network monitoring
    _startNetworkMonitoring();
    
    // Audio will be handled by the background session (SceneTriggerService)
    print('🎵 Audio will be managed by background session');
    
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
    
    print('👂 RunScreen: Now listening to ProgressMonitorService time updates');
  }
  
  /// Save timer state for background persistence
  void _saveTimerState() {
    // Save current timer state to shared preferences
    // This ensures the timer can resume correctly when app is brought back
    print('💾 RunScreen: Saving timer state for background persistence');
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
        
        print('🎵 Audio paused when timer paused (session + audio manager)');
      } catch (e) {
        print('❌ Error pausing audio: $e');
      }
      
      print('⏸️ Simple timer paused at: ${_elapsedTime.inSeconds}s');
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
      print('🛑 Simple timer stopped completely');
    }
    
    // Only call setState if the widget is still mounted and not disposed
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  // Note: _saveRunCompletion method removed to prevent duplicate run saving
  // Run completion is now handled by RunCompletionService
  
  /// Mark episode as completed for the user
  Future<void> _markEpisodeCompleted(String episodeId) async {
    try {
      // Check if Firebase is ready using the provider
      final firebaseStatus = ref.read(firebaseStatusProvider);
      if (firebaseStatus != FirebaseStatus.ready) {
        print('⚠️ RunScreen: Firebase not ready, skipping episode completion');
        return;
      }
      
      print('🏆 RunScreen: Marking episode $episodeId as completed');
      
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) return;
      
      final firestore = FirebaseFirestore.instance;
      
      // Check if user already has progress for this episode
      final existingProgressQuery = await firestore
          .collection('user_progress')
          .where('userId', isEqualTo: user.uid)
          .where('episodeId', isEqualTo: episodeId)
          .limit(1)
          .get();
      
      if (existingProgressQuery.docs.isNotEmpty) {
        // Update existing progress
        final docId = existingProgressQuery.docs.first.id;
        await firestore.collection('user_progress').doc(docId).update({
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
          'elapsedTime': _elapsedTime.inSeconds,
        });
      } else {
        // Create new progress entry
        await firestore.collection('user_progress').add({
          'userId': user.uid,
          'episodeId': episodeId,
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
          'elapsedTime': _elapsedTime.inSeconds,
        });
      }
      
      print('✅ RunScreen: Episode marked as completed');
      
    } catch (e) {
      print('❌ RunScreen: Error marking episode as completed: $e');
      // Don't rethrow - this is not critical
    }
  }
  
  // Helper methods for timer display
  Color _getTimerDisplayColor() {
    if (_timerStopped) return Colors.grey.shade200;
    if (_isPaused) return Colors.orange.shade100;
    return Colors.green.shade100;
  }
  
  Color _getTimerDisplayBorderColor() {
    if (_timerStopped) return Colors.grey.shade400;
    if (_isPaused) return Colors.orange.shade300;
    return Colors.green.shade300;
  }
  
  IconData _getTimerDisplayIcon() {
    if (_timerStopped) return Icons.timer_off;
    if (_isPaused) return Icons.pause_circle;
    return Icons.timer;
  }
  
  Color _getTimerDisplayIconColor() {
    if (_timerStopped) return Colors.grey.shade600;
    if (_isPaused) return Colors.orange.shade600;
    return Colors.green.shade600;
  }
  
  String _getTimerDisplayText() {
    if (_isPaused) return 'Timer Paused';
    return 'Simple Timer';
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
            onPressed: _directSaveRun,
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
              onPressed: _directSaveRun,
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
  Future<void> _directSaveRun() async {
    print('🚀 REAL GPS TRACKING: Starting GPS data save with real distance calculation');
    
    try {
      // Get current user first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ INDEPENDENT GPS CAPTURE: FAILED - No user logged in');
        return;
      }
      
      // Get current time and create a simple run ID
      final now = DateTime.now();
      final runId = 'run_${now.millisecondsSinceEpoch}';
      
      // USE COLLECTED GPS DATA FOR REAL DISTANCE CALCULATION
      List<Map<String, dynamic>> gpsPoints = [];
      
      // Calculate total distance from GPS route to ensure accuracy
      double distance = 0.0;
      if (_gpsRoute.length > 1) {
        for (int i = 1; i < _gpsRoute.length; i++) {
          final prevPos = _gpsRoute[i - 1];
          final currPos = _gpsRoute[i];
          final segmentDistance = Geolocator.distanceBetween(
            prevPos.latitude,
            prevPos.longitude,
            currPos.latitude,
            currPos.longitude,
          ) / 1000; // Convert to kilometers
          distance += segmentDistance;
        }
        print('🚀 REAL GPS TRACKING: Calculated total distance from GPS route: ${distance.toStringAsFixed(6)} km');
      } else {
        distance = _totalDistance; // Fallback to accumulated distance
        print('🚀 REAL GPS TRACKING: Using accumulated distance: ${distance.toStringAsFixed(6)} km');
      }
      
      print('🚀 REAL GPS TRACKING: Using collected GPS data for distance calculation');
      print('🚀 REAL GPS TRACKING: GPS route has ${_gpsRoute.length} points');
      print('🚀 REAL GPS TRACKING: Total accumulated distance: ${_totalDistance.toStringAsFixed(4)} km');
      print('🚀 REAL GPS TRACKING: Elapsed time: ${_elapsedTime.inSeconds} seconds');
      
      // Debug: Check if GPS tracking was working
      if (_gpsRoute.isNotEmpty) {
        print('🚀 REAL GPS TRACKING: First GPS point: (${_gpsRoute.first.latitude}, ${_gpsRoute.first.longitude})');
        print('🚀 REAL GPS TRACKING: Last GPS point: (${_gpsRoute.last.latitude}, ${_gpsRoute.last.longitude})');
      }
      
      if (_gpsRoute.isNotEmpty) {
        // Convert collected GPS positions to data points with elapsed time
        for (int i = 0; i < _gpsRoute.length; i++) {
          final position = _gpsRoute[i];
          
          // Calculate elapsed time at this GPS point
          // Assume GPS points are collected every 5 seconds on average
          final elapsedSecondsAtPoint = (i * 5).clamp(0, _elapsedTime.inSeconds);
          
          gpsPoints.add({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'elapsedSeconds': elapsedSecondsAtPoint,
            'elapsedTimeFormatted': '${(elapsedSecondsAtPoint ~/ 60)}:${(elapsedSecondsAtPoint % 60).toString().padLeft(2, '0')}',
            'accuracy': position.accuracy,
            'altitude': position.altitude,
            'speed': position.speed,
            'heading': position.heading,
          });
        }
        
        print('🚀 REAL GPS TRACKING: Created ${gpsPoints.length} GPS points with real distance: ${distance.toStringAsFixed(4)} km');
      } else {
        print('⚠️ REAL GPS TRACKING: No GPS data collected - distance will be 0');
        distance = 0.0;
      }
      
      // Create comprehensive run data with independent GPS capture
      final runData = {
        'id': runId,
        'userId': currentUser.uid,
        'startTime': now.subtract(Duration(seconds: _elapsedTime.inSeconds)).toIso8601String(),
        'endTime': now.toIso8601String(),
        'duration': _elapsedTime.inSeconds,
        'durationFormatted': '${_elapsedTime.inMinutes}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
        'elapsedTimeSeconds': _elapsedTime.inSeconds,
        'distance': distance,
        'distanceFormatted': '${distance.toStringAsFixed(2)} km',
        'averagePace': _elapsedTime.inSeconds > 0 && distance > 0 ? (_elapsedTime.inSeconds / 60) / distance : 0.0,
        'averagePaceFormatted': _elapsedTime.inSeconds > 0 && distance > 0 ? '${((_elapsedTime.inSeconds / 60) / distance).toStringAsFixed(1)} min/km' : '0.0 min/km',
        'gpsPoints': gpsPoints,
        'totalGpsPoints': gpsPoints.length,
        'episodeId': 'S01E01',
        'episodeTitle': 'First Contact',
        'status': 'completed',
        'completedAt': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'runType': 'episode',
        'wasTimerUsed': true,
        'timerElapsedSeconds': _elapsedTime.inSeconds,
        'wasPaused': _isPaused,
        'deviceInfo': {
          'platform': 'iOS',
          'appVersion': '1.0.0',
        },
        'metadata': {
          'saveMethod': 'real_gps_tracking',
          'gpsSource': 'continuous_collection',
          'gpsPointsCollected': _gpsRoute.length,
          'realDistanceCalculated': true,
          'savedAt': now.toIso8601String(),
        }
      };
      
      print('🚀 REAL GPS TRACKING: Created complete run data');
      print('🚀 REAL GPS TRACKING: Duration: ${_elapsedTime.inSeconds} seconds (${runData['durationFormatted']})');
      print('🚀 REAL GPS TRACKING: Distance: ${distance.toStringAsFixed(2)} km');
      print('🚀 REAL GPS TRACKING: GPS points: ${gpsPoints.length}');
      print('🚀 REAL GPS TRACKING: Episode: ${runData['episodeTitle']}');
      
      // Save directly to Firestore
      await FirebaseFirestore.instance.collection('runs').doc(runId).set(runData);
      
      print('✅ REAL GPS TRACKING: Complete run data saved successfully to Firestore!');
      print('✅ REAL GPS TRACKING: Run ID: $runId');
      print('✅ REAL GPS TRACKING: Collection: runs');
      print('✅ REAL GPS TRACKING: User: ${currentUser.uid}');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Run saved successfully! Duration: ${runData['durationFormatted']}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Set up run summary data for the summary screen
      if (mounted) {
        // Create run summary data
        final summaryData = RunSummaryData(
          totalTime: _elapsedTime,
          totalDistance: _totalDistance,
          averagePace: _currentPace > 0 ? _currentPace : 0.0,
          caloriesBurned: _calculateCalories(_totalDistance, _elapsedTime),
          episode: EpisodeModel(
            id: 'S01E01',
            title: 'First Contact',
            description: 'First Contact episode',
            seasonId: 'S01',
            status: 'completed',
            order: 1,
            createdAt: now,
            updatedAt: now,
            objective: 'Complete the mission',
            targetDistance: 0.0,
            targetTime: 15 * 60 * 1000, // 15 minutes in milliseconds
            audioFiles: [],
          ),
          achievements: _generateAchievements(_totalDistance, _elapsedTime),
          route: gpsPoints.map((point) => LocationPoint(
            latitude: point['latitude']?.toDouble() ?? 0.0,
            longitude: point['longitude']?.toDouble() ?? 0.0,
            accuracy: point['accuracy']?.toDouble() ?? 0.0,
            altitude: point['altitude']?.toDouble() ?? 0.0,
            speed: point['speed']?.toDouble() ?? 0.0,
            elapsedSeconds: point['elapsedSeconds']?.toInt() ?? 0,
            heading: point['heading']?.toDouble() ?? 0.0,
            elapsedTimeFormatted: point['elapsedTimeFormatted'] ?? '0:00',
          )).toList(),
          createdAt: now.subtract(Duration(seconds: _elapsedTime.inSeconds)),
          completedAt: now,
        );
        
        // Set the summary data in the provider
        print('🚀 REAL GPS TRACKING: Setting summary data in provider...');
        print('🚀 REAL GPS TRACKING: Summary data - Time: ${summaryData.totalTime.inSeconds}s, Distance: ${summaryData.totalDistance}km, Pace: ${summaryData.averagePace} min/km');
        
        ref.read(currentRunSummaryProvider.notifier).state = summaryData;
        
        // Verify the data was set
        final verifyData = ref.read(currentRunSummaryProvider);
        print('🚀 REAL GPS TRACKING: Provider verification - Data set: ${verifyData != null}');
        if (verifyData != null) {
          print('🚀 REAL GPS TRACKING: Verified data - Time: ${verifyData.totalTime.inSeconds}s, Distance: ${verifyData.totalDistance}km');
        }
        
        // Navigate to run summary screen
        print('🚀 REAL GPS TRACKING: Navigating to run summary screen...');
        context.go('/run/summary');
      }
      
    } catch (e) {
      print('❌ REAL GPS TRACKING: Error saving run: $e');
      print('❌ REAL GPS TRACKING: Stack trace: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving run: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

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
  
  /// Generate achievements based on distance and time
  List<String> _generateAchievements(double distance, Duration time) {
    final achievements = <String>[];
    
    // Distance achievements
    if (distance >= 5.0) achievements.add('5K Runner');
    if (distance >= 10.0) achievements.add('10K Warrior');
    if (distance >= 21.1) achievements.add('Half Marathon Hero');
    if (distance >= 42.2) achievements.add('Marathon Master');
    
    // Time achievements
    final minutes = time.inMinutes;
    if (minutes >= 30) achievements.add('30 Minute Warrior');
    if (minutes >= 60) achievements.add('Hour Hero');
    if (minutes >= 120) achievements.add('2 Hour Champion');
    
    // Speed achievements
    if (distance > 0) {
      final pace = minutes / distance; // min/km
      if (pace <= 4.0) achievements.add('Speed Demon');
      if (pace <= 5.0) achievements.add('Fast Runner');
      if (pace <= 6.0) achievements.add('Steady Pacer');
    }
    
    // Consistency achievements
    if (distance > 0 && time.inSeconds > 0) {
      achievements.add('GPS Tracker');
      achievements.add('Real Distance Runner');
    }
    
    return achievements;
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ RunScreen: GPS service is disabled');
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
        print('❌ RunScreen: Location permission permanently denied');
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
      print('❌ RunScreen: ensureLocationPermission error: $e');
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
    print('✅ RunScreen: GPS permissions and services OK');
    
    // Don't start if timer was explicitly stopped
    if (_timerStopped) {
      print('🎯 RunScreen: Timer was stopped - not starting session');
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Don't start if there's already an active session
    final isSessionActive = ref.read(runSessionControllerProvider.notifier).isSessionActive;
    if (isSessionActive) {
      print('🎯 RunScreen: Session already active - not starting new session');
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Debug: Check what target data is available
    final userRunTarget = ref.read(userRunTargetProvider);
    print('🎯 RunScreen: _startRun called');
    print('🎯 RunScreen: userRunTarget from provider: $userRunTarget');
    print('🎯 RunScreen: Provider hash: ${userRunTarget.hashCode}');
    
    if (userRunTarget != null) {
      if (userRunTarget.targetDistance > 0) {
        print('🎯 RunScreen: User selected DISTANCE target: ${userRunTarget.targetDistance} km');
      } else if (userRunTarget.targetTime.inMinutes > 0) {
        print('🎯 RunScreen: User selected TIME target: ${userRunTarget.targetTime.inMinutes} min');
      }
    } else {
      print('🎯 RunScreen: No user target, using episode defaults');
    }
    
    // Get episode ID from query parameters and load episode data
    final episodeId = _getEpisodeIdFromQuery();
    print('🎯 RunScreen: Episode ID from query: $episodeId');
    
    EpisodeModel? currentEpisode;
    if (episodeId != null) {
      // Load episode data directly from the story service
      try {
        final episodeAsync = ref.read(episodeByIdProvider(episodeId));
        episodeAsync.whenData((episode) {
          if (episode != null) {
            currentEpisode = episode;
            print('🎯 RunScreen: Episode loaded: ${episode.title}');
            print('🎯 RunScreen: Episode audio files: ${episode.audioFiles.length}');
          }
        });
      } catch (e) {
        print('🎯 RunScreen: Error loading episode: $e');
      }
    }
    
    // If no episode loaded, create a fallback episode with audio files
    if (currentEpisode == null) {
      print('🎯 RunScreen: No episode loaded, creating fallback with audio');
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
      print('🎯 RunScreen: Fallback episode created with ${currentEpisode!.audioFiles.length} audio files');
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
          print('🎯 RunScreen: User selected DISTANCE target: ${userRunTarget.targetDistance} km');
        } else if (userRunTarget.targetTime.inMinutes > 0) {
          // User selected time target
          targetTime = userRunTarget.targetTime;
          targetDistance = null; // No distance target - user only selected time
          print('🎯 RunScreen: User selected TIME target: ${userRunTarget.targetTime.inMinutes} min');
        } else {
          print('🎯 RunScreen: Invalid target - both distance and time are zero');
        }
      }
      // No fallback to database - only show user selection
      
      print('🎯 RunScreen: Using targetTime: $targetTime');
      print('🎯 RunScreen: Using targetDistance: $targetDistance');
      
      // Only start if user has selected a target AND timer wasn't stopped
      print('🎯 RunScreen: Target check: targetTime=$targetTime, targetDistance=$targetDistance, _timerStopped=$_timerStopped');
      if ((targetTime != null || targetDistance != null) && !_timerStopped) {
        // Check if the run session manager can start a session
        print('🎯 RunScreen: Checking if session can start...');
        final canStart = ref.read(runSessionControllerProvider.notifier).canStartSession();
        print('🎯 RunScreen: canStartSession() returned: $canStart');
        if (canStart) {
          final trackingMode = ref.read(trackingModeProvider);
          // Force debug logging for testing
          print('🎯 RunScreen: Starting session with episode: ${currentEpisode!.id}');
          print('🎯 RunScreen: Episode audio files: ${currentEpisode!.audioFiles}');
          print('🎯 RunScreen: Audio files count: ${currentEpisode!.audioFiles.length}');
          
          print('🎯 RunScreen: About to start session...');
          
          // Set up time update callback BEFORE starting the session
          // This ensures we don't miss any time updates
          print('🔗 RunScreen: Setting up time update callback before starting session...');
          _startListeningToServiceUpdates();
          
          await ref.read(runSessionControllerProvider.notifier).startSession(
            currentEpisode!,
            userTargetTime: targetTime ?? const Duration(minutes: 30),
            userTargetDistance: targetDistance ?? 5.0,
            trackingMode: trackingMode,
          );
          print('🎯 RunScreen: Session start completed');
          print('🎯 RunScreen: Session active: ${ref.read(runSessionControllerProvider.notifier).isSessionActive}');
          
          // Hook route updates to force map refresh via provider changes
          ref.read(runSessionControllerProvider.notifier).state.onRouteUpdated = (route) {
            setState(() {});
          };
          print('🎯 RunScreen: Background session started for audio and scene management');
        } else {
          print('🎯 RunScreen: Cannot start session - run session manager is not ready');
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
        print('🎯 RunScreen: Timer was stopped - not starting session');
      } else {
        print('🎯 RunScreen: No user target selected, cannot start session');
      }
      
      setState(() {
        _isInitializing = false;
      });
      
      // Note: Timer callback is now set up before starting the session
      // No need to call _startSimpleTimer() here
      
    } catch (e) {
      print('Error starting run: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting run: $e')),
        );
      }
    }
  }
  

  
  // Simple function to toggle pause state
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused; // Toggle pause state
    });
    
    if (_isPaused) {
      print('⏸️ RunScreen: Timer PAUSED at ${_elapsedTime.inSeconds} seconds');
    } else {
      print('▶️ RunScreen: Timer RESUMED from ${_elapsedTime.inSeconds} seconds');
    }
  }

    // Function to pause the timer
  void _pauseTimer() {
    print('⏸️ RunScreen: Pausing timer');
    
    try {
      // Pause our simple timer first (this we can control)
      _pauseSimpleTimer();
      
      // Also pause the background session
      ref.read(runSessionControllerProvider.notifier).pauseSession();
      print('⏸️ RunScreen: Session paused successfully');
      
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
      print('⏸️ RunScreen: Error pausing session: $e');
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
    print('🔄 RunScreen: Resuming timer from pause');
    
        // Resume the background session and audio
    try {
      // Resume the background session (this will resume the scene trigger audio)
      ref.read(runSessionControllerProvider.notifier).resumeSession();
      
      // Also directly resume all audio from our audio manager
      final audioManager = ref.read(audioManagerProvider);
      await audioManager.resumeAll();
      
      print('🎵 Audio resumed when timer resumed (session + audio manager)');
    } catch (e) {
      print('❌ Error resuming audio: $e');
    }
    
    // Start our simple timer (it will resume from paused time)
    _startSimpleTimer();
    
    setState(() {
      _isInitializing = false;
    });
    
    print('🔄 RunScreen: Timer resumed from pause');
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

    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        title: const Text('Your Run', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      // Scene Notification Overlay removed - no currentSceneProvider available
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Episode Info Card
            if (currentEpisode != null)
              Container(
                margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle,
                        color: kElectricAqua,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Episode',
                        style: TextStyle(
                          color: kElectricAqua,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentEpisode.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentEpisode.objective,
                    style: TextStyle(
                      fontSize: 14,
                      color: kTextMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentEpisode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final userRunTarget = ref.watch(userRunTargetProvider);
                      
                      // Debug logging
                      print('🎯 RunScreen UI: userRunTarget: $userRunTarget');
                      if (userRunTarget != null) {
                        print('🎯 RunScreen UI: Target distance: ${userRunTarget.targetDistance} km');
                        print('🎯 RunScreen UI: Target time: ${userRunTarget.targetTime.inMinutes} min');
                      } else {
                        print('🎯 RunScreen UI: No user target, using episode defaults');
                        print('🎯 RunScreen UI: Episode distance: ${currentEpisode.targetDistance} km');
                        print('🎯 RunScreen UI: Episode time: ${(currentEpisode.targetTime / 60000).toInt()} min');
                      }
                      
                      return Row(
                        children: [
                          // Show distance target only if user selected distance
                          if (userRunTarget != null && userRunTarget.targetDistance > 0)
                            Expanded(
                              child: _buildEpisodeStat(
                                'Target',
                                '${userRunTarget.targetDistance} km',
                                Icons.flag,
                                Colors.orange,
                              ),
                            ),
                          // Show time target only if user selected time
                          if (userRunTarget != null && userRunTarget.targetTime.inMinutes > 0)
                            Expanded(
                              child: _buildEpisodeStat(
                                'Time',
                                '${userRunTarget.targetTime.inMinutes} min',
                                Icons.timer,
                                Colors.blue,
                              ),
                            ),
                          // No fallback to episode defaults - only show user selection
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.audio_file,
                        color: Colors.purple.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio Files: ${currentEpisode.audioFiles.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Simple Timer Display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                       _getTimerDisplayIcon(),
                       color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getTimerDisplayText(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_elapsedTime.inMinutes}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    _isPaused ? 'Paused Time' : 'Elapsed Time',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  // Debug button to check timer status
                  ElevatedButton(
                    onPressed: () {
                      final runSessionManager = ref.read(runSessionControllerProvider.notifier);
                      print('🔍 Debug: Session active: ${runSessionManager.isSessionActive}');
                      print('🔍 Debug: Session state: ${runSessionManager.sessionState}');
                      print('🔍 Debug: Current elapsed time: ${_elapsedTime.inSeconds}s');
                      print('🔍 Debug: Timer running: $_isTimerRunning');
                      print('🔍 Debug: Timer paused: $_isPaused');
                    },
                    child: const Text('Debug Timer Status'),
                  ),
                ],
              ),
            ),

          // Run Stats - Now in a scrollable column
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map panel (Phase C basic) - Fixed height
                const SizedBox(
                  height: 200,
                  child: RunMapPanel(),
                ),
                const SizedBox(height: 16),
                const SceneProgressIndicator(),
                const SizedBox(height: 8),
                const SceneHud(),
                const SizedBox(height: 16),
                  // Scene Progress Indicator
                  Consumer(
                    builder: (context, ref, child) {
                      final currentScene = ref.watch(currentSceneProvider);
                      final playedScenes = ref.watch(playedScenesProvider);
                      final currentProgress = ref.watch(currentRunProgressProvider);
                      
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade50,
                              Colors.blue.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.theater_comedy,
                                  color: Colors.purple.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Story Progress',
                                  style: TextStyle(
                                    color: Colors.purple.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Scene Progress Bar
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: currentProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.shade400,
                                        Colors.blue.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Scene Markers
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: SceneType.values.map((scene) {
                                final isPlayed = playedScenes.contains(scene);
                                final isCurrent = currentScene == scene;
                                final triggerPercentage = SceneTriggerService.getSceneTriggerPercentage(scene);
                                
                                return Column(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isPlayed 
                                          ? Colors.green 
                                          : isCurrent 
                                            ? Colors.orange 
                                            : Colors.grey.shade300,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isCurrent ? Colors.orange.shade600 : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: isPlayed 
                                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                                        : isCurrent 
                                          ? const Icon(Icons.play_arrow, color: Colors.white, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(triggerPercentage * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      SceneTriggerService.getSceneTitle(scene).split(' ').first,
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Current Scene Info
                            if (currentScene != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.volume_up,
                                      color: Colors.orange.shade600,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Playing: ${SceneTriggerService.getSceneTitle(currentScene!)}',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),

                  // Stats Grid
                  Consumer(
                    builder: (context, ref, child) {
                      final currentStats = ref.watch(currentRunStatsProvider);
                      final sessionState = ref.watch(currentRunSessionProvider);
                      
                      return Column(
                        children: [
                          // GPS Status Indicator
                          _buildGpsStatusIndicator(),
                          
                          const SizedBox(height: 16),
                          
                          // Pace Zone Indicator
                          _buildPaceZoneIndicator(),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Distance',
                                   '${(currentStats?.distance ?? 0.0).toStringAsFixed(2)} km',
                                  Icons.straighten,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Speed',
                                   '${_formatSpeed(currentStats?.distance, currentStats?.elapsedTime)} km/h',
                                  Icons.speed,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Current Pace',
                                  _buildCurrentPaceDisplay(),
                                  Icons.trending_up,
                                  _getPaceZoneColor(_getPaceZone(_currentPace)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Current Speed',
                                  '${_currentSpeed.toStringAsFixed(1)} km/h',
                                  Icons.speed,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Avg Pace',
                                   '${_formatPace(currentStats?.averagePace, currentStats?.distance)} min/km',
                                  Icons.trending_up,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Calories',
                                  '${_calculateCalories(currentStats?.distance ?? 0.0, currentStats?.elapsedTime ?? Duration.zero).toStringAsFixed(0)} kcal',
                                  Icons.local_fire_department,
                                  Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Control Buttons
                  Center(
                    child: _buildControlButtons(),
                  ),
                  
                  const SizedBox(height: 24), // Bottom padding for safe area
                ],
              ),
            ),
          ],
        ),
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

  String _getStatusText(RunSessionState state) {
    switch (state) {
      case RunSessionState.inactive:
        return 'Not Started';
      case RunSessionState.running:
        return 'Running';
      case RunSessionState.playingScene:
        return 'Story Playing';
      case RunSessionState.paused:
        return 'Paused';
    }
  }

  Color _getStatusColor(RunSessionState state) {
    switch (state) {
      case RunSessionState.inactive:
        return Colors.grey;
      case RunSessionState.running:
        return Colors.green;
      case RunSessionState.playingScene:
        return Colors.orange;
      case RunSessionState.paused:
        return Colors.orange;
    }
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



  void _finishRun() async {
    try {
      print('🎯 RunScreen: Starting run completion process...');
      
      // Get the current run data directly from the run session manager
      final runSessionManager = ref.read(runSessionControllerProvider.notifier);
      
      // USE THE BUILT-IN createRunModel() METHOD INSTEAD OF MANUAL DATA EXTRACTION
      print('💾 RunScreen: Using createRunModel() method for data capture...');
      
      // Create the run model using the service's built-in method
      // Access the underlying RunSessionManager through the controller's state
      final runModel = runSessionManager.state.createRunModel();
      
      print('💾 RunScreen: Run model created with ${runModel.route?.length ?? 0} GPS points');
      print('💾 RunScreen: Distance: ${runModel.totalDistance}km, Time: ${runModel.totalTime}');
      
      // SAVE THE RUN TO DATABASE FIRST - SIMPLE AND DIRECT
      if (runModel.route?.isNotEmpty == true) {
        print('💾 RunScreen: Saving run to database...');
        try {
          // Save to database directly
          final firestore = FirestoreService();
          final runId = await firestore.saveRun(runModel);
          await firestore.completeRun(runId, runModel);
          print('✅ RunScreen: Run saved to database with ID: $runId');
          print('✅ RunScreen: ${runModel.route?.length ?? 0} GPS points saved');
        } catch (e) {
          print('❌ RunScreen: Error saving run to database: $e');
        }
      } else {
        print('⚠️ RunScreen: No GPS route data to save');
      }
      
      // NOW stop everything AFTER saving the data
      print('🛑 RunScreen: Stopping session and cleanup...');
      
      // Stop the simple timer
      _timerStopped = true;
      _stopSimpleTimer();
      print('🛑 Simple timer stopped completely');
      
      // Stop audio
      final audioManager = ref.read(audioManagerProvider);
      audioManager.stopAll();
      print('🎵 Audio stopped when run finished');
      
      // Stop the run session
      try {
        runSessionManager.stopSession();
        print('🛑 RunSessionManager: Session stopped');
      } catch (e) {
        print('⚠️ RunScreen: Error stopping session: $e');
      }
      
      // Navigate to summary screen
      if (mounted) {
        context.go('/run/summary');
      }
      
    } catch (e) {
      print('❌ RunScreen: Error in _finishRun: $e');
      // Navigate to summary anyway
      if (mounted) {
        context.go('/run/summary');
      }
    }
  }
  
  /// Show user-friendly error dialog
  void _showErrorDialog(String title, String message, {bool showRetry = false, VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceBase,
        title: Text(
          title,
          style: TextStyle(
            color: kTextHigh,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: kTextMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: kElectricAqua),
            ),
          ),
          if (showRetry && onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(
                'Retry',
                style: TextStyle(color: kMeadowGreen),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Convert technical error messages to user-friendly ones
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Please check your internet connection and try again.';
    } else if (errorString.contains('permission') || errorString.contains('access')) {
      return 'Please check your app permissions.';
    } else if (errorString.contains('not found') || errorString.contains('missing')) {
      return 'The requested content could not be found. Please try again.';
    } else if (errorString.contains('timeout')) {
      return 'The operation took too long. Please try again.';
    } else if (errorString.contains('invalid') || errorString.contains('malformed')) {
      return 'Invalid data received. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Build toast notification
  Widget _buildToastNotification() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _currentErrorMessage?.contains('lost') == true || _currentErrorMessage?.contains('Failed') == true
            ? Colors.red.shade100
            : Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _currentErrorMessage?.contains('lost') == true || _currentErrorMessage?.contains('Failed') == true
              ? Colors.red.shade300
              : Colors.green.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _currentErrorMessage?.contains('lost') == true || _currentErrorMessage?.contains('Failed') == true
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: _currentErrorMessage?.contains('lost') == true || _currentErrorMessage?.contains('Failed') == true
                ? Colors.red.shade600
                : Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentErrorMessage ?? '',
              style: TextStyle(
                color: _currentErrorMessage?.contains('lost') == true || _currentErrorMessage?.contains('Failed') == true
                    ? Colors.red.shade600
                    : Colors.green.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showErrorToast = false;
                _currentErrorMessage = null;
              });
            },
            icon: const Icon(Icons.close, size: 20),
            color: Colors.grey.shade600,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  /// Build loading overlay
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kElectricAqua),
              ),
              const SizedBox(height: 16),
              Text(
                _currentErrorMessage ?? 'Loading...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
