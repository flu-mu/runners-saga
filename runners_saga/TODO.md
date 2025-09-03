# TODO List - The Runner's Saga

## Critical Issues (Still Unresolved - 10th Attempt)
- [ ] **GPS points not saving to Firebase** - User reports distance shows as 0.0km, only run ID saved
- [ ] **Pause button not pausing timer** - Timer continues running when pause is pressed
- [ ] **Services still running after run completion** - RunSessionManager, Progress calc, Simple timer continue running

## Completed Tasks
- [x] Fix energy units display (kJ/kcal) in outdoor run details
- [x] Fix pace units display (km/h or mi/h) in outdoor run details  
- [x] Fix splits distance units (miles/km based on settings)
- [x] Fix run history units display
- [x] Fix active run screen units
- [x] Fix test file compilation errors
- [x] Add comprehensive debug logging for GPS data access

## Pending Tasks
- [ ] Replace hardcoded colors throughout app with theme system
- [ ] Add Episode Downloads screen accessible from settings
- [ ] Implement theme switching functionality

## Investigation Notes
- GPS points are being collected by ProgressMonitorService (logs show "Progress monitor route has X points")
- But when _directSaveRun() accesses the route, both ProgressMonitor route and RunScreen GPS route show 0 points
- This suggests the route is being cleared between collection and save attempt
- Services continue running after run completion despite cleanup attempts
- "Bad state: Cannot use 'ref' after the widget was disposed" error persists
