# Background Service Implementation for Runners Saga

## Overview

This document describes the comprehensive solution implemented to ensure that the Runners Saga app continues to function properly when minimized, maintaining GPS tracking, timer functionality, and story progression without audio conflicts.

## Problem Statement

Previously, the app had several critical issues when minimized:
1. **Timer stopped**: The background timer would stop running when the app was minimized
2. **GPS tracking stopped**: Location updates would cease, losing the runner's route
3. **Story provider stopped**: Scene progression would halt
4. **Audio conflicts**: When the app was restored, multiple audio files would play simultaneously

## Solution Architecture

### 1. App Lifecycle Manager (`AppLifecycleManager`)

The central coordinator that manages all background services and handles app lifecycle changes:

- **App Backgrounding**: Ensures background services start when app is minimized
- **App Foregrounding**: Syncs state from background services and resolves audio conflicts
- **Service Coordination**: Manages communication between all background components

### 2. Enhanced Background Service Manager (`BackgroundServiceManager`)

Manages the native Android background service:

- **Session Persistence**: Maintains run session state across app lifecycle changes
- **Service Lifecycle**: Handles starting/stopping of background services
- **Event Communication**: Bridges Flutter and native Android services

### 3. Enhanced Background Timer Manager (`BackgroundTimerManager`)

Ensures timer continuity in the background:

- **State Persistence**: Saves timer state to SharedPreferences
- **Background Continuity**: Continues counting when app is minimized
- **State Restoration**: Recovers timer state when app returns to foreground

### 4. Enhanced Progress Monitor Service (`ProgressMonitorService`)

Maintains GPS tracking in the background:

- **GPS Persistence**: Saves route data to SharedPreferences
- **Background Tracking**: Continues location updates when app is minimized
- **Data Continuity**: Ensures no GPS data is lost during app lifecycle changes

### 5. Enhanced Android Background Service (`RunTrackingService`)

Native Android service that continues running when the app is minimized:

- **GPS Tracking**: Continuous location updates using Android LocationManager
- **Timer Management**: Background timer using ScheduledExecutorService
- **Wake Lock**: Prevents device from sleeping during runs
- **Foreground Service**: High-priority service with persistent notification

## Key Features

### Continuous GPS Tracking
- GPS updates every 5 seconds (GPS provider) and 10 seconds (Network provider)
- Backup timer ensures positions are captured even when stationary
- Route data persisted to SharedPreferences every 10 GPS points
- Automatic recovery of GPS data when app returns to foreground

### Persistent Timer
- Timer continues running in background using native Android service
- Timer state saved to SharedPreferences
- Automatic validation of timer continuity when app returns
- Correction of any timing gaps detected

### Audio Conflict Prevention
- Audio state management during app lifecycle changes
- Automatic detection and resolution of audio conflicts
- Single audio source enforcement
- Smooth audio transitions between background/foreground

### Battery Optimization
- Request for battery optimization exemption
- Wake lock management for continuous operation
- Efficient background processing
- Foreground service with low-priority notification

## Implementation Details

### App Lifecycle Handling

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  
  if (_isInitialized) {
    // Forward lifecycle changes to the app lifecycle manager
    _appLifecycleManager.onAppLifecycleChanged(state);
  }
}
```

### Background Service Integration

```dart
// Start background service for continuous tracking
await _startBackgroundService(episode, userTargetTime, userTargetDistance);

