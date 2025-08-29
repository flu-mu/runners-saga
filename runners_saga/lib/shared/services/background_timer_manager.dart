import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages background timer functionality for run tracking
class BackgroundTimerManager {
  static BackgroundTimerManager? _instance;
  static BackgroundTimerManager get instance => _instance ??= BackgroundTimerManager._();
  
  BackgroundTimerManager._();
  
  static const String _timerKey = 'background_timer';
  static const String _runStartTimeKey = 'run_start_time';
  static const String _runPausedTimeKey = 'run_paused_time';
  static const String _runStatusKey = 'run_status';
  static const String _lastUpdateTimeKey = 'last_update_time';
  static const String _appBackgroundTimeKey = 'app_background_time';
  
  Timer? _backgroundTimer;
  DateTime? _runStartTime;
  Duration _pausedTime = Duration.zero;
  bool _isRunning = false;
  bool _isPaused = false;
  
  // App lifecycle tracking
  DateTime? _appBackgroundTime;
  bool _isAppInBackground = false;
  
  // Stream controllers for real-time updates
  final StreamController<Duration> _elapsedTimeController = StreamController<Duration>.broadcast();
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _backgroundUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters
  Stream<Duration> get elapsedTimeStream => _elapsedTimeController.stream;
  Stream<bool> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get backgroundUpdateStream => _backgroundUpdateController.stream;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  Duration get elapsedTime => _calculateElapsedTime();
  
  /// Initialize the background timer manager
  Future<void> initialize() async {
    await _loadRunState();
    _startBackgroundTimer();
    
    debugPrint('⏱️ BackgroundTimerManager: Initialized with running: $_isRunning, paused: $_isPaused');
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
    
    debugPrint('📱 BackgroundTimerManager: App ${isInBackground ? 'backgrounded' : 'foregrounded'}');
  }
  
  /// Handle app going to background
  void _handleAppBackgrounded() {
    _appBackgroundTime = DateTime.now();
    _saveAppBackgroundTime();
    
    // Ensure timer continues running in background
    if (_isRunning && !_isPaused) {
      _ensureBackgroundTimerRunning();
    }
    
    debugPrint('📱 BackgroundTimerManager: App backgrounded, timer state: running=$_isRunning, paused=$_isPaused');
  }
  
  /// Handle app coming to foreground
  void _handleAppForegrounded() {
    if (_appBackgroundTime != null) {
      final backgroundDuration = DateTime.now().difference(_appBackgroundTime!);
      debugPrint('📱 BackgroundTimerManager: App foregrounded after ${backgroundDuration.inSeconds}s in background');
      
      // Check if timer should have continued running
      if (_isRunning && !_isPaused) {
        _validateTimerContinuity(backgroundDuration);
      }
    }
    
    _appBackgroundTime = null;
    _clearAppBackgroundTime();
  }
  
  /// Validate that timer continued running while app was in background
  void _validateTimerContinuity(Duration backgroundDuration) {
    final expectedElapsed = _calculateElapsedTime();
    final actualElapsed = elapsedTime; // Use the getter instead of undefined _elapsedTime
    
    if ((expectedElapsed - actualElapsed).abs() > const Duration(seconds: 5)) {
      debugPrint('⚠️ BackgroundTimerManager: Timer discontinuity detected! Expected: $expectedElapsed, Actual: $actualElapsed');
      
      // Correct the timer if there was a significant gap
      if (expectedElapsed > actualElapsed) {
        _runStartTime = DateTime.now().subtract(expectedElapsed);
        _saveRunState();
        debugPrint('🔧 BackgroundTimerManager: Timer corrected to: $expectedElapsed');
      }
    }
  }
  
  /// Ensure background timer is running
  void _ensureBackgroundTimerRunning() {
    if (_backgroundTimer?.isActive == true) return;
    
    debugPrint('🔧 BackgroundTimerManager: Restarting background timer');
    _startBackgroundTimer();
  }
  
  /// Start a new run timer
  Future<void> startRun() async {
    _runStartTime = DateTime.now();
    _pausedTime = Duration.zero;
    _isRunning = true;
    _isPaused = false;
    
    await _saveRunState();
    _startBackgroundTimer();
    _statusController.add(true);
    
    debugPrint('⏱️ BackgroundTimerManager: Run started at $_runStartTime');
  }
  
  /// Pause the run timer
  Future<void> pauseRun() async {
    if (!_isRunning || _isPaused) return;
    
    _pausedTime = _calculateElapsedTime();
    _isPaused = true;
    
    await _saveRunState();
    _statusController.add(false);
    
    debugPrint('⏸️ BackgroundTimerManager: Run paused, paused time: $_pausedTime');
  }
  
  /// Resume the run timer
  Future<void> resumeRun() async {
    if (!_isRunning || !_isPaused) return;
    
    _runStartTime = DateTime.now().subtract(_pausedTime);
    _isPaused = false;
    
    await _saveRunState();
    _statusController.add(true);
    
    debugPrint('▶️ BackgroundTimerManager: Run resumed');
  }
  
  /// Stop the run timer
  Future<void> stopRun() async {
    _isRunning = false;
    _isPaused = false;
    _backgroundTimer?.cancel();
    
    await _clearRunState();
    _statusController.add(false);
    
    debugPrint('⏹️ BackgroundTimerManager: Run stopped');
  }
  
  /// Get the current elapsed time
  Duration _calculateElapsedTime() {
    if (!_isRunning || _runStartTime == null) {
      return Duration.zero;
    }
    
    if (_isPaused) {
      return _pausedTime;
    }
    
    return DateTime.now().difference(_runStartTime!);
  }
  
  /// Start the background timer
  void _startBackgroundTimer() {
    _backgroundTimer?.cancel();
    
    _backgroundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning || _isPaused) return;
      
      final elapsed = _calculateElapsedTime();
      _elapsedTimeController.add(elapsed);
      
      // Send background updates for background services
      if (_isAppInBackground) {
        _sendBackgroundUpdate(elapsed);
      }
      
      // Update background service notification every 30 seconds
      if (elapsed.inSeconds % 30 == 0) {
        _updateBackgroundNotification(elapsed);
      }
    });
    
    debugPrint('⏱️ BackgroundTimerManager: Background timer started');
  }
  
  /// Send background update to background services
  void _sendBackgroundUpdate(Duration elapsed) {
    final update = {
      'type': 'TIMER_UPDATE',
      'elapsedSeconds': elapsed.inSeconds,
      'isRunning': _isRunning,
      'isPaused': _isPaused,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _backgroundUpdateController.add(update);
  }
  
  /// Update the background service notification
  void _updateBackgroundNotification(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    // This will be handled by the background service manager
    debugPrint('⏱️ BackgroundTimerManager: Updating notification - $timeString');
  }
  
  /// Save run state to persistent storage
  Future<void> _saveRunState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_runStartTime != null) {
        await prefs.setString(_runStartTimeKey, _runStartTime!.toIso8601String());
      }
      
      await prefs.setInt(_runPausedTimeKey, _pausedTime.inMilliseconds);
      await prefs.setString(_runStatusKey, jsonEncode({
        'isRunning': _isRunning,
        'isPaused': _isPaused,
      }));
      
      await prefs.setString(_lastUpdateTimeKey, DateTime.now().toIso8601String());
      
      debugPrint('💾 BackgroundTimerManager: Run state saved');
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to save run state: $e');
    }
  }
  
  /// Save app background time
  Future<void> _saveAppBackgroundTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_appBackgroundTime != null) {
        await prefs.setString(_appBackgroundTimeKey, _appBackgroundTime!.toIso8601String());
      }
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to save app background time: $e');
    }
  }
  
  /// Clear app background time
  Future<void> _clearAppBackgroundTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_appBackgroundTimeKey);
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to clear app background time: $e');
    }
  }
  
  /// Load run state from persistent storage
  Future<void> _loadRunState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final startTimeString = prefs.getString(_runStartTimeKey);
      if (startTimeString != null) {
        _runStartTime = DateTime.parse(startTimeString);
      }
      
      final pausedTimeMs = prefs.getInt(_runPausedTimeKey) ?? 0;
      _pausedTime = Duration(milliseconds: pausedTimeMs);
      
      final statusString = prefs.getString(_runStatusKey);
      if (statusString != null) {
        final status = jsonDecode(statusString) as Map<String, dynamic>;
        _isRunning = status['isRunning'] ?? false;
        _isPaused = status['isPaused'] ?? false;
      }
      
      // Load app background time
      final backgroundTimeString = prefs.getString(_appBackgroundTimeKey);
      if (backgroundTimeString != null) {
        _appBackgroundTime = DateTime.parse(backgroundTimeString);
        _isAppInBackground = true;
      }
      
      debugPrint('📱 BackgroundTimerManager: Run state loaded - Running: $_isRunning, Paused: $_isPaused, AppBackground: $_isAppInBackground');
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to load run state: $e');
    }
  }
  
  /// Clear run state from persistent storage
  Future<void> _clearRunState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_runStartTimeKey);
      await prefs.remove(_runPausedTimeKey);
      await prefs.remove(_runStatusKey);
      await prefs.remove(_lastUpdateTimeKey);
      await prefs.remove(_appBackgroundTimeKey);
      
      debugPrint('🗑️ BackgroundTimerManager: Run state cleared');
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to clear run state: $e');
    }
  }
  
  /// Get current timer state for background services
  Map<String, dynamic> getCurrentState() {
    return {
      'isRunning': _isRunning,
      'isPaused': _isPaused,
      'elapsedSeconds': elapsedTime.inSeconds,
      'startTime': _runStartTime?.toIso8601String(),
      'pausedTimeMs': _pausedTime.inMilliseconds,
      'isAppInBackground': _isAppInBackground,
      'appBackgroundTime': _appBackgroundTime?.toIso8601String(),
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }
  
  /// Restore timer state from background service
  Future<void> restoreFromBackgroundState(Map<String, dynamic> state) async {
    try {
      final isRunning = state['isRunning'] as bool? ?? false;
      final isPaused = state['isPaused'] as bool? ?? false;
      final elapsedSeconds = state['elapsedSeconds'] as int? ?? 0;
      final startTimeString = state['startTime'] as String?;
      
      if (startTimeString != null && isRunning) {
        _runStartTime = DateTime.parse(startTimeString);
        _isRunning = isRunning;
        _isPaused = isPaused;
        
        if (!isPaused) {
          _pausedTime = Duration.zero;
        } else {
          _pausedTime = Duration(seconds: elapsedSeconds);
        }
        
        await _saveRunState();
        _startBackgroundTimer();
        
        debugPrint('🔄 BackgroundTimerManager: State restored from background service');
      }
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to restore from background state: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _backgroundTimer?.cancel();
    _elapsedTimeController.close();
    _statusController.close();
    _backgroundUpdateController.close();
  }
}

