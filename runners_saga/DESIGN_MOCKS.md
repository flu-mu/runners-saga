# Runner's Saga - Hi-Fi Visual Mockups (Midnight Trail Theme)

This doc provides implementation-ready visual specs for the new look and feel. Use it alongside `APP_IMPLEMENTATION_PLAN.md`.

## Theme tokens
- Colors
  - Primary (Electric Aqua): #18D2C4
  - Scene/Alert (Ember Coral): #FF6B57
  - Success (Meadow Green): #30C474
  - Navy base: #0B1B2B
  - Surface base: #101826
  - Surface elevated: #0E1420
  - Gradient: #2A1E5C -> #0E4C63
  - Text high: #EAF2F6, text mid: #A9BAC6, divider: #1C2433
- Radius: 12, 16
- Spacing: 4, 8, 12, 16, 20, 24
- Typography
  - Headings: Poppins 700
  - Body: Inter 400/500
  - Numerals/Stats: Inter 600, tabular

## Episode Details (pre-run)
- App bar: transparent over gradient; title Poppins 600 20pt, color #EAF2F6
- Hero: 390x220pt gradient with season silhouette overlay
- Tiles (each 72pt, r=16, bg #0E1420, border #1C2433)
  - Duration: subtitle "Clip spacing"; opens RunTargetSheet
  - Tracking: value GPS / Steps / Simulate
  - Sprints: switch on right; when on show "Intensity: Light | Moderate | Hard"
  - Music: value External Player; caption "External music ducks during scenes"
- Download pill (above CTA)
  - Idle: "Ready to download (8.2 MB)"
  - Progress: progress bar + percent
  - Done: "All files cached" badge (Meadow Green)
- CTA
  - Disabled: bg #1C2433, text #A9BAC6
  - Enabled: bg #18D2C4, text #0B1B2B

## Run Target Sheet
- Corner radius 28pt; segmented tabs: Distance | Time
- Slider: track #1C2433; active #18D2C4; thumb 24pt white
- Preset chips: selected bg #18D2C4, text #0B1B2B; unselected border #1C2433, text #A9BAC6
- Primary button: Apply (48pt height)

## Tracking Mode Sheet
- Rows (72pt): GPS (recommended), Step Counting, Simulate
- Radio selector; selected row left stripe in Aqua

## Run Screen
- Header: transparent; title Poppins 600 18pt
- Scene pulse: top border 2pt #FF6B57 flashes 120ms on scene start
- Stats slab (120pt): 3 columns
  - Distance big 42pt, unit 12pt (#A9BAC6)
  - Time big 42pt
  - Pace 28pt + caption 12pt
- Map panel (approx 390x300pt)
  - Polyline: #18D2C4 width 4pt
  - Km markers: circular, bg #30C474, text white
  - Position: aqua pulse dot
- Story HUD chip: "Incoming transmission"; bg #141C2B; text #EAF2F6
- Controls: Pause (aqua outline), End Run (ember outline)

## Post-Run Summary
- Banner: gradient with art; "Episode Complete" with green check
- Metrics: Distance, Total Time, Pace small cards
- Splits: horizontal bars, Aqua->Green scale
- Route snapshot: map capture with polyline
- Share buttons: outline aqua, secondary "Save Image"

## Workout Logs & Statistics
- Logs list: thumbnail left, title and date, right stat (distance)
- Statistics: PB cards (1K/1mi), simple bar chart in Aqua

## Downloads Screen
- Rows with title, size, status badge (Idle/Queued/Downloading/Cached)
- Top action: Delete All (danger subdued)

## Theme code snippet
```dart
const kMidnightNavy = Color(0xFF0B1B2B);
const kRoyalPlum    = Color(0xFF2A1E5C);
const kDeepTeal     = Color(0xFF0E4C63);
const kElectricAqua = Color(0xFF18D2C4);
const kEmberCoral   = Color(0xFFFF6B57);
const kMeadowGreen  = Color(0xFF30C474);
const kTextHigh     = Color(0xFFEAF2F6);
const kTextMid      = Color(0xFFA9BAC6);
const kSurfaceBase  = Color(0xFF101826);
const kSurfaceElev  = Color(0xFF0E1420);

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kSurfaceBase,
  colorScheme: const ColorScheme.dark(
    primary: kElectricAqua,
    secondary: kRoyalPlum,
    surface: kSurfaceElev,
    error: kEmberCoral,
  ),
);
```

## Interaction specs
- Scene start: border glow 120ms ease-out then fade 120ms
- Download gate: Start disabled until `DownloadStatus.cached`
- Music ducking: duck on scene start; restore after complete

Note: If you need PNG exports, I can generate and place them under `assets/images/mocks/` based on these specs.