// Background service continues running when app is minimized
final success = await backgroundServiceManager.startRunSession(
  runId: runId,
  episodeTitle: episode.title,
  targetTime: targetTime,
  targetDistance: targetDistance,
);
```

### GPS Data Persistence

```dart
// Persist route data periodically
Future<void> _persistRouteData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Convert route to JSON and save
  final routeJson = _route.map((pos) => {
    'latitude': pos.latitude,
    'longitude': pos.longitude,
    'accuracy': pos.accuracy,
    // ... other properties
  }).toList();
  
  await prefs.setString(_routeKey, jsonEncode(routeJson));
}
```

### Timer State Persistence

```dart
// Save timer state to SharedPreferences
Future<void> _saveRunState() async {
  final prefs = await SharedPreferences.getInstance();
  
  if (_runStartTime != null) {
    await prefs.setString(_runStartTimeKey, _runStartTime!.toIso8601String());
  }
  
  await prefs.setInt(_runPausedTimeKey, _pausedTime.inMilliseconds);
  await prefs.setString(_runStatusKey, jsonEncode({
    'isRunning': _isRunning,
    'isPaused': _isPaused,
  }));
}
```

## Android Manifest Configuration

The Android manifest includes necessary permissions and service declarations:

```xml
<!-- Background processing permissions -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- Foreground service for background run tracking -->
<service
    android:name=".RunTrackingService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location|mediaPlayback" />
```

## iOS Configuration

The iOS Info.plist includes background modes for location and audio:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
</array>
```

## Usage Flow

### 1. Starting a Run Session
1. User starts episode from app
2. `RunSessionManager.startSession()` is called
3. Background service starts with GPS tracking and timer
4. App can be minimized without losing functionality

### 2. App Minimization
1. App goes to background
2. `AppLifecycleManager` detects state change
3. Background services continue running
4. GPS and timer data persisted to SharedPreferences

### 3. App Restoration
1. App returns to foreground
2. `AppLifecycleManager` syncs state from background services
3. GPS data and timer state restored
4. Audio conflicts resolved automatically

### 4. Session Completion
1. User finishes run
2. Background service stopped
3. All data saved and services cleaned up

## Testing

### Background Functionality Test
1. Start a run session
2. Minimize the app
3. Wait 2-3 minutes
4. Restore the app
5. Verify:
   - Timer continued running
   - GPS tracking continued
   - Route data is complete
   - No audio conflicts

### GPS Continuity Test
1. Start run session
2. Minimize app during GPS tracking
3. Move device to different location
4. Restore app
5. Verify route includes all positions

### Timer Continuity Test
1. Start run session
2. Minimize app
3. Wait for specific time intervals
4. Restore app
5. Verify elapsed time is accurate

## Troubleshooting

### Common Issues

1. **Background service not starting**
   - Check Android manifest permissions
   - Verify battery optimization settings
   - Check logcat for service errors

2. **GPS tracking stops in background**
   - Verify location permissions
   - Check if device has aggressive battery saving
   - Ensure foreground service is running

3. **Timer inaccuracy after background**
   - Check timer state persistence
   - Verify background service timer
   - Check for device sleep issues

4. **Audio conflicts on restore**
   - Check audio state management
   - Verify single audio source enforcement
   - Check scene trigger service state

### Debug Logging

The implementation includes comprehensive debug logging:

```dart
debugPrint('📱 AppLifecycleManager: App going to background at $_lastBackgroundTime');
debugPrint('📍 ProgressMonitorService: GPS update: (${position.latitude}, ${position.longitude})');
debugPrint('⏱️ BackgroundTimerManager: Timer update: $elapsedSeconds seconds');
```

## Performance Considerations

- **GPS Update Frequency**: 5-10 second intervals to balance accuracy and battery life
- **Data Persistence**: Periodic saves every 10 GPS points to minimize I/O
- **Memory Management**: Limited GPS point storage (1000 points) to prevent memory issues
- **Battery Optimization**: Efficient background processing with minimal wake locks

## Future Enhancements

1. **Cloud Sync**: Sync GPS data to cloud storage for backup
2. **Offline Maps**: Cache map tiles for offline route display
3. **Smart GPS**: Adaptive GPS frequency based on movement patterns
4. **Background Audio**: Continue story audio in background with media controls

## Conclusion

This implementation provides a robust solution for background functionality in the Runners Saga app. Users can now:

- **Minimize the app** without losing run progress
- **Continue GPS tracking** in the background
- **Maintain accurate timing** across app lifecycle changes
- **Avoid audio conflicts** when returning to the app
- **Preserve complete run data** regardless of app state

The solution ensures that runners can use the app as intended - starting a run, putting their phone in their pocket, and having the complete story experience without interruption.


