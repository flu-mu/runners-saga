# Implementation Plan - September 7th, 2025 (0907)

## 📅 Document Information
- Date: September 7th, 2025
- Document ID: 0907 (MM=09, DD=07)
- Previous Plan: 0906-ImplementationPlan.md (September 6th, 2025)
- Status: IN PROGRESS 🚧

## 🎯 Today's Objectives

### 🚨 CRITICAL PRIORITY
1. **Firebase Security Rules** - Write and deploy security rules before expiration (2 days remaining)
   - Current risk: Database in Test Mode, will deny all requests after 30 days
   - Impact: App will stop working if not addressed

### 🔧 HIGH PRIORITY
2. **Fix Pause/Resume Button** - Button text not updating when paused
   - Current: Pause button pauses timer but doesn't change to "Resume" text
   - Required: Button should show "Resume" when paused, "Pause" when running

3. **Debug Duck Music System** - System not working correctly
   - Current: Duck music implementation not functioning as expected
   - Next: Add debug printouts to monitor volume levels during ducking

### 🧪 TESTING
4. **Build Testing** - Test build after any code modifications
   - Follow cursor rules: "Always test the build after modifying code"

---

## 📋 Yesterday's Accomplishments (0906)

### ✅ Completed Work
- **GPS Preservation & Save Flow** - Fixed GPS points loss at save time
- **Run Completion Status** - Show correct run status in history for new and legacy docs
- **Start Another Run** - Second run can start without app restart
- **Settings Integration** - Distance/pace/speed/energy applied across main views
- **Episode Download Recognition** - Stop unnecessary re-download prompts for S01E03
- **Live Run Map Polyline** - Fixed live map not drawing route during active run
- **Background Audio & Scene Triggers** - Restored background scene triggering
- **Run Summary Stats** - Fixed summary stats showing 0.00 for distance/pace/calories
- **Compact ZRX-Style Layout** - Applied condensed header and expanded map layout
- **Duck Music Implementation** - System implemented but not working correctly
- **Analyzer Cleanups** - Reduced noise for future work

### 🚨 Critical Issues Identified
- **Firebase Security Rules Expiration** - 2 days remaining before client access denied
- **Pause/Resume Button** - Text not updating properly
- **Duck Music System** - Not functioning as expected

---

## ✅ Completed Work

### 1) Firebase Security Rules - CRITICAL TASK COMPLETED ✅
- **Problem**: Database in Test Mode, would deny all requests after September 9th (2 days remaining)
- **Solution**: Created comprehensive security rules with:
  - User authentication requirements for all database access
  - User data protection (users can only access their own data)
  - Read-only access to episodes and seasons for authenticated users
  - Data structure validation for runs and user documents
  - Complete denial of access to unauthorized collections
- **Files Modified**:
  - `firestore.rules` - Complete rewrite with proper security rules
- **Deployment**: Successfully deployed to Firebase production
- **Status**: ✅ **COMPLETED** - App is now secure and will continue working after expiration

### 2) Live Mid-Run Clip Interval Updates - NEW FEATURE ✅
- **Feature**: Real-time control over scene intervals during active runs
- **Implementation**:
  - **SceneTriggerService**: New methods for setting and refreshing clip intervals
    - `setClipInterval(mode, distanceKm?, minutes?)` - applies new mode/values and resets baselines
    - `refreshClipIntervalFromSettings()` - reloads mode/values from SettingsService
  - **RunSessionManager**: Methods to control intervals mid-run
    - `updateClipInterval(ClipIntervalMode, {distanceKm, minutes})`
    - `refreshClipIntervalFromSettings()`
  - **Duration Sheet Integration**: Changes take effect immediately during active workouts
    - Distance tab → updates distance-based intervals
    - Time tab → updates time-based intervals
