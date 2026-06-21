# Plan: Hold-Timer Exercises + Exercise Library

## Context

Two Phase-2 features in `Feature_tracking.md` are unfinished:

- **Line 45 — Timer for hold exercises.** The `Exercise` model already has a `timedDuration` field and the warm-up flow uses it end-to-end, but for **main workout exercises** there is no way to mark an exercise as timed, and the **active session screen completely ignores `timedDuration`** — it always shows the reps/weight editor and logs reps. Hold exercises (planks, wall-sits, dead-hangs, L-sits) currently can't be run as timers.
- **Line 42 — Exercise library.** There is no preset list of exercises, no categories/muscle-groups, and no search. Exercise names are free-text only. Users must remember and re-type every exercise name.

**Decisions (confirmed with user):**
1. Hold timer = **countdown that auto-completes** at zero (mirror the warm-up timer exactly).
2. Exercise library = **static presets only** (no persistence). Free-text entry still works for anything not in the library.
3. **Log held duration** to history (add a field to `LoggedSet`; show "Held 30s").

---

# Feature A — Hold-Timer Exercises

### A1. Allow main exercises to be marked "Timed" (create_workout.dart)
Currently only `_WarmupExerciseCardState` (lines ~582–729) has the Reps⇄Timed toggle. Replicate that pattern in the **main exercise card `_ExerciseSlotCard`** (starts ~line 737):
- Add `_isTimed` / `_timedValue` state seeded in `initState` from `e.timedDuration != null` (reuse logic at lines 588–596).
- Add a toggle chip (reuse the badge UI at lines 669–686).
- When timed: the `REPS` `_PickerField` becomes a `DURATION` picker writing `e.timedDuration` via `_openTimePicker`; when reps: clear `e.timedDuration` and restore a reps value. Reuse `_toggleMode` logic (lines 604–616) and the existing `_openTimePicker`.
- Keep weight available (a weighted plank is valid) — only reps is swapped for duration.

### A2. Hold-timer view in the active session (workout_session_screen.dart) — THE CORE CHANGE
`timedDuration` already survives into `_sequence` via `generateSequence`/`generateSlots`, so the data is present at runtime.

- **State:** add `_holdSecondsRemaining`, `_holdTotal`, `_isHolding`, plus reuse the existing `_countdownTimer`/`_restTimer` Timer pattern (or add `_holdTimer`).
- **Routing:** in the view selector (lines ~375–380), when the current exercise `e = _sequence[_index]` has `e.timedDuration != null`, render a new `_buildHoldView()` instead of `_buildExerciseView()`.
- **`_buildHoldView()`:** lift almost verbatim from `warmup_screen.dart` `_buildTimedExercise` (lines 311–421) — a circular ring + big countdown number + exercise name + duration label + Skip button. **Reuse the session screen's existing `_RingPainter` (lines 1076–1120)** so no new painter is needed.
- **Timer:** clone `_startRestTimer` (lines 190–210) / warm-up `_startTimer` (lines 120–138) — `Timer.periodic` 1s countdown, `_playBeep()` in the final 3s (helper at 128–133), `_vibrate()` at zero, then **auto-call `_finishSet()`** (auto-complete).
- **Start trigger:** seed `_holdSecondsRemaining`/`_holdTotal` from `e.timedDuration!.inSeconds` when advancing onto a timed exercise (extend `_prefillControllers` at lines 83–89 / `_advance`). Provide a Start/Pause control consistent with the existing pause handling (`_isPaused`).
- Weight: if `e.weight > 0`, still show/log it.

### A3. Record held duration (logged_set.dart + adapter)
- Add `int? heldSeconds` (and `int? targetSeconds`) to `LoggedSet`: constructor, `toJson` (lines 18–25), `fromJson` (lines 27–34) with null default. **No Hive migration** — `LoggedSetAdapter` (typeId 3) is JSON-delegating, old sessions just omit the key.
- In `_finishSet()` (lines 140–156): when `e.timedDuration != null`, set `heldSeconds`/`targetSeconds` from the timer and set reps to 0. `_skipSet()` (158–169) logs `skipped: true` as today.

### A4. Display held duration in history (session_detail_screen.dart)
- `_SetTile` (lines 117–204) hardcodes `Target: r × w → r × w` at lines 168–179. Branch: if the logged set has `heldSeconds != null`, render e.g. `Held ${heldSeconds}s` (target `${targetSeconds}s`) instead of the reps×weight line.
- `history_screen.dart` shows only session-level summaries — **no change needed**.

---

# Feature B — Exercise Library (static presets + search)

