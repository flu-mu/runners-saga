# Implementation Plan - September 14th, 2025 (1409)

## 📅 Document Information
- Date: September 14th, 2025
- Document ID: 1409 (MM=09, DD=14)
- Previous Plan: 0906-ImplementationPlan.md
- Status: IN PROGRESS ⏳

## 🎯 Today’s Objectives
1.  **Architectural Refactor**: Untangle the timer logic in `run_screen.dart` to create a single, reliable source of truth for run state.
2.  **Coach Feature Foundation**: Build the user interface for the new "Coach" feature in the settings screen.
3.  **Prioritize Audio**: Plan the system for managing audio playback between story scenes and coach readouts.

---

## 📝 Plan & Progress

### **Phase 1: Core Timer and Logic Refactoring (The Foundation)**
- **Status**: ✅ **PARTIALLY COMPLETED**
- **Description**: Simplify the run timer logic by removing redundant timers from `run_screen.dart` and making the `RunSessionManager` (via providers) the single source of truth for run state. This is a critical prerequisite for adding more complex features like the Coach.

- **Tasks**:
    - [x] **Task 1.1: Consolidate the Run Timer in `run_screen.dart`**: Removed local state (`_simpleTimer`, `_elapsedTime`, etc.) and the UI now reflects data from Riverpod providers (`currentRunStatsProvider`, `currentRunSessionProvider`).
    - [x] **Task 1.2: Implement Pre-calculated Scene Triggers**: Ensured `SceneTriggerService` reliably receives progress updates from the refactored `RunSessionManager`.
    - [x] **Task 1.3: Refactor `RunSessionManager`**: Confirmed the connection between `ProgressMonitorService` and `SceneTriggerService` is robust for both foreground and background operation.

### **Phase 2: Coach Feature - Settings UI**
- **Status**: ✅ **PARTIALLY COMPLETED**
- **Description**: Build the UI for the new Coach feature in the settings screen to allow users to configure voice feedback.

- **Tasks**:
    - [x] **Task 2.1: Add "Coach Settings" UI to `settings_screen.dart`**: A new section has been added to the settings screen for all coach-related options.
    - [x] **Task 2.2: Implement Frequency Selection UI**: Added `ToggleButtons` for "By Time" / "By Distance" and corresponding `Slider` controls.
    - [x] **Task 2.3: Implement Content Selection UI**: Added `CheckboxListTile` widgets for selecting which stats the coach reads out.
    - [x] **Task 2.4: Create Providers and Persist Settings**: Created Riverpod providers for each setting and connected them to the `SettingsService` for persistence.

### **Phase 3: Coach Feature - Core Logic**
- **Status**: ✅ **PARTIALLY COMPLETED**
- **Description**: Implement the text-to-speech (TTS) functionality for the coach readouts, ensuring it can be triggered from a background service.

- **Tasks**:
    - [x] **Task 3.1: Create a `CoachService`**: This service uses the `flutter_tts` package to read out stats based on user settings.
    - [x] **Task 3.2: Integrate `CoachService` with `ProgressMonitorService`**: The progress monitor now checks on every tick if a coach readout is due and triggers it.

### **Phase 4: Advanced Audio Scheduling & Prioritization**
- **Status**: ✅ **COMPLETED**
- **Description**: Created and integrated a system to manage audio playback, ensuring coach readouts have priority over story scenes.

- **Tasks**:
    - [x] **Task 4.1: Introduce an `AudioSchedulerService`**: This service manages a priority queue for all audio playback requests.
    - [x] **Task 4.2: Implement Prioritization Logic**: The `CoachService` submits high-priority requests and the `SceneTriggerService` submits normal-priority requests to the scheduler.
    - [x] **Task 4.3: Implement Scene Rescheduling**: The priority queue ensures that if a coach readout is requested, it will play before any subsequent story scenes.

---

## ✅ Completed Work (Today)

### 1) Coach Settings UI
- **Task**: 2.1, 2.2, 2.3
- **Description**: Added a new "COACH" section to the `settings_screen.dart` file. This UI allows users to enable/disable the coach, choose frequency (by time or distance) with sliders, and select which stats to have read aloud using checkboxes.
- **Files**:
  - `runners_saga/lib/features/settings/screens/settings_screen.dart`
- **Verification**: The new UI section appears correctly on the Settings screen. All controls are present but are currently wired to placeholder data. The logic to connect them to providers and persist the settings (Task 2.4) is the next step for this feature.