- **Files Modified**:
  - `runners_saga/lib/shared/services/story/scene_trigger_service.dart`
  - `runners_saga/lib/shared/services/run/run_session_manager.dart`
  - `runners_saga/lib/shared/providers/run_session_providers.dart`
  - `runners_saga/lib/features/run/widgets/run_target_sheet.dart`
  - `runners_saga/lib/shared/models/run_enums.dart`
  - `runners_saga/lib/shared/services/settings/settings_service.dart`
- **Status**: ✅ **IMPLEMENTED** - Needs testing

### 3) Advanced Step Detection & Tracking System - NEW FEATURE ✅
- **Feature**: Comprehensive step detection with multiple tracking modes and unit support
- **Implementation**:
  - **Step Detection Service**: 
    - Uses pedometer if available, falls back to accelerometer peak detection
    - Android runtime permission request for ACTIVITY_RECOGNITION
    - iOS NSMotionUsageDescription for motion data access
  - **Tracking Modes**:
    - **GPS Tracking**: Traditional GPS-based distance tracking
    - **Step Counting**: Pedometer-based with configurable stride length
    - **Simulate Running**: Fixed pace simulation for testing
  - **Unit Support**:
    - Pace picker shows min/mi when Miles selected, min/km otherwise
    - Values converted to/from min/km behind the scenes
    - Live indicators update as pickers are adjusted
  - **UI Enhancements**:
    - Embedded pickers under selected radio items
    - Brand-colored header with master Tracking switch
    - Live indicators: "Stride: Xm YY cm" and "Pace: Xm YYs / mile|km"
  - **Persistence**: All settings saved via SharedPreferences
    - Tracking mode, stride length, simulate pace, master Tracking Enabled flag
- **Files Modified**:
  - `runners_saga/lib/features/story/screens/episode_detail_screen.dart` - UI with embedded pickers
  - `runners_saga/lib/shared/services/run/step_detection_service.dart` - Step detection logic
  - `runners_saga/lib/features/run/screens/run_screen.dart` - Step detection integration
  - `runners_saga/lib/shared/services/run/progress_monitor_service.dart` - Tracking logic
  - `runners_saga/lib/shared/services/run/run_session_manager.dart` - Monitor initialization
  - `runners_saga/lib/shared/providers/run_session_providers.dart` - Provider integration
  - `runners_saga/lib/shared/services/settings/settings_service.dart` - Settings persistence
  - `runners_saga/lib/shared/providers/run_config_providers.dart` - Configuration providers
  - `runners_saga/android/app/src/main/AndroidManifest.xml` - Android permissions
  - `runners_saga/ios/Runner/Info.plist` - iOS motion usage description
  - `runners_saga/pubspec.yaml` - Added sensors_plus and pedometer dependencies
- **Status**: ✅ **IMPLEMENTED** - Needs testing

