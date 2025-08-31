# **Today's Implementation Plan - The Runner's Saga**

## **Date**: August 31, 2025  
**Priority**: HIGH - Critical Timer and GPS Issues  
**Estimated Time**: 6-8 hours  

---

## **🎯 Overview**

Today we need to fix three critical issues that are preventing the app from functioning properly:

1. **Timer Coordination Problem**: Audio scene triggers are resetting elapsed time values
2. **GPS Tracking Issue**: GPS points are not updating with new positions in background
3. **Background Scene Trigger Issue**: Scenes don't play when app is backgrounded

The goal is to create a **unified timer architecture** where scene triggers don't interfere with elapsed time, GPS tracking works continuously in background, and story progression continues seamlessly.

---

## **⚠️ Critical Issues to Fix**

### **Issue 1: Timer Coordination Problem** ⚠️
- **Problem**: When app comes to foreground, scene audio trigger resets elapsed timer
- **Root Cause**: Multiple timers running simultaneously, scene triggers modifying elapsed time
- **Impact**: Users lose accurate run time tracking
- **Priority**: HIGHEST

### **Issue 2: GPS Background Tracking** ⚠️
- **Problem**: GPS points are collected but don't reflect new positions in background
- **Root Cause**: GPS position update logic not properly handling new positions
- **Impact**: Inaccurate route tracking and distance calculation
- **Priority**: HIGH

### **Issue 3: Background Scene Progression** ⚠️
- **Problem**: Story scenes don't play when app is backgrounded
- **Root Cause**: Missing background progress monitoring integration
- **Impact**: Users miss story progression when app is minimized
- **Priority**: HIGH

---

## **🔧 Implementation Plan**

### **Phase 1: Timer Consolidation (Morning - 3 hours)**

#### **1.1 Single Source of Truth for Elapsed Time**
**File**: `lib/shared/services/run/progress_monitor_service.dart`

**Changes Needed**:
```dart
class ProgressMonitorService {
  // Single timer for elapsed time ONLY
  Timer? _elapsedTimeTimer;
  Duration _elapsedTime = Duration.zero;
  DateTime? _startTime;
  
  // This timer ONLY updates elapsed time, nothing else
  void _startElapsedTimeTimer() {
    _elapsedTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMonitoring) return;
      
      // ONLY update elapsed time - no scene triggers, no progress calculations
      _elapsedTime = DateTime.now().difference(_startTime!) - _totalPausedTime;
      onTimeUpdate?.call(_elapsedTime);
    });
  }
}
```

**Remove**: Any other timers that modify `_elapsedTime`

#### **1.2 Separate Progress Calculation Timer**
**File**: `lib/shared/services/run/progress_monitor_service.dart`

**Changes Needed**:
```dart
// Separate timer for progress calculations and scene triggers
void _startProgressCalculationTimer() {
  _progressCalculationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    if (!_isMonitoring) return;
    
    // Calculate progress based on current elapsed time (NOT resetting it)
    final progress = _calculateProgress();
    
    // Trigger scene checks without modifying elapsed time
    _checkSceneTriggers(progress);
  });
}
```

#### **1.3 Remove Duplicate Timers**
**Files to Clean Up**:
- `lib/features/run/screens/run_screen.dart` - Remove `_simpleTimer` that duplicates elapsed time
- `lib/shared/services/run/run_session_manager.dart` - Ensure no timer conflicts
- `lib/shared/services/background_timer_manager.dart` - Coordinate with main timer

**Principle**: Only ONE timer should increment elapsed time

### **Phase 2: Scene Trigger Service Fix (Morning - 1 hour)**

#### **2.1 Prevent Scene Triggers from Modifying Time**
**File**: `lib/shared/services/story/scene_trigger_service.dart`

**Changes Needed**:
```dart
void updateProgress({double? progress, Duration? elapsedTime, double? distance}) {
  if (!_isRunning) return;

  // Use provided values without recalculating elapsed time
  if (progress != null) {
    _currentProgress = progress.clamp(0.0, 1.0);
  } else if (_targetTime != null && elapsedTime != null) {
    // Use elapsed time as-is, don't recalculate
    _currentProgress = (elapsedTime.inMilliseconds / _targetTime!.inMilliseconds).clamp(0.0, 1.0);
  }
  
  _checkSceneTriggers();
}
```

**Key Change**: Scene triggers should NEVER modify elapsed time values

### **Phase 3: GPS Tracking Fix (Afternoon - 2 hours)**

#### **3.1 Fix GPS Position Updates**
**File**: `lib/shared/services/run/progress_monitor_service.dart`

**Changes Needed**:
```dart
void _onPositionUpdate(Position position) {
  if (!_isMonitoring) return;
  
  // Always add new position to route
  _route.add(position);
  
  // Calculate distance from previous position (if exists)
  if (_lastPosition != null) {
    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    ) / 1000; // Convert to kilometers
    
    // Only add distance if it's significant (avoid GPS noise)
    if (distance > 0.001) { // 1 meter minimum
      _currentDistance += distance;
      onDistanceUpdate?.call(_currentDistance);
    }
  }
  
  _lastPosition = position;
  _lastGpsUpdate = DateTime.now();
  
  // Always notify route update
  onRouteUpdate?.call(_route);
}
```