### 3) Coach Settings Providers & Persistence
- **Task**: 2.4
- **Description**: Created Riverpod providers for all coach settings (`coachEnabled`, `coachFrequencyType`, etc.) and a `SettingsService` to persist these values to `SharedPreferences`. The UI in `settings_screen.dart` is now connected to these providers, allowing users to change and save their coach preferences.
- **Files**:
  - `runners_saga/lib/shared/providers/coach_providers.dart` (new)
  - `runners_saga/lib/shared/services/settings/settings_service.dart` (new)
  - `runners_saga/lib/features/settings/screens/settings_screen.dart` (updated)
  - `runners_saga/lib/shared/models/run_enums.dart` (updated)
- **Verification**: The coach settings are now functional and persist across app restarts.

### 4) Coach Service Core Logic
- **Task**: 3.1
- **Description**: Created a `CoachService` to handle text-to-speech (TTS) readouts. This service reads the user's preferences from the new coach providers, constructs a summary string of the selected run stats, and uses the `flutter_tts` package to speak it.
- **Files**:
  - `runners_saga/lib/shared/services/run/coach_service.dart` (new)
- **Verification**: The service is created and contains the core logic for generating and speaking the readout. The next step is to integrate this service into the `ProgressMonitorService` to trigger readouts at the correct time/distance intervals during a run.

---

### 5) Coach Readout Integration
- **Task**: 3.2
- **Description**: Integrated the `CoachService` with the `ProgressMonitorService`. The progress monitor now tracks the time/distance of the last readout and checks on every timer tick if a new readout is due based on the user's settings. This ensures coach readouts are triggered correctly during a run, even in the background.
- **Files**:
  - `runners_saga/lib/shared/services/run/progress_monitor_service.dart` (updated)
  - `runners_saga/lib/features/settings/screens/coach_service.dart` (updated)
- **Verification**: The logic for triggering readouts is now part of the core run-tracking service.

### 5) Coach Readout Integration
- **Task**: 3.2
- **Description**: Integrated the `CoachService` with the `ProgressMonitorService`. The progress monitor now tracks the time/distance of the last readout and checks on every timer tick if a new readout is due based on the user's settings. This ensures coach readouts are triggered correctly during a run, even in the background.
- **Files**:
  - `runners_saga/lib/shared/services/run/progress_monitor_service.dart` (updated)
- **Verification**: The logic for triggering readouts is now part of the core run-tracking service.

### 6) Audio Scheduler Service
- **Task**: 4.1, 4.2, 4.3
- **Description**: Created an `AudioSchedulerService` to manage a priority queue for audio playback. This prevents the Coach and story scenes from speaking at the same time. Both the `CoachService` (high-priority) and `SceneTriggerService` (normal-priority) have been updated to submit requests to this scheduler.
- **Files**:
  - `runners_saga/lib/shared/services/audio/audio_scheduler_service.dart` (new)
  - `runners_saga/lib/features/settings/screens/coach_service.dart` (updated)
  - `runners_saga/lib/shared/services/story/scene_trigger_service.dart` (updated)
- **Verification**: The architecture for prioritized audio playback is now fully integrated. Coach readouts will correctly play before or after story scenes based on priority.

### 7) Run Screen Timer Refactoring
- **Task**: 1.1
- **Description**: Refactored `run_screen.dart` to remove all local timer and state management logic. The screen now acts as a pure view layer, displaying data directly from `currentRunStatsProvider` and `currentRunSessionProvider`. This resolves a major architectural issue and stabilizes the run screen.
- **Files**:
  - `runners_saga/lib/features/run/screens/run_screen.dart` (updated)
- **Verification**: The run screen UI correctly displays time and other stats from the central providers. The pause/resume buttons correctly delegate to the `RunSessionManager`. The screen is now much simpler and more reliable.

### 8) Scene Trigger Integration Verification
- **Task**: 1.2, 1.3
- **Description**: Verified and strengthened the connection between the `ProgressMonitorService` and the `SceneTriggerService`. The `onProgressUpdate` callback in `ProgressMonitorService` was enhanced to provide not just the progress percentage, but also the current `elapsedTime` and `distance`. This ensures the `SceneTriggerService` has all the data it needs to correctly trigger scenes based on both milestones and intervals, both in the foreground (via `RunSessionManager`) and background.
- **Files**:
  - `runners_saga/lib/shared/services/run/progress_monitor_service.dart` (updated)
- **Verification**: The data pipeline for scene triggering is now robust and complete. The `RunSessionManager` can now reliably forward all necessary progress metrics to the `SceneTriggerService`.