### 4) OpenStreetMap Subdomain Fix - BUG FIX ✅
- **Problem**: OSM warning about using subdomains with tile server (discouraged practice)
- **Solution**: Removed subdomain usage from TileLayer configurations
- **Implementation**:
  - Changed URL template from `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png` to `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
  - Removed `subdomains: const ['a', 'b', 'c']` property from TileLayer widgets
- **Files Modified**:
  - `runners_saga/lib/features/run/screens/run_history_screen.dart` - Fixed map tile URL
  - `runners_saga/lib/features/run/widgets/run_map_panel.dart` - Fixed map tile URL
- **Status**: ✅ **COMPLETED** - OSM warning resolved

### 5) Duck Music System Fixes - BUG FIX ✅
- **Problem**: Duck music system not working correctly - external apps not lowering volume during scenes
- **Solution**: Implemented proper audio session management and internal ducking
- **Implementation**:
  - **Internal Ducking**: Calls `duckBackgroundMusic(10%)` when scene triggers for immediate in-app music lowering
  - **External App Restoration**: Proper audio session deactivation with `notifyOthersOnDeactivation` so Spotify/Apple Music return to normal volume
  - **Debug Logging**: Added comprehensive audio session monitoring for troubleshooting
    - Subscribed to interruption/noisy/devices streams
    - Logs ducking enable/disable events
    - Monitors audio session focus changes
  - **OS-Level Ducking**: AudioSession configured for ducking (playback + mixWithOthers + duckOthers on iOS, gainTransientMayDuck on Android)
- **Files Modified**:
  - `runners_saga/lib/shared/services/run/run_session_manager.dart` - Internal ducking on scene start
  - `runners_saga/lib/shared/services/story/scene_trigger_service.dart` - External app restoration and debug logging
- **Testing Instructions**:
  1. Start external music (Spotify/Apple Music)
  2. Begin a run; when scene triggers:
     - External music should lower volume during scene
     - In-app background music should drop to ~10%
     - After scene completes, both volumes should restore
  3. Watch logs for ducking events and audio session changes
- **Status**: ✅ **IMPLEMENTED** - Needs testing

---

## 🧪 **TESTING REQUIRED - HIGH PRIORITY**

### 1) Live Mid-Run Clip Intervals Testing
- **Test**: Start a run, open Duration sheet, adjust "between clips" slider
- **Verify**: Next scene triggers at new spacing, even before milestones
- **Files to check**: `run_target_sheet.dart`, `scene_trigger_service.dart`

### 2) Duck Music System Testing  
- **Test**: Start external music (Spotify/Apple Music), begin run, wait for scene
- **Verify**: 
  - External music lowers during scene
  - In-app music drops to ~10%
  - Both volumes restore after scene
- **Logs to watch**: Ducking events, audio session changes
- **Files to check**: `run_session_manager.dart`, `scene_trigger_service.dart`

### 3) Advanced Step Detection & Tracking Testing
- **Test**: Different tracking modes (GPS, Step Counting, Simulate Running)
- **Verify**:
  - Unit conversion (min/mi vs min/km) works correctly
  - Live indicators update in real-time
  - Settings persist between app sessions
  - Master Tracking switch works (disables distance accumulation)
- **Files to check**: `episode_detail_screen.dart`, `step_detection_service.dart`

---

## 🎯 Today's Implementation Plan

### Phase 1: Critical Security (MUST DO FIRST) ✅ COMPLETED
1. **Firebase Security Rules** ✅ **COMPLETED**
   - ✅ Reviewed current firestore.rules file
   - ✅ Written comprehensive security rules for:
     - ✅ User authentication requirements
     - ✅ Data access patterns (runs, episodes, settings)
     - ✅ Field validation and data types
   - ✅ Deployed rules to Firebase
   - ✅ Verified deployment success

### Phase 2: UI Fixes
2. **Pause/Resume Button Fix**
   - Identify current pause button implementation
   - Fix state management for button text
   - Ensure timer stops/starts correctly
   - Test pause/resume functionality

3. **Duck Music Debug**
   - Add debug logging to volume ducking system
   - Test with external music apps (Apple Music, Spotify)
   - Verify volume changes are actually happening
   - Fix any issues found

### Phase 3: Testing & Validation
4. **Build Testing**
   - Run `flutter build` after each major change
   - Verify no compilation errors
   - Test on device if possible

---

## 📝 Notes
- **Firebase Rules**: ✅ **COMPLETED** - App is now secure and will continue working
- **Pause/Resume**: Should be a quick fix once identified
- **Duck Music**: May require deeper investigation into audio session management
- **Testing**: Follow cursor rules for build testing

---

## 🚀 Status
- [x] Firebase Security Rules ✅ **COMPLETED**
- [x] OpenStreetMap Subdomain Fix ✅ **COMPLETED**
- [x] Live Mid-Run Clip Intervals ✅ **IMPLEMENTED** - Needs testing
- [x] Advanced Step Detection & Tracking System ✅ **IMPLEMENTED** - Needs testing  
- [x] Duck Music System Fixes ✅ **IMPLEMENTED** - Needs testing
- [ ] Pause/Resume Button Fix
- [ ] Build Testing
- [ ] Document completion

*** Great progress! OSM warning fixed. Three features need thorough testing before completion. ***
