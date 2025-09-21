# Implementation Plan - September 21st, 2025 (0921)

## 📅 Document Information
- **Date**: September 21st, 2025
- **Document ID**: 0921 (MM=09, DD=21)
- **Status**: IN PROGRESS 🚧

---

## 🔁 Carried Forward / New Follow-Ups
- ✅ **Fix Runs Not Saving to Firestore**
- ✅ Audio coach readouts, pace calculation, and background run behaviour
- 🔄 Run screen load performance (map + audio should wait for UI readiness)
- 🔄 Resume button restores session state
- 🔄 External audio ducking (Spotify / Apple Music) + internal music restoration
- 🔄 Audio session stability (OSStatus -50) while scenes initialise

---

## 🎯 Today's Primary Objective
Ensure completed runs persist to the `runs` collection in Firestore with full route payload.

### ❗️Why This Broke
Latest test run continues to fail with a `permission-denied` error despite authenticated user. That points at Firestore security rules rejecting the payload. The most likely cause is that our write is tripping the validators, typically because a field arrives with an unexpected type or invalid numeric value.

### 🔎 Evidence From 0921 Logs
```
❌ FirestoreService.saveRun: Error occurred: [cloud_firestore/permission-denied]
```
Firestore rules will return `permission-denied` whenever a write does not satisfy the rule predicates (even if auth is correct). We confirmed the user is authenticated and `userId` matches the auth UID, so the rejection is almost certainly data-shape related.

---

## 🧪 Hypothesis: Invalid Field Types in Run Payload
The current `RunModel` serialisation pulls values directly from `geolocator.Position`. On some devices the `speed`, `accuracy`, or `altitude` can come back as `NaN`, `infinity`, or `-infinity`. Firestore stores IEEE 754 numbers, but common security rules use predicates like `is number` / `is finite`, or they compare ranges (e.g. `distance >= 0`). Any NaN/Infinity makes those comparisons fail, causing an automatic rule rejection – the exact symptom we are seeing.

### Other Potential Causes Considered
- **Missing `userId`** – ruled out; logs show the correct UID present.
- **Timestamp format** – we serialise to `Timestamp` via generated code; rules usually accept that.
- **Route list empty** – not the case; we log 37 GPS points just before saving.
- **Metadata structure** – contains scalars and strings only; unlikely to trigger rule failure.

Given the data, non-finite doubles are the only high-probability failure point that matches both the rules behaviour and the raw payload source.

---

## ✅ Fixes Implemented Today
- **Firestore safety net**: `PositionExtension.toLocationPoint` + sanitiser helpers ensure numeric fields stay finite; Firestore writes now succeed under current rules.
- **Local scene playback**: Scene trigger now loads the downloaded clips from disk, and `_episodeDir` logging only fires on first creation.
- **Coach & pace**: Progress monitor sets pace for GPS, simulated, and step runs; coach readouts use the selected stats and new language dropdown before calling TTS.
- **Background continuity**: Run no longer auto-pauses when the app backgrounds; coach and story audio keep playing.

Next steps focus on performance and polish (see Task List).
---

## 📋 Immediate Task List
1. **Run Screen Load Profiling** 🔁
   - Profile start-up (map, scene/audio init) and gate `startSession` until UI is ready. Add lightweight placeholder for map if needed.
2. **Resume Button Fix** 🔁
   - Adjust `RunSessionManager.resumeSession` guard (`if (!_isSessionActive || !_isPaused) return;`) so the UI resume button works.
3. **Audio Session & Ducking** 🔁
   - Reapply `duckOthers` with the simplified config, request focus so Spotify/Apple Music duck, and ensure `_audioManager.restoreBackgroundMusic()` runs after scenes.
4. **Internal Music Continuity** 🔁
   - Verify background track stays playing (volume-only duck) or restart it post-scene if required.
5. **Clean-up Tasks** 🔁
   - Remove Firestore payload logger once QA signs off; monitor logs for any remaining `OSStatus -50` errors.

---

## 🧾 Validation Checklist
- [x] Finish run produces Firestore document with populated `gpsPoints`, `distance`, `duration`, `userId`.
- [x] No security-rule warnings in logcat for the write.
- [ ] Summary screen shows persisted values (distance, pace, achievements) without fallback data. *(pending pace fix)*

---

## 📎 Notes & Next Steps
- If security rules still reject, request temporary access to read the deployed rules or have the team share the relevant validator snippet so we can align payload fields precisely. With the payload logger active we now get the exact structure from the device.
- Keep the sanitisation helpers close to the model so any new GPS-derived fields will adopt the same guardrails by default.
- Once persistence is verified, schedule a quick regression pass over GPX import (`SettingsScreen`) to ensure sanitisation doesn’t need to be mirrored there.
- Coordinate with the pace fix: summary still shows fallback pace, so tackle the pace defect next.
- Sanitised season documents on fetch so missing `order`/`totalEpisodes` values no longer crash `StoryService` (keeps stats tolerant of legacy Firestore data).
- Episode download flow now enforces multi-file parity—cached status stays false until every scene file is present, preventing accidental single-file fallbacks.
- **Audio Playback Investigation (0921)**
  - Likely: iOS audio session fails with `OSStatus -50`. Simplified configuration pending validation; rerun after fresh build to confirm the session activates.
  - Possible: `_localSceneFileMap` mismatch could leave scenes without a local path. Added guard/logging; monitor for `'No local file available'` warnings.
  - Unlikely: Repeated `_episodeDir` creation means redownload; logging now only fires on first creation, confirming we’re just ensuring the folder exists.
  - Unlikely: Coach ducking/audio scheduler blocking story clips. Reviewed logic—it only attenuates internal background music and exits when nothing is playing.
- **New focus areas**
  - Profile run screen load so audio/map start together.
  - Fix resume guard so paused sessions restart cleanly.
  - Extend ducking/resume logic for internal + external audio once session init stabilises.
