# **Morning Chat Setup - Runner's Saga Project**

## **CRITICAL REMINDERS**
- **Do not clean/rebuild** unless a persistent build error blocks progress.
- **Do not change dependencies** or native configs unless directly related to the reported issue.
- **Do not run Xcode builds**; the user runs them locally. Share commands only when requested.
- **Focus strictly on the reported problem**; avoid unrelated refactors or “optimizations”.

## **DAILY START CHECKLIST**
- [ ] Confirm today’s single goal (1 sentence)
- [ ] Identify the exact file/function(s) to touch
- [ ] State minimal edits needed (no version or config changes unless required)
- [ ] If iOS native is involved: list the one command the user may need (e.g., `cd ios && pod install`)
- [ ] After edits: verify no new lints and summarize changes in 2-3 bullets

## **iOS RULES**
- Plugin registration: keep `GeneratedPluginRegistrant.register(with: self)` enabled in `ios/Runner/AppDelegate.swift` unless there’s a specific reason to change it.
- Don’t toggle SceneDelegate or scene manifest unless explicitly necessary; prefer the simplest working setup.
- Run CocoaPods only from `ios/`:
  - `cd ios && pod install && cd ..`
- Don’t suggest cleaning build folders; config changes like `Info.plist` or `AppDelegate.swift` take effect without a clean.

## **LOCATION PERMISSIONS (RUNSCREEN)**
- Always gate run start with a permission+service check:
  - `Geolocator.isLocationServiceEnabled()` → prompt to enable if false
  - `Geolocator.checkPermission()` → request; handle `deniedForever` with app settings link
- Fail fast with a brief Snackbar and exit start logic if not permitted.

## **MAP TILES**
- Use the main OSM endpoint (no subdomains):
  - `https://tile.openstreetmap.org/{z}/{x}/{y}.png`

## **WHEN PACKAGES CHANGE (ONLY IF REQUIRED)**
- Explain why the change is necessary and its expected effect
- Show the minimal diff; run `cd ios && pod install` after `pub get`
- Never flip versions back and forth; confirm with the user first

## **STYLE OF WORK**
- Keep edits scoped, reversible, and documented
- Summarize impact in bullets; avoid long narratives
- If uncertain, ask before proceeding

---
Paste this at the start of the morning chat to keep us aligned and efficient.

## **Implementation Checklist**
- **Goal & Success Criteria**
  - Define today’s single goal in one sentence
  - Write explicit acceptance criteria (measurable result/log/behavior)

- **Scope**
  - List exact files/functions to touch
  - Note affected models/services and platform surfaces (iOS/Android/Web)

- **Safety Rails (do first)**
  - Do not clean/rebuild; user runs Xcode builds
  - Do not change dependencies unless essential; confirm first
  - iOS specifics:
    - Keep `GeneratedPluginRegistrant.register(with: self)` in `ios/Runner/AppDelegate.swift`
    - Don’t add/remove SceneDelegate or scene manifest
    - If deps change: run `cd ios && pod install && cd ..`

- **Implementation Steps**
  - Apply minimal, isolated edits; prefer guards/early returns
  - Follow naming/style; keep functions small and clear
  - If `pubspec.yaml` changed: `flutter pub get` (only then)
  - Add targeted logs for verification

- **Validation**
  - Permission flows: use `_ensureLocationPermission()` before tracking
  - Ask user to run and share logs; do not start Xcode builds
  - Verify original bug behavior (e.g., no duplicate run saves)

- **Rollback**
  - Keep changes confined so we can revert quickly if needed

- **Closeout**
  - Summarize edits (2–3 bullets) and next action
