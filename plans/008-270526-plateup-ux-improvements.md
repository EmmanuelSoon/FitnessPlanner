# PlateUp UX Improvements

## Context
Six improvements requested to enhance the fitness app experience:
1. Screen wake lock + sound/vibration during warm-ups (currently only during workout sessions)
2. 3-second countdown before the first warm-up exercise begins
3. Auto-scroll to newly added exercise in the create workout screen
4. Title-case capitalization for exercise name input
5. Scroll-wheel pickers for REPS, REST, and DURATION fields (time-based fields use min+sec columns)
6. Rename app from "Fitness Planner" to "PlateUp"

---

## Critical Files

| File | Purpose |
|---|---|
| `lib/presentation/warmup_screen.dart` | Add wakelock, sound, vibration, pre-start countdown |
| `lib/presentation/create_workout.dart` | Scroll controller, title-case, picker fields |
| `lib/main.dart` | App title string |
| `android/app/src/main/AndroidManifest.xml` | Android display name |
| `ios/Runner/Info.plist` | iOS display name |

---

## Feature Details

### 1 · Wakelock + Sound + Vibration During Warm-Up
**File:** `lib/presentation/warmup_screen.dart`

- Add imports: `wakelock_plus`, `audioplayers`, `vibration`, `flutter/services.dart`
- Add `AudioPlayer? _audioPlayer;` field
- `initState`: `WakelockPlus.enable()` + `_audioPlayer = AudioPlayer()`
- `dispose`: `WakelockPlus.disable()` + `_audioPlayer?.dispose()`
- Add `_playBeep()` and `_vibrate(int ms)` helpers (same pattern as `workout_session_screen.dart` lines 128-137)
- In `_startTimer()` (timed exercise): beep + `HapticFeedback.mediumImpact()` each second; `HapticFeedback.heavyImpact()` at 0
- In the "Get Ready" interstitial timer in `_advanceExercise()`: beep + `HapticFeedback.mediumImpact()` each tick

---

### 2 · 3-Second Pre-Warm-Up Countdown
**File:** `lib/presentation/warmup_screen.dart`

- Add state: `bool _isPreStart = true;` and `int _preStartSeconds = 3;`
- In `initState`, replace direct `_startCurrentExercise()` with `_startPreCountdown()`
- `_startPreCountdown()`: sets `_isPreStart = true`, counts 3->0 with beep + haptic each tick, then calls `_startCurrentExercise()`
- In `build()`, add `if (_isPreStart) return _buildPreStart();` before existing checks
- `_buildPreStart()` reuses `_buildGetReady()` layout: shows "GET READY", the countdown number, and first exercise name as "Up next"

---

### 3 · Auto-Scroll on Add Exercise
**File:** `lib/presentation/create_workout.dart`