### B1. Preset data (new file `lib/domain/models/exercise_library.dart`)
Mirror the `default_warmup.dart` pattern. Define a small immutable template type and a `const` list:
```dart
class LibraryExercise {
  final String name;
  final String category;     // 'Chest','Back','Legs','Shoulders','Arms','Core','Calisthenics','Cardio'
  final bool isTimed;        // hint: hold exercises default to a timer
  const LibraryExercise({required this.name, required this.category, this.isTimed = false});
}

const List<LibraryExercise> kExerciseLibrary = [ ... ];
```
Populate with common movements per category, including calisthenics (pull-ups, chin-ups, dips, push-up variations, pistol squats, muscle-ups) and hold movements flagged `isTimed: true` (plank, side plank, wall sit, dead hang, L-sit, hollow hold). No persistence, no Hive adapter.

### B2. Library picker UI (new file `lib/presentation/widgets/exercise_library_picker.dart`)
Copy the modal-sheet structure from `workout_picker.dart` (`showWorkoutPicker` / `_WorkoutPickerSheet` / `_PickerTile`), built as a **stateful** sheet (like `reminder_picker.dart`) to hold search state:
- Top: a search `TextField` filtering `kExerciseLibrary` by case-insensitive substring on name (optionally category).
- Category section headers grouping results when no search query is active.
- `_PickerTile`-style rows; tapping calls `onSelected(LibraryExercise)` and closes the sheet.
- Signature: `void showExerciseLibraryPicker({required BuildContext context, required void Function(LibraryExercise) onSelected})`.

### B3. Wire picker into create_workout.dart
- **Main exercise:** change the "Add exercise" button (lines 495–526, calling `_addExercise` at 73–96) to first open `showExerciseLibraryPicker`. On select, build an `Exercise` from the template (reuse the existing defaults: `reps:10, sets:1, restTime:Duration.zero, weight:0`, and if `template.isTimed` set `timedDuration: const Duration(seconds: 30)`), wrap in a `Superset`, and append. Keep a "type my own / blank" affordance so free-text still works for exercises not in the library.
- Inserted exercises remain fully editable in the existing cards (name `TextField` stays), so library is purely a head-start.

### B4. (Optional, skipped for now) category on Exercise model
Not required for static-preset search. Skip adding `category` to `Exercise` unless we later want to display/group by category in workouts.

---

## Files to change
- `lib/presentation/create_workout.dart` — timed toggle on main exercise card (A1); wire library picker (B3).
- `lib/presentation/workout_session_screen.dart` — hold-timer state + `_buildHoldView` + auto-complete timer (A2).
- `lib/domain/models/logged_set.dart` — add `heldSeconds`/`targetSeconds` (A3).
- `lib/presentation/session_detail_screen.dart` — show held duration in `_SetTile` (A4).
- **New** `lib/domain/models/exercise_library.dart` — preset data (B1).
- **New** `lib/presentation/widgets/exercise_library_picker.dart` — search picker (B2).

## Reuse map
- Hold timer UI: `warmup_screen.dart` `_buildTimedExercise` (311–421) + session screen's existing `_RingPainter` (1076–1120).
- Countdown logic: `warmup_screen.dart` `_startTimer` (120–138) / session `_startRestTimer` (190–210); `_playBeep`, `_vibrate`.
- Timed toggle: `create_workout.dart` `_WarmupExerciseCardState` (582–729), `_toggleMode` (604–616), `_openTimePicker`.
- Preset data: `default_warmup.dart`.
- Picker UI: `workout_picker.dart` (`showWorkoutPicker`/`_PickerTile`) + `reminder_picker.dart` (stateful sheet).
- JSON-based Hive adapters mean **no migration** for the `LoggedSet` field change.

## Verification
1. `flutter analyze` — no new errors.
2. **Timed create:** Create a workout, add an exercise from the library, toggle it to Timed, set 30s, save. Reopen to confirm it persists as timed.
3. **Hold session:** Start the workout. On the timed exercise, confirm a countdown ring shows, beeps in the last 3s, vibrates, and **auto-advances** to rest at zero. Confirm non-timed exercises still show the reps/weight editor.
4. **History:** Open the finished session in `session_detail_screen` — the timed set shows "Held 30s" instead of "0 × 0kg".
5. **Library search:** Add-exercise → picker opens → type "plank" → list filters → selecting inserts a pre-filled (timed) exercise. Confirm typing a name not in the library still works.
6. Confirm older saved sessions still load (backward-compatible `LoggedSet.fromJson`).
7. Build/run on device via the `release-phone` skill if a full device check is wanted.
