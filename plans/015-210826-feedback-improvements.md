# 015 — Feedback improvements (6 items)

## Context

The user filed `feedback-notes.txt` with 6 usability complaints after using the app for a while:
1. The workout-complete screen's "total volume" number is meaningless — replace with a real per-exercise summary.
2. The calendar doesn't show what was actually done that day (only what's scheduled) — clunky to have to go into History.
3. Running tracking has no treadmill run type — treadmill runs synced from Health Connect are silently dropped, and there's no way to mark a manual run as treadmill.
4. Tapping a workout from the home screen jumps straight into the live session — the user wants a preview (prefilled from last time) they can tweak before starting.
5. The big reps/weight numbers during a workout clip to one digit for any 2-3 digit value (e.g. "20" shows "2") — a `SizedBox` sizing bug.
6. The exercise search sheet's results list gets covered by the keyboard.

Six independent-ish UI/data fixes, scoped and confirmed with the user via clarifying questions (see below). Implemented as one batch of small, targeted changes — no speculative abstractions beyond what each item needs.

## Confirmed decisions (from user)

- **Item 1 format:** per-set weight, e.g. `"3 sets · 8×60, 8×60, 7×55kg"`.
- **Item 2:** calendar shows a per-workout icon (chosen at creation, from a fixed 6-icon set: dumbbell, pull-up, push-up, cardio, stretch, core) — solid when a session was actually completed that day, dim when only scheduled. Runs use a running-man icon; treadmill runs use a distinct icon. Tapping a completed day shows the per-exercise summary (reuses item 1's widget); tapping a scheduled-but-undone day shows "Start workout" → the new preview screen (item 4).
- **Item 3:** add `RunType.treadmill`; Health Connect import tags `RUNNING_TREADMILL` correctly instead of dropping it; treadmill runs get the `directions_walk_rounded` icon (no literal treadmill glyph exists in Material Icons).
- **Item 4:** new full preview screen — editable, prefilled from the most recent prior session for that workout (falls back to template defaults) — with a "Start workout" button that carries the (possibly edited) values into the existing session flow unchanged.
- **Item 6:** replace the exercise-search bottom sheet with a full-screen page (search input pinned at top, results fill the rest) so the OS keyboard can never cover results.

## Suggested order

5 → 6 → 3 → 1 → 2 → 4 (smallest/most self-contained first; item 2 depends on item 3's treadmill icon and reuses item 1's summary widget; item 4 is the largest new surface, done last).

---

## Item 5 — Fix reps/weight clipping

**File:** `lib/presentation/workout_session_screen.dart`, `_BigNumber` widget (~line 1191-1267).

Root cause: the value `Text` is wrapped in `SizedBox(width: 90)` at 84px font with `maxLines: 1` and no `overflow` set (defaults to clip) — any 2-3 digit value gets cut off. Both reps (~694-702) and weight (~711-720) use this same widget, so one fix covers both.

Fix: replace the fixed `SizedBox(width: 90)` with a `ConstrainedBox(constraints: BoxConstraints(minWidth: 90))` so the box grows with content instead of clipping it, keeping the same visual size for 1-digit values:

```dart
ConstrainedBox(
  constraints: const BoxConstraints(minWidth: 90),
  child: Text(
    value,
    textAlign: TextAlign.center,
    maxLines: 1,
    softWrap: false,
    style: displayStyle(fontSize: 84, fontWeight: FontWeight.w400, color: c.ink, letterSpacing: -3, height: 0.9),
  ),
),
```
The parent `Row` already uses `mainAxisSize: MainAxisSize.min`, so this is a self-contained ~5-line diff.

---

## Item 6 — Full-screen exercise search

**File:** `lib/presentation/widgets/exercise_library_picker.dart`.

Replace `showModalBottomSheet` with `Navigator.push(MaterialPageRoute(...))`, **keeping the exact same `showExerciseLibraryPicker` function signature** (`onSelected`, `onBlank`, `initialQuery`, `autofocus`) so both call sites in `lib/presentation/create_workout.dart` (~104-109 add-exercise, ~1099-1105 rename-exercise) need zero changes.

Rename `_ExerciseLibrarySheet` → `_ExerciseLibraryPage`; keep all existing state/logic (`_query`, `_filtered`, category grouping, "Use '<query>'" row, timed badge, `_LibraryTile`) unchanged. Restructure `build()` into a `Scaffold`:
- `AppHeaderBar` with a back button at top.
- Search `TextField` (unchanged) directly below it, not inside a sheet.
- `Expanded(child: ListView(...))` for results below that.

A plain `Scaffold` resizes for the keyboard by default (`resizeToAvoidBottomInset: true`), so the input stays pinned at top and results shrink above the keyboard — no manual `viewInsets` math needed (simpler than today's manual `maxHeight: 0.85 * screenHeight`). Existing `Navigator.pop(context)` calls inside item taps keep working (pop the pushed page instead of the sheet).

---

## Item 3 — Treadmill run tracking

**Enum:** `lib/domain/models/run_session.dart:1` — add `treadmill`:
```dart
enum RunType { easy, tempo, interval, long, race, treadmill, other }
```
(`toJson`/`fromJson` use `.name`/`.byName`, no other change there.)

**Health Connect import:** `lib/services/health_service.dart` (~104-110 filter, ~220 mapping) — also accept `HealthWorkoutActivityType.RUNNING_TREADMILL` in the filter (currently only `RUNNING` passes, so treadmill workouts are silently dropped), and set `runType: RunType.treadmill` when the source activity type was treadmill (vs `RunType.other` for plain outdoor `RUNNING`).

**Exhaustive `switch` statements on `RunType`** — must add a `treadmill` case to all 5 (not 3 — verified during planning):
| File | ~Lines |
|---|---|
| `lib/presentation/record_run_screen.dart` (`_runTypeLabel`) | 509-518 |
| `lib/presentation/run_list_screen.dart` (`_runTypeLabel`) | 394-409 |
| `lib/presentation/run_detail_screen.dart` (`_runTypeLabel`) | 43-52 |
| `lib/domain/models/planned_run.dart` (`_typeLabel`) | 30-43 |
| `lib/presentation/mesocycle_setup_screen.dart` | 485-497 |

`record_run_screen.dart`'s type-picker chips iterate `RunType.values` directly, so "Treadmill" appears automatically once the label switch compiles.

**Icon:** `lib/presentation/run_list_screen.dart` (~319-325) currently keys the row icon only on `run.source`. Add a check for `run.runType == RunType.treadmill` → `Icons.directions_walk_rounded`, before falling back to the existing `source`-based check. Reuse the same icon for the calendar's treadmill marker in item 2.

`flutter analyze` after this item is essential — the enum addition will surface any missed non-exhaustive switch as a compile error.

---

## Item 1 — Workout-complete per-exercise summary

**File:** `lib/presentation/workout_complete_screen.dart`.

Remove the `volumeKg`/`volumeLabel` calc and its `_StatCell` (keep duration + completed-sets cells as-is). Add a new section below the stat strip that groups `session.sets` by `exerciseName` (first-seen order preserved) and renders one line per exercise:

```dart
List<_ExerciseBreakdown> _groupByExercise(List<LoggedSet> sets) {
  final order = <String>[];
  final map = <String, List<LoggedSet>>{};
  for (final s in sets) {
    map.putIfAbsent(s.exerciseName, () { order.add(s.exerciseName); return []; }).add(s);
  }
  return [for (final n in order) _ExerciseBreakdown(n, map[n]!)];
}

String _setLine(LoggedSet s) =>
    s.heldSeconds != null ? '${s.heldSeconds}s' : '${s.actualReps}×${fmtWeight(s.actualWeight)}kg';

// per exercise, e.g.:
// "3 sets · 8×60, 8×60, 7×55kg"  (+ "(1 skipped)" suffix if any sets were skipped)
```
Reuses `fmtWeight` from `lib/presentation/widgets/number_picker_sheet.dart` (already used elsewhere for consistent weight formatting). Build this as a small widget (e.g. `lib/presentation/widgets/session_breakdown.dart`, taking `List<LoggedSet>`) so item 2's calendar day-sheet can reuse it verbatim instead of duplicating the grouping logic.

---

## Item 2 — Calendar day markers reflect actual completion + workout icons

### 2a. `Workout.icon` field
**File:** `lib/domain/models/workout.dart` — add `final String? icon;` (optional constructor param), plus `'icon': icon` in `toJson()` (only if non-null) and `icon: json['icon'] as String?` in `fromJson()`. No Hive adapter change needed — `WorkoutAdapter` just JSON-encodes the whole object, so old saved workouts safely deserialize with `icon == null`.

### 2b. Icon catalog
**New file:** `lib/domain/models/workout_icons.dart`:
```dart
const Map<String, IconData> kWorkoutIcons = {
  'dumbbell': Icons.fitness_center_rounded,
  'pull_up': Icons.sports_gymnastics_rounded,
  'push_up': Icons.accessibility_new_rounded,
  'cardio': Icons.favorite_rounded,
  'stretch': Icons.self_improvement_rounded,
  'core': Icons.horizontal_rule_rounded,
};

IconData workoutIconFor(String? key) => kWorkoutIcons[key] ?? Icons.fitness_center_rounded;
```

### 2c. Icon picker in workout creation
**File:** `lib/presentation/create_workout.dart` — add `String? _selectedIcon` state (initialized from `existing?.icon`), a row/grid of tappable icon swatches below the name field (highlight selected), and pass `icon: _selectedIcon` into the `Workout(...)` constructed on save.

### 2d/2e. Wire actual completion into the calendar
**Files:** `lib/presentation/calendar_screen.dart`, `lib/presentation/widgets/month_grid.dart`.

In `calendar_screen.dart`, alongside the existing `runsByDay` grouping, add a `workoutSessionsByDay: Map<String, List<WorkoutSession>>` built the same way (from `sessionsProvider`, using the existing `_dateKey` helper), plus a `workoutIcons: Map<String, String?>` (workoutId → icon key). Pass both into `MonthGrid`.

In `month_grid.dart`, add the two new props (default `const {}`), threaded into `_DayCell` like `runsByDay` already is. Replace the current plain 4×4 "scheduled" dot with an icon lookup: solid + the workout's chosen icon when a session was actually completed that day, dim + the same icon when only scheduled. Apply the equivalent solid/dim split already used for the run icon, and pick the treadmill icon (item 3) when `runsForDay.any((r) => r.runType == RunType.treadmill)`.

### 2f. Day-sheet behavior
**File:** `lib/presentation/calendar_screen.dart`, `_showDaySheet`.

Look up `sessionForDate` from `workoutSessionsByDay`. If present, render the item-1 summary widget (`session_breakdown.dart`) instead of the current "Start workout" button block. If a workout is scheduled but no session exists yet, keep "Start workout" but point it at the new preview screen (item 4) instead of `WarmupScreen`/`WorkoutSessionScreen` directly.

---

## Item 4 — Workout start-preview screen

**New file:** `lib/presentation/workout_start_preview_screen.dart`, class `WorkoutStartPreviewScreen` (named to avoid collision with `create_workout.dart`'s existing `WorkoutPreviewScreen`, which is an unrelated "preview before saving a new template" screen).

**Data flow:**
- `sessionsProvider` already returns sessions newest-first. Find `lastSession = sessions.firstWhereOrNull((s) => s.workoutId == workout.id)`.
- For each exercise in the workout template, prefill from `lastSession`'s most recent logged set with matching `exerciseName` (`actualReps`/`actualWeight`); fall back to the template's own `reps`/`weight` if there's no prior session or no matching sets for that exercise.
- Let the user edit these values inline using the existing `openRepsPicker`/`openWeightPicker` wheel sheets from `lib/presentation/widgets/number_picker_sheet.dart` (same interaction pattern already used live in `workout_session_screen.dart`), held in local mutable state keyed by exercise name.
- **"Start workout" button:** builds an in-memory adjusted `Workout` copy — same `id`/`name`/`icon`, but with each exercise's `reps`/`weight` overridden from the edited values — and pushes it into `WarmupScreen`/`WorkoutSessionScreen` exactly like the existing call sites do (`warmup.isNotEmpty ? WarmupScreen(workout: adjusted) : WorkoutSessionScreen(workout: adjusted)`). Keeping the same `id` means "last session for this workout" lookups keep working. **No changes needed to `WarmupScreen` or `WorkoutSessionScreen`** — they already just read off whatever `Workout` they're given.

**Call sites to update (swap in the preview screen instead of going straight to Warmup/Session):**
- `lib/presentation/workout_list_screen.dart` — `WorkoutListCard.onTap` (~199-206).
- `lib/presentation/calendar_screen.dart` — `_showDaySheet`'s "Start workout" button (~256-267, see item 2f).

---

## Verification

- `flutter analyze` after each item (especially item 3, for enum exhaustiveness).
- Manual pass on device via `adb` (adb path per `CLAUDE.md`):
  - **5:** log a 2-3 digit rep count / weight mid-workout, confirm no clipping.
  - **6:** open exercise search (both add and rename flows) on-device, confirm keyboard never covers results.
  - **3:** check the run-type chip picker shows "Treadmill"; if a Health Connect treadmill workout is available, sync and confirm it imports tagged correctly (otherwise just verify manual logging + labels/icon).
  - **1:** finish a workout with a skipped set and varying weight across sets, confirm the breakdown groups/orders correctly.
  - **2:** set an icon on a workout, complete a session, confirm the calendar shows it solid on the session date and dim on other scheduled dates; tap a completed date → summary; tap a scheduled-undone date → preview screen.
  - **4:** open the preview for a workout with prior history, confirm prefill matches last actuals, edit a value, start, confirm the session screen reflects the edit.

## Open items to double check while implementing

- Exact set of `flutter analyze` warnings after the `RunType.treadmill` addition — the plan found 5 exhaustive switches (not the 3 initially assumed); double check no others were missed.
