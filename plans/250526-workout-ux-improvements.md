# Workout UX Improvements
**Date:** 25 May 2026  
**Source:** User feedback round 1 (11 items)

---

## Overview

Addressing 11 user-reported issues across three themes:
- **Active-workout polish** (screen lock, sound, countdown, timer prominence, rest controls)
- **Data model enhancements** (supersets, warm-up phase)
- **Navigation & end-of-session flows** (post-create routing, workout-complete screen)

Grouped into three phases ordered by risk and dependency.

---

## Phase 1 — Quick wins (no model changes)

### 1.1 — Decrease rest time button *(Item 6)*
**File:** `lib/presentation/workout_session_screen.dart`

Add a `−15s` button next to the existing `+15s` in `_buildRestView()`.  
Clamp to a minimum of 0 seconds so it can't go negative.

```dart
void _subtractRestTime(int seconds) {
  setState(() {
    _restSecondsRemaining =
        (_restSecondsRemaining - seconds).clamp(0, _restTotal + 3600);
  });
}
```

Change the bottom row from `[+15s | Skip rest]` to `[−15s | +15s | Skip rest]`.

---

### 1.2 — Hide weight when 0 *(Item 8)*
**File:** `workout_session_screen.dart`

In `_buildExerciseView()`, only render the weight `_BigNumber` and the divider when `e.weight > 0`:

```dart
if (e.weight > 0) ...[
  _divider,
  _BigNumber(value: ..., label: 'weight', unit: 'kg', ...),
]
```

In the "UP NEXT" card in `_buildRestView()`:
```dart
Text(nextEx.weight > 0
    ? '${nextEx.reps} × ${nextEx.weight}kg'
    : '${nextEx.reps} reps')
```

---

### 1.3 — Workout duration more prominent *(Item 9)*
**File:** `workout_session_screen.dart`

Move the elapsed timer from the small top-right mono text into a dedicated centred display **below the set-progress bar** and **above the hero content**.

Layout target:
```
[close]
EXERCISE 2 / 5       Set 1 / 3
[====|===]   (progress bar)
        00:47        ← centred, larger
[Exercise name]
[reps]    |    [weight]
Next: Bench Press
```

Style: `fontSize: 28`, monospace, `c.inkDim`. Remove the old tiny top-right timer.  
Apply the same centred elapsed display to `_buildRestView()` (currently absent there).

---

### 1.4 — Post-create navigation to workout list *(Item 7)*
**File:** `lib/presentation/create_workout.dart`

When creating a **new** workout (not editing), after `WorkoutPreviewScreen` returns `saved == true`, the current code just clears the form and stays on `CreateWorkoutScreen`. Fix: pop all the way back to the root (workout list).

```dart
// In _goToPreview().then callback:
if (saved == true) {
  if (widget.existingWorkout != null) {
    Navigator.pop(context); // editing: single pop as before
  } else {
    // New workout: pop CreateWorkout + WorkoutPreview to reach list
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
```

---

### 1.5 — Fix rest screen layout / text overflow *(Item 2)*
**File:** `workout_session_screen.dart` → `_buildRestView()`

The "UP NEXT" card can overflow on narrow screens.  
Redesign the rest screen hero area to a vertical stack matching the Quiet design language:

```
SET 2              ← small label, c.inkMute
Bench Press        ← large display text
10 × 60kg          ← reps × weight (omit weight if 0)
──────────────────
  [circular timer]
```

Shift the exercise info **above** the ring timer, give each section flex space, constrain the ring to 200×200. Replace the card container with plain text hierarchy.

---

## Phase 2 — Active workout behaviour

### 2.1 — Keep screen on during workout *(Item 1)*
**Package:** add `wakelock_plus: ^1.2.10` to `pubspec.yaml`

```dart
// initState()
WakelockPlus.enable();

// dispose() and _finishWorkout()
WakelockPlus.disable();
```

---

### 2.2 — Sound & haptic feedback *(Item 3)*
**Root cause:** `SystemSound.play(SystemSoundType.alert)` is often silent on Android when media volume is 0 or device profile suppresses it. `HapticFeedback` requires vibration support to be enabled.

**Fix:**
- Add `vibration: ^2.0.0` — richer haptic with graceful fallback.
- Add `audioplayers: ^6.1.0` — play a bundled short beep asset.
- Bundle `assets/sounds/beep.mp3` (250 ms tone).
- On the 3-second rest countdown ticks: `Vibration.vibrate(duration: 100)` + play beep.
- On rest end / set complete: `Vibration.vibrate(duration: 250)`.

**`pubspec.yaml` additions:**
```yaml
dependencies:
  audioplayers: ^6.1.0
  vibration: ^2.0.0
```

---

### 2.3 — 5-second countdown before workout starts *(Item 5)*
**File:** `workout_session_screen.dart`

Add `_isCountingDown = true` and `_countdownSeconds = 5` to state.  
`initState()` runs the countdown first, then starts `_elapsedTimer` when it reaches 0.

`build()` gains a third branch:
```dart
_isCountingDown ? _buildCountdownView() : (_isResting ? _buildRestView() : _buildExerciseView())
```

`_buildCountdownView()` — full-screen overlay:
```
GET READY
   [5 → 1]       ← giant mono number
[Workout name]
```
Haptic + beep on each tick. On 0: heavy impact, transition to exercise view.

---

## Phase 3 — New features (model changes required)

### 3.1 — Supersets *(Item 10)*

#### New model: `Superset`

```dart
// lib/domain/models/superset.dart
class Superset {
  String id;
  List<Exercise> exercises;  // ≥1; if length > 1 it's a true superset
  int sets;
  Duration restAfterSet;     // rest only after all exercises in the group complete once

  bool get isSuperset => exercises.length > 1;
}
```

`Exercise` loses its `sets` and `restTime` fields (they move to `Superset`).  
`Workout.exercises` becomes `List<Superset>`.

**Migration:** On load from Hive, wrap each legacy `Exercise` in a single-exercise `Superset`. Bump the Hive adapter version for both `Exercise` and `Workout`.

#### Sequence generation

```dart
// Superset.generateSlots() — returns flat list of execution slots
// For 3 sets of [Bench, Fly] with 90s rest:
//   Bench(s1) → Fly(s1) → REST 90s → Bench(s2) → Fly(s2) → REST 90s → Bench(s3) → Fly(s3)
```

Between exercises within the same set of a superset: no rest, just an "intra-group next" label.  
Rest only fires after the last exercise of each set (except the final set of the workout).

#### UI changes

- **CreateWorkout:** Add a "group with next exercise" toggle on each exercise card. When enabled, a vertical accent bar visually connects the cards and the REST field is hidden (rest lives at the `Superset` level, shown on the last exercise of the group).
- **WorkoutSessionScreen:** During a superset, replace the rest timer between intra-group exercises with an instant "→ Next: [exercise]" transition.
- **WorkoutPreview:** Show supersets with a bracket / grouping indicator and a shared set count.

---

### 3.2 — Warm-up session before workout *(Item 4)*

#### Model changes

Add `List<Exercise> warmup` (defaults `[]`) to `Workout`.  
Plain `Exercise` is sufficient — warm-ups are always sequential single exercises, never supersets. Warm-up exercises are not logged in the session (informational + timer only).

```dart
// Workout model
List<Exercise> warmup; // defaults to []
```

**Timed exercises:** Warm-up exercises are time-based (30 s each), not rep-based. Add an optional field to `Exercise`:

```dart
Duration? timedDuration; // if non-null → timed exercise; reps field ignored
```

The `WarmupScreen` checks `timedDuration != null` to decide whether to show a countdown timer or a rep count. This also future-proofs timed cardio exercises in the main workout.

#### Default warm-up

When a user creates a new workout, pre-populate `warmup` with the following 6 exercises (~5 min total including transitions):

| # | Exercise | Duration | Focus |
|---|---|---|---|
| 1 | Jumping Jacks | 30 s | Full-body activation |
| 2 | High Knees | 30 s | Cardio / hip flexors |
| 3 | Arm Circles | 30 s | Shoulder mobility |
| 4 | Cross-Body Shoulder Stretch | 30 s | Upper body |
| 5 | Standing Quad Stretch | 30 s | Legs — quads |
| 6 | Standing Hamstring Stretch | 30 s | Legs — hamstrings |

```dart
// lib/domain/models/default_warmup.dart
const List<Exercise> kDefaultWarmup = [
  Exercise(name: 'Jumping Jacks',               timedDuration: Duration(seconds: 30)),
  Exercise(name: 'High Knees',                  timedDuration: Duration(seconds: 30)),
  Exercise(name: 'Arm Circles',                 timedDuration: Duration(seconds: 30)),
  Exercise(name: 'Cross-Body Shoulder Stretch', timedDuration: Duration(seconds: 30)),
  Exercise(name: 'Standing Quad Stretch',       timedDuration: Duration(seconds: 30)),
  Exercise(name: 'Standing Hamstring Stretch',  timedDuration: Duration(seconds: 30)),
];
```

Applied in `CreateWorkoutScreen.initState()` for new workouts:
```dart
if (widget.existingWorkout == null) {
  _warmup.addAll(kDefaultWarmup);
}
```

The user can remove or reorder exercises before saving — the default is just a starting point.

#### UI flow

1. If `workout.warmup.isNotEmpty`, push `WarmupScreen` before `WorkoutSessionScreen`.
2. `WarmupScreen` iterates through `workout.warmup` exercises in order:
   - **Timed exercise** (`timedDuration != null`): shows exercise name + a large countdown ring (same `_RingPainter` as rest timer). Advances automatically when timer hits 0, or user can tap "Skip".
   - **Rep-based exercise** (future use): shows exercise name + rep count + "Done" button.
3. Brief 3-second "Get ready" interstitial between each exercise.
4. After the last warm-up exercise, navigate to the main `WorkoutSessionScreen`.

**New file:** `lib/presentation/warmup_screen.dart`

#### CreateWorkout

Add a collapsible "Warm-up" section above the main exercises. Pre-filled with `kDefaultWarmup`. Uses a simplified exercise card (no REST field, no SETS/WEIGHT fields for timed exercises — just NAME + DURATION). User can toggle each entry between timed and rep-based.

---

### 3.3 — Workout complete screen *(Item 11)*

**New file:** `lib/presentation/workout_complete_screen.dart`

Replace the snackbar + `Navigator.pop()` in `_finishWorkout()` with `Navigator.pushReplacement` to `WorkoutCompleteScreen(session: session)`.

#### Screen layout

```
✓  Workout done!
[workout name]

Duration   Sets   Volume
  42:17     18    4.2t

─────────────────────────
🧘 Remember to cool down
   Stretch for 5–10 min

─────────────────────────
[ Next workout — Thu ]     ← only shown if a schedule exists
  Push Day

─────────────────────────
[Back to workouts]
```

#### "Next workout" logic

Read `scheduledWorkouts` from Hive (to be added in the calendar phase). If present, surface the next upcoming entry after today's date. If none exist, the section is hidden entirely.

> **Note:** The calendar feature doesn't exist yet — the "next workout" slot is reserved in the UI with a `// TODO: calendar phase` comment and hidden by default.

---

## File changes summary

| File | Change |
|---|---|
| `pubspec.yaml` | Add `wakelock_plus`, `audioplayers`, `vibration` |
| `assets/sounds/beep.mp3` | **New** |
| `lib/domain/models/exercise.dart` | Remove `sets`, `restTime` → moved to `Superset`; add `timedDuration` field |
| `lib/domain/models/exercise_adapter.dart` | Version bump |
| `lib/domain/models/default_warmup.dart` | **New** — `kDefaultWarmup` constant |
| `lib/domain/models/superset.dart` | **New** |
| `lib/domain/models/superset_adapter.dart` | **New** Hive adapter |
| `lib/domain/models/workout.dart` | `exercises` → `List<Superset>`, add `warmup: List<Exercise>` field |
| `lib/domain/models/workout_adapter.dart` | Version bump + migration fallback |
| `lib/presentation/workout_session_screen.dart` | Items 1, 2, 3, 5, 6, 8, 9, 10 |
| `lib/presentation/create_workout.dart` | Items 4, 7, 10 |
| `lib/presentation/warmup_screen.dart` | **New** (Item 4) |
| `lib/presentation/workout_complete_screen.dart` | **New** (Item 11) |

---

## Implementation order

```
Phase 1 (safe, no model risk):
  1.4 → 1.1 → 1.2 → 1.3 → 1.5

Phase 2 (add packages first, then behaviour):
  2.1 → 2.2 → 2.3

Phase 3 (all model changes land together in one commit):
  3.1 (Superset model + sequence + UI) → 3.2 (warmup) → 3.3 (end screen)
```

Phase 3 items should land in a single PR because the model changes are breaking — the Hive adapter version bump and migration wrapper must ship together with the UI.

---

## Open questions

- **Beep asset**: bundle a `.mp3` vs generate a tone programmatically? Bundling is simpler and avoids runtime synthesis.
- **Superset rest field in edit UI**: show rest on the last exercise card of the group, or on a group-level header row? Recommend group-level header to avoid ambiguity.
- **Warm-up logging**: should warm-up sets be included in session history? Suggested: no — they're prep, not working sets.