#### **3.2 Enhanced Background GPS Monitoring**
**File**: `lib/shared/services/run/progress_monitor_service.dart`

**Changes Needed**:
```dart
void _startBackgroundGpsMonitoring() {
  // More frequent GPS updates in background
  _backgroundGpsTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (!_isMonitoring) return;
    
    try {
      // Get current position as backup
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      // Add to route if it's a new position
      if (_lastPosition == null || 
          _calculateDistance(_lastPosition!, position) > 0.001) {
        _onPositionUpdate(position);
      }
    } catch (e) {
      debugPrint('Background GPS backup failed: $e');
    }
  });
}
```

#### **3.3 GPS Data Persistence**
**File**: `lib/shared/services/run/progress_monitor_service.dart`

**Changes Needed**:
```dart
Future<void> _persistGpsData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Save route data every 10 GPS points
  if (_route.length % 10 == 0) {
    final routeJson = _route.map((pos) => {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'timestamp': pos.timestamp?.toIso8601String(),
      'speed': pos.speed,
      'heading': pos.heading,
    }).toList();
    
    await prefs.setString('gps_route_${DateTime.now().millisecondsSinceEpoch}', 
                         jsonEncode(routeJson));
    
    debugPrint('📍 GPS route persisted: ${_route.length} points');
  }
}
```

### **Phase 4: Background Scene Trigger Integration (Afternoon - 2 hours)**

#### **4.1 Background Progress Monitoring**
**File**: `lib/shared/services/run/progress_monitor_service.dart`

**Changes Needed**:
```dart
void _startBackgroundProgressMonitoring() {
  // This timer runs even in background to check scene triggers
  _backgroundProgressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (!_isMonitoring) return;
    
    // Calculate progress based on current elapsed time
    final progress = _calculateProgress();
    
    // Check if any scenes should trigger
    _checkSceneTriggers(progress);
    
    // If in background, queue scenes for later playback
    if (_isAppInBackground) {
      _queueBackgroundScenes(progress);
    }
  });
}
```

#### **4.2 Scene Trigger Integration**
**File**: `lib/shared/services/story/scene_trigger_service.dart`

**Changes Needed**:
```dart
// Add method to check scene triggers from external progress
void checkSceneTriggersFromProgress(double progress) {
  _currentProgress = progress.clamp(0.0, 1.0);
  _checkSceneTriggers();
}

// Enhanced background scene handling
Future<void> _handleBackgroundScene(SceneType sceneType) async {
  // Add to background queue
  _backgroundSceneQueue.add(sceneType);
  
  // Show notification
  await _showSceneNotification(sceneType);
  
  // Schedule for playback when app returns to foreground
  _scheduleBackgroundScene(sceneType);
}
```

---

## **🚀 ALTERNATIVE SOLUTION: Single Audio File Approach**

### **Problem Analysis**
After implementing the background scene queuing system, we discovered that **background audio playback is fundamentally unreliable on mobile devices** due to:
- iOS/Android system restrictions
- Audio session interruptions
- File loading failures in background
- Memory and permission limitations

### **Proposed Solution: Single Audio File with Timestamps**
Instead of trying to play multiple audio files in the background, use **one continuous audio file** with precise scene timestamps:

#### **4.3 Single Audio File Implementation**
**File**: `lib/shared/services/story/scene_trigger_service.dart`

**New Architecture**:
```dart
class SceneTriggerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Single audio file containing all scenes
  String? _episodeAudioFile;
  
  // Scene timestamps within the single audio file
  final Map<SceneType, Duration> _sceneTimestamps = {
    SceneType.missionBriefing: Duration.zero,
    SceneType.theJourney: Duration(seconds: 120),      // 2:00
    SceneType.firstContact: Duration(seconds: 240),    // 4:00
    SceneType.theCrisis: Duration(seconds: 420),       // 7:00
    SceneType.extractionDebrief: Duration(seconds: 540), // 9:00
  };
  
  // Pause audio at scene boundaries
  void _pauseAtSceneBoundary(SceneType sceneType) {
    final nextScene = _getNextScene(sceneType);
    if (nextScene != null) {
      final nextTimestamp = _sceneTimestamps[nextScene]!;
      // Pause 1 second before next scene
      final pauseTime = nextTimestamp - const Duration(seconds: 1);
      _schedulePause(pauseTime);
    }
  }
  
  // Resume audio at specific scene timestamp
  Future<void> _playSceneAudio(SceneType sceneType) async {
    final timestamp = _sceneTimestamps[sceneType];
    if (timestamp != null) {
      await _audioPlayer.seek(timestamp);
      await _audioPlayer.play();
    }
  }
}
```

#### **4.4 Benefits of Single Audio File Approach**
- ✅ **Better background compatibility** - One audio session is easier to maintain
- ✅ **No file loading issues** - Audio is already loaded and playing
- ✅ **Precise scene timing** - Exact timestamp control for scene triggers
- ✅ **Simpler state management** - One audio player instance
- ✅ **More reliable background operation** - Pause/unpause is more reliable than file loading

#### **4.5 Implementation Requirements**
1. **Single Audio File**: One MP3/WAV file containing all 5 scenes in sequence
2. **Scene Timestamps**: Precise time markers for each scene trigger point
3. **Audio Player with Seeking**: Use `just_audio`'s `seek()` method for precise positioning
4. **Pause/Resume Logic**: Pause at scene boundaries, resume when triggered

#### **4.6 Questions to Resolve**
- Do you have a single audio file with all 5 scenes?
- What are the exact timestamps for each scene?
- How long is the total audio file?
- Should we implement this as the primary solution or keep the current approach as fallback?

---

## **📋 Implementation Checklist**

### **Phase 1: Timer Consolidation**
- [x] Remove duplicate timers from RunScreen
- [x] Implement single elapsed time timer in ProgressMonitorService
- [x] Add separate progress calculation timer
- [x] Fix race condition in timer callback setup
- [ ] Test timer continuity in background/foreground

### **Phase 2: Scene Trigger Fix**
- [x] Modify SceneTriggerService to not modify elapsed time
- [x] Remove hardcoded audio file references
- [x] Implement Firebase-based audio file resolution
- [x] Add comprehensive debug logging for audio playback
- [ ] Test scene triggers don't reset timer values
- [ ] Verify progress calculation works independently

### **Phase 3: GPS Tracking Fix**
- [x] Fix GPS position update logic
- [x] Add GPS data persistence
- [x] Implement background GPS monitoring
- [ ] Test GPS continuity in background

### **Phase 4: Background Scene Integration**
- [x] Implement background scene queuing system
- [x] Add scene trigger integration
- [x] Enhance app lifecycle handling for foreground resume
- [x] Improve audio session configuration
- [ ] Test background scene progression
- [ ] Verify complete user flow

### **Phase 5: Single Audio File Implementation (Alternative)**
- [ ] Determine if single audio file approach is feasible
- [ ] Get scene timestamps and audio file
- [ ] Implement timestamp-based scene triggering
- [ ] Test background audio compatibility
- [ ] Compare performance with current approach

---

## **🎯 Success Criteria**

### **By End of Day:**
1. **✅ Timer Continuity**: Elapsed time continues correctly when app is backgrounded/foregrounded
2. **✅ GPS Background Tracking**: GPS points update continuously in background with new positions
3. **✅ Scene Trigger Independence**: Scene triggers don't modify or reset elapsed time values
4. **✅ Background Scene Progression**: Scenes can trigger and queue for playback in background
5. **✅ Data Integrity**: All run data (time, distance, GPS route) remains accurate across app lifecycle

### **User Experience:**
- User can start run and background app without losing progress
- GPS tracking continues accurately in background
- Story scenes trigger at correct times even when app is minimized
- App returns to foreground with complete, accurate run data

---

## **⚠️ Important Notes**

1. **Single Timer Principle**: Only ONE timer should increment elapsed time
2. **Scene Trigger Independence**: Scene triggers should NEVER modify elapsed time
3. **GPS Continuity**: GPS must work continuously in background without gaps
4. **Data Persistence**: All critical data must be saved periodically for background survival
5. **Testing Priority**: Test each fix individually before moving to next phase
6. **Background Audio Reality**: Mobile background audio is fundamentally limited - consider single file approach

---

## **🚀 Next Steps After Today**

Once these critical issues are fixed, we can move to:
- Enhanced user experience features
- Advanced workout analytics
- Multi-episode support
- Performance optimizations

**Today's work is foundational** - these fixes will enable all future enhancements to work properly.

---

## **📝 Current Progress Summary (August 31, 2025)**

### **✅ Completed Tasks**
1. **Timer Consolidation**: Fixed race condition in timer callback setup, removed duplicate timers
2. **Scene Trigger System**: Removed hardcoded audio files, implemented Firebase-based resolution
3. **Background Audio**: Implemented scene queuing system for background operation
4. **Audio Session**: Enhanced configuration for better background compatibility
5. **Debug Logging**: Added comprehensive logging throughout audio playback pipeline

### **🔄 In Progress**
1. **Background Scene Testing**: Need to verify scene queuing and foreground resume works
2. **Audio Playback**: Investigating why audio still doesn't play despite path resolution fixes

### **❌ Remaining Issues**
1. **Background Audio Reliability**: Current approach may not be sufficient for reliable background playback
2. **Single Audio File Approach**: Need to evaluate if this alternative solution would be more effective

### **🎯 Next Priority**
Evaluate the single audio file approach as it may provide better background audio compatibility than the current multiple file system.

---

**Agent Instructions**: Follow this plan step-by-step, testing each phase before moving to the next. Focus on the timer consolidation first as it's the root cause of the elapsed time reset issue. Ensure all changes maintain backward compatibility and don't break existing functionality. Consider implementing the single audio file approach if background audio continues to be problematic.