- Add `final _scrollCtrl = ScrollController();` to `_CreateWorkoutScreenState`
- Dispose it in `dispose()`
- Pass `controller: _scrollCtrl` to the `ListView` (line 287)
- After `setState` in `_addExercise()`:
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  });
  ```

---

### 4 · Title Case for Exercise Name Input
**File:** `lib/presentation/create_workout.dart`

Two TextFields get `textCapitalization: TextCapitalization.words`:
- Exercise name field in `_ExerciseSlotCardState.build()` (~line 855)
- Exercise name field in `_WarmupExerciseCardState.build()` (~line 646)

---

### 5 · Scroll-Wheel Pickers for REPS, REST, and DURATION

**Scope:** All "reps" or "time-based" fields get pickers. SETS and WEIGHT keep text inputs.

**Fields affected:**
| Widget | Field | Picker type |
|---|---|---|
| `_ExerciseSlotCard` | REPS | Single column, 1-50 |
| `_ExerciseSlotCard` | REST | Two columns: min (0-9) + sec (0, 5, ..., 55) |
| `WarmupExerciseCard` (timed mode) | DURATION | Two columns: min (0-9) + sec (0, 5, ..., 55) |
| `WarmupExerciseCard` (rep mode) | REPS | Single column, 1-50 |

**Key constraint:** The card row `[SETS][REPS][WEIGHT][REST]` is already compact.
**Solution:** Field boxes keep the **exact same physical size** — they just display a compact formatted value:
- REPS: `"10"` (unchanged visually)
- REST/DURATION: `"1:30"` or `"0:45"` (4 chars, similar width to current `"60s"`)

All picker interaction happens inside a **modal bottom sheet** — no layout changes to the card row.

**New shared widget `_PickerField`:**
- Same visual style as `_NumField` (same padding, border, label text style)
- Shows formatted value as static text (no keyboard)
- Entire box wrapped in `GestureDetector` -> `onTap` opens bottom sheet
- Value tracked as typed state in parent card (not via `TextEditingController`)

**REPS bottom sheet:**
- Single `CupertinoPicker`, values 1-50
- Initial index = `currentReps - 1`
- On select: updates `e.reps` + `setState`

**REST / DURATION bottom sheet (same component, reused for both):**
- Two side-by-side `CupertinoPicker` columns
- Left: minutes 0-9 with "min" label
- Right: seconds 0, 5, 10, ..., 55 (12 items) with "sec" label
- Initial selection derived from current `Duration`
- On select: updates `s.restAfterSet` or `e.timedDuration` depending on caller
- Display: `"${m}:${s.toString().padLeft(2, '0')}"` e.g. `"1:30"`, `"0:45"`

**Changes to `_ExerciseSlotCardState`:**
- Remove `_repsCtrl` and `_restCtrl` `TextEditingController`s
- Add `late int _repsValue` and `late Duration _restDuration` state fields
- Replace REPS `_NumField` -> `_PickerField` (reps variant)
- Replace REST `_NumField` -> `_PickerField` (rest/duration variant)

**Changes to `_WarmupExerciseCardState`:**
- Remove `_valueCtrl` `TextEditingController`
- Add `late int _repsValue` and `late Duration _timedValue` state fields (initialized from exercise)
- Replace the inline value `TextField` with `_PickerField`:
  - Timed mode: DURATION picker (min+sec) -> updates `e.timedDuration`
  - Rep mode: REPS picker (single column) -> updates `e.reps`
- In `_toggleMode()`: reset the relevant state variable (default 30s timed, 10 reps)

---

### 6 · Rename App to PlateUp

| File | Change |
|---|---|
| `lib/main.dart` line 57 | `title: 'Fitness Planner'` -> `title: 'PlateUp'` |
| `android/.../AndroidManifest.xml` line 3 | `android:label="fitness_planner"` -> `android:label="PlateUp"` |
| `ios/Runner/Info.plist` line 10 | `<string>Fitness Planner</string>` -> `<string>PlateUp</string>` |
| `ios/Runner/Info.plist` line 18 | `<string>fitness_planner</string>` -> `<string>PlateUp</string>` |

**Do NOT** change `pubspec.yaml`'s `name: fitness_planner` — it's the Dart package identifier used in all imports.

---

## Execution Order
1. Feature 6 - App rename (simplest)
2. Feature 4 - Title case (one-liner per field)
3. Feature 3 - Scroll controller
4. Feature 1 - Wakelock + sound + vibration in warmup
5. Feature 2 - Pre-warm-up countdown (builds on feature 1 helpers)
6. Feature 5 - Scroll-wheel pickers (most complex, last)

---

## Verification
- `flutter analyze` - no new errors
- Create workout screen:
  - "Add exercise" -> list animates to new card
  - Exercise name keyboard opens in title case
  - Tap REPS -> bottom sheet scroll wheel 1-50
  - Tap REST -> two-column picker (min + sec), field shows "1:30" style
- Warm-up section in create workout:
  - Tap DURATION field (timed mode) -> two-column picker (min + sec)
  - Tap REPS field (rep mode) -> single-column picker
  - Exercise name also opens in title case
- Warm-up flow during workout:
  - 3-second "GET READY" countdown before first exercise
  - Screen stays on throughout warm-up
  - Beep + haptic each second
- App name shows "PlateUp" on home screen
