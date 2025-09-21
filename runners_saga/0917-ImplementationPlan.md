# Implementation Plan - September 17th, 2025 (0917)

## 📅 Document Information
- **Date**: September 17th, 2025
- **Document ID**: 0917 (MM=09, DD=17)
- **Status**: IN PROGRESS 🚧

---

## 🎯 Today's Objectives

### 🚨 CRITICAL PRIORITY
Based on the latest status report and your feedback, we have four critical bugs to address. The top priority is to ensure the core functionality of the app is working as expected.

1.  **Fix Pace Calculation**: The pace on the run screen is stuck at `0.00`.
2.  **Fix Runs Not Saving to Database**: Completed runs are not being persisted to Firestore.
3.  **Fix Story Audio**: Story scenes are not playing audio.
4.  **Fix Coach Audio**: Coach voice readouts are not working.

---

## 📋 Current Status Summary

The project is at a pivotal stage. The build is stable, and the foundational UI and services are integrated. However, several key features are non-functional.

### ✅ What's Working
- **Build Status**: The iOS build is successful.
- **Core Tracking**: The run timer and distance calculation are working correctly.
- **UI & Navigation**: The main screens and navigation flow are in place.
- **Service Architecture**: `CoachService` and `AudioSchedulerService` are integrated.

### ⚠️ Known Issues (Today's Focus)
- **Pace Calculation**: Stuck at `0.00` during a run.
- **Database Save**: Completed runs are not being saved to Firestore.
- **Story Audio**: `SceneTriggerService` is not playing audio for scenes.
- **Coach Audio**: `CoachService` is not producing TTS voice readouts.

---

## 🚀 Today's Implementation Plan

We will tackle the critical bugs in a logical order, starting with the most fundamental running metric: pace.

### **Phase 1: Fix Pace Calculation**
- **Goal**: Ensure the real-time pace on the `RunScreen` updates correctly.
- **File to Investigate**: `runners_saga/lib/shared/services/run/progress_monitor_service.dart`
- **Action Plan**:
    1.  Review the `_onPositionUpdate` method in `ProgressMonitorService`.
    2.  Analyze the logic for calculating `_currentPace`. The current implementation seems to have a flawed time difference calculation.
    3.  Implement a more robust pace calculation that uses the time difference between consecutive GPS points.
    4.  Verify that `onPaceUpdate` callbacks are being correctly triggered.

### **Phase 2: Fix Database Save**
- **Goal**: Ensure that when a user finishes a run, the `RunModel` is correctly saved to the Firestore `runs` collection.
- **Files to Investigate**:
    - `runners_saga/lib/features/run/screens/run_screen.dart` (the `_finishRun` method)
    - `runners_saga/lib/shared/services/run/run_completion_service.dart`
- **Action Plan**:
    1.  Add extensive logging to the `_finishRun` method to trace the `RunModel` data right before the save attempt.
    2.  Verify that the `RunCompletionService` is being called with the correct data.
    3.  Check for any silent errors during the Firestore `set` operation.
    4.  Confirm that the `RunModel` being created includes the GPS route, as this has been a problem in the past.

### **Phase 3: Debug Audio Systems**
- **Goal**: Get both story scenes and coach readouts to play audio.
- **Files to Investigate**:
    - `runners_saga/lib/shared/services/story/scene_trigger_service.dart`
    - `runners_saga/lib/shared/services/run/coach_service.dart`
    - `runners_saga/lib/shared/services/audio/audio_scheduler_service.dart`
- **Action Plan**:
    1.  **Story Audio**:
        -   In `SceneTriggerService`, verify that `_playSceneAudio` is called.
        -   Check the `AudioPlayer` state within `just_audio`. Is it loading the file? Is it encountering an error?
        -   Ensure the local file paths for the audio are correct and accessible.
    2.  **Coach Audio**:
        -   In `CoachService`, confirm that `_flutterTts.speak()` is being called.
        -   Add `await _flutterTts.awaitSpeakCompletion(true);` to ensure the call is not being dropped.
        -   Check device volume and TTS engine settings.
    3.  **Audio Scheduler**:
        -   Add logging to `AudioSchedulerService` to see if requests are being added to the queue and processed by `_processQueue`.

---

## 🧪 Validation & Success Criteria

By the end of the day, we should be able to:

- [ ] **Pace**: Start a run and see the "Pace" metric on the `RunScreen` update to a non-zero value.
- [ ] **Database**: Complete a run and find a new document in the `runs` collection in Firestore containing the correct distance, time, and route data.
- [ ] **Audio**: Hear the first story scene play at the beginning of a run and hear a coach readout after the first time/distance interval is met.

---

## 📝 Notes
- The contradiction between the status document (stating data saving works) and your report (it doesn't) is noted. We will trust your direct feedback and prioritize fixing the database save issue.
- We will tackle these issues one by one and test after each fix to ensure we are making stable progress.

**Next Action**: Begin debugging the pace calculation logic in `ProgressMonitorService`.
