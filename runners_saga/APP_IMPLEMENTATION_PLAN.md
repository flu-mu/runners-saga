# APP IMPLEMENTATION PLAN - The Runner's Saga

## Current Status: PHASE E IN PROGRESS 🚧
**Core user flow is working, but GPS tracking and data persistence need fixing**

### What's Done (Phases A-D) ✅
- ✅ Phase A: New "Midnight Trail" theme, Episode Details screen, settings sheets
- ✅ Phase B: Duration selection bottom sheet, target selection
- ✅ Phase C: Run screen map panel, scene HUD, web simulation mode
- ✅ Phase D: Core User Flow & Navigation - COMPLETED
- ✅ Phase E1: Map Improvements - PARTIALLY COMPLETED

### What's Working Now
- ✅ Home screen with "Midnight Trail" theme and clickable "Northgate Saga" button
- ✅ Season/episode selection screen with horizontal season tabs and vertical episode lists
- ✅ Episode detail screen with blue background and run parameter configuration
- ✅ All run parameter options (Duration, Tracking, Sprints, Music) work as bottom sheets
- ✅ Sensible defaults set automatically: Duration (first option), Tracking (GPS), Sprints (Off), Music (External)
- ✅ Start Workout button is active immediately with defaults
- ✅ Navigation flow: Home → Northgate → Seasons → Episode → Run works end-to-end
- ✅ Firebase integration working (with fallback data when collections don't exist)
- ✅ Audio scene triggering working during runs
- ✅ App builds and runs successfully on iOS device
- ✅ GPS simulation service removed (was causing confusion)
- ✅ Duplicate run entries fixed
- ✅ Run completion service streamlined

---

## CURRENT: Phase E - Enhanced Run Experience 🚧
**Now that the core flow works, let's enhance the run experience**

### Phase E1: Map Improvements ✅ PARTIALLY COMPLETED (2-3 hours)
- ✅ Fixed map overflow issue (removed GPS simulation widget)
- ✅ Implemented KM markers on the map
- ✅ Route polyline drawing implemented
- ✅ Map panel height adjusted to avoid overflow
- ❌ **ISSUE**: Map doesn't accurately display current GPS position
- ❌ **ISSUE**: GPS tracking not working properly during runs

### Phase E2: GPS Tracking & Data Persistence 🚧 PRIORITY FOR TOMORROW (3-4 hours)
- ❌ **CRITICAL ISSUE**: GPS points not being collected during runs
- ❌ **CRITICAL ISSUE**: Run data not being saved to database
- ❌ **CRITICAL ISSUE**: Map not showing real-time position updates
- [ ] Debug GPS data collection in `ProgressMonitorService`
- [ ] Fix `_onPositionUpdate()` method logic
- [ ] Verify location permissions and `Geolocator.getPositionStream()`
- [ ] Ensure `RunSessionManager.stopSession()` saves runs with GPS data
- [ ] Test map real-time updates during runs

### Phase E3: Post-Run Experience (2-3 hours)
- [ ] Create post-run summary screen
- [ ] Implement run completion flow
- [ ] Add navigation from run screen to summary
- [ ] Display run statistics and achievements

### Phase E4: Enhanced Scene Triggering (1-2 hours)
- [ ] Improve scene HUD visibility
- [ ] Add scene transition animations
- [ ] Implement better audio ducking for external music

---

## TOMORROW'S IMPLEMENTATION PLAN (Priority Order)

### 1. **Fix GPS Tracking Issues** 🚨 CRITICAL (2-3 hours)
- **Problem**: Map doesn't accurately display current position, GPS tracking not working
- **Root Cause**: `ProgressMonitorService._onPositionUpdate()` has flawed logic
- **Solution**: 
  - Fix GPS position update logic
  - Add extensive logging to debug GPS data collection
  - Verify location permissions are working
  - Test real-time map updates

### 2. **Fix Run Data Persistence** 🚨 CRITICAL (1-2 hours)
- **Problem**: Test runs not being saved to database, GPS route data missing
- **Root Cause**: `RunSessionManager.stopSession()` may not be calling Firestore save methods
- **Solution**:
  - Add logging to run saving process
  - Verify `FirestoreService.saveRun()` is being called
  - Check if run model contains GPS route data

### 3. **Restore Firestore Indexes** ⚠️ MEDIUM (1 hour)
- **Problem**: Temporarily disabled `orderBy` clauses to avoid index errors
- **Solution**:
  - Create required composite indexes in Firebase console
  - Re-enable `orderBy('startTime', descending: true)` in queries
  - Test workout list sorting

### 4. **Performance Optimization** ⚠️ MEDIUM (1 hour)
- **Problem**: Workout screen loading may have performance issues
- **Solution**:
  - Check Firestore query optimization
  - Verify pagination is working
  - Test with different amounts of run data

---

## Technical Achievements in Phase E
- **GPS Simulation Removal**: Eliminated confusing GPS simulation service
- **Duplicate Run Fix**: Consolidated run saving to single point (`RunSessionManager`)
- **Map Panel Fixes**: Resolved overflow issues and improved route display
- **Build Stability**: App now builds and runs successfully on iOS
- **Audio System**: Scene triggering and audio playback working during runs

## Current Blockers
1. **GPS Tracking**: `ProgressMonitorService` not collecting GPS points properly
2. **Data Persistence**: Runs not being saved to Firestore database
3. **Map Accuracy**: Map not showing real-time position updates
4. **Firestore Indexes**: Need to create composite indexes for proper sorting

## Expected Outcome After Tomorrow
Users should be able to:
1. ✅ Start a run and see real-time GPS tracking
2. ✅ See their position accurately displayed on the map
3. ✅ Have their run data saved with GPS route
4. ✅ View completed runs in workout list (properly sorted)
5. ✅ See accurate distance and time tracking during runs

---

## Original Phases (Resume After Phase E)
### Phase F: Polish & Performance
- [ ] UI refinements
- [ ] Performance optimization
- [ ] Error handling
- [ ] User testing feedback

