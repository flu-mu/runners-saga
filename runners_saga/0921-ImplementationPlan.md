# Implementation Plan - September 21st, 2025 (0921)

## 📅 Document Information
- **Date**: September 21st, 2025
- **Document ID**: 0921 (MM=09, DD=21)
- **Status**: IN PROGRESS 🚧

---

## 🔁 Carried Forward From 0917
- 🔄 **Fix Runs Not Saving to Firestore** *(still open) – now top priority with fresh debug logs*
- 🔄 Pace metric continues to read `0.00` during runs *(secondary until persistence is stable)*
- 🔄 Audio system regressions (story + coach) *(defer until persistence + pace resolved)*

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

## ✅ Fix Implemented (0921)
- **Sanitised GPS metrics before serialisation**: `PositionExtension.toLocationPoint` (and the LatLng helper) now coerces `accuracy`, `altitude`, `speed`, and `heading` to finite doubles. Any non-finite value is replaced with a safe fallback (`0` or `null`), ensuring Firestore receives strictly numeric data that will satisfy rules.
- **Utility helpers added**: `_sanitizeDouble` and `_sanitizeNullableDouble` centralise the guard so future adjustments are easy.

Next action is to rerun the finish flow and verify the rule pass. If the write still fails we will log the final `run.toFirestore()` map so we can compare against expected rule schema.

---

## 📋 Immediate Task List
1. **Verify Firestore Write After Sanitisation** ✅
   - Re-ran a simulated session, finished the run, observed no `permission-denied`, and confirmed the document exists in Firestore with the GPS payload intact.
   - ✅ Added temporary payload logger in `FirestoreService.saveRun` (0921) to capture the map before writing; keep it until rules sign-off.
   - ✅ Mirrored rule-required fields (`totalDistance`, `totalTime`, `status`) before writes so Firestore validators pass even though the legacy schema uses `distance` / `duration`.
   - 🔁 Follow-up: once QA validates multiple runs, remove the extra logger and redundant field mirrors if the Firestore schema is migrated.

2. **Backfill Distance/Pace Metrics (if needed)
   - Once persistence passes, double-check that `totalDistance`, `averagePace`, and `route` fields land as expected.

3. **Revisit Pace Calculation Bug (from 0917)**
   - Inspect `_onPositionUpdate` in `ProgressMonitorService`; recalc pace using per-segment deltas to prevent zeros.

4. **Audio Regression Follow-Up**
   - After persistence + pace are stable, resume debugging `SceneTriggerService` and `CoachService` playback.

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
