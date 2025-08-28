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
  
  Timer? _backgroundTimer;
  DateTime? _runStartTime;
  Duration _pausedTime = Duration.zero;
  bool _isRunning = false;
  bool _isPaused = false;
  
  // Stream controllers for real-time updates
  final StreamController<Duration> _elapsedTimeController = StreamController<Duration>.broadcast();
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  
  // Getters
  Stream<Duration> get elapsedTimeStream => _elapsedTimeController.stream;
  Stream<bool> get statusStream => _statusController.stream;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  Duration get elapsedTime => _calculateElapsedTime();
  
  /// Initialize the background timer manager
  Future<void> initialize() async {
    await _loadRunState();
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
      
      // Update background service notification every 30 seconds
      if (elapsed.inSeconds % 30 == 0) {
        _updateBackgroundNotification(elapsed);
      }
    });
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
      
      debugPrint('💾 BackgroundTimerManager: Run state saved');
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to save run state: $e');
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
      
      debugPrint('📱 BackgroundTimerManager: Run state loaded - Running: $_isRunning, Paused: $_isPaused');
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
      
      debugPrint('🗑️ BackgroundTimerManager: Run state cleared');
    } catch (e) {
      debugPrint('❌ BackgroundTimerManager: Failed to clear run state: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _backgroundTimer?.cancel();
    _elapsedTimeController.close();
    _statusController.close();
  }
}
