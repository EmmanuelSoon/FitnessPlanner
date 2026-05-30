# Supersets
**Date:** 25 May 2026  
**Source:** User feedback round 1 (Item 10)

---

## Overview

Add superset support to the workout model and session flow. A superset groups two or more exercises that are performed back-to-back with no rest between them; rest only fires after the last exercise of each set of the group.

---

## Model changes

### New model: `Superset`

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

### Sequence generation

```dart
// Superset.generateSlots() — returns flat list of execution slots
// For 3 sets of [Bench, Fly] with 90s rest:
//   Bench(s1) → Fly(s1) → REST 90s → Bench(s2) → Fly(s2) → REST 90s → Bench(s3) → Fly(s3)
```

Between exercises within the same set of a superset: no rest, just an "intra-group next" label.  
Rest only fires after the last exercise of each set (except the final set of the workout).

---

## UI changes

### CreateWorkout (`lib/presentation/create_workout.dart`)

Add a "group with next exercise" toggle on each exercise card. When enabled:
- A vertical accent bar visually connects the cards.
- The REST field is hidden on intermediate cards (rest lives at the `Superset` level, shown on the last exercise of the group).

> **Open question:** Show rest on the last exercise card of the group, or on a group-level header row? Recommend group-level header to avoid ambiguity.

### WorkoutSessionScreen (`lib/presentation/workout_session_screen.dart`)

During a superset, replace the rest timer between intra-group exercises with an instant "→ Next: [exercise]" transition.

### WorkoutPreview

Show supersets with a bracket / grouping indicator and a shared set count.

---

## File changes

| File | Change |
|---|---|
| `lib/domain/models/exercise.dart` | Remove `sets`, `restTime` → moved to `Superset`; add `timedDuration` field |
| `lib/domain/models/exercise_adapter.dart` | Version bump |
| `lib/domain/models/superset.dart` | **New** |
| `lib/domain/models/superset_adapter.dart` | **New** Hive adapter |
| `lib/domain/models/workout.dart` | `exercises` → `List<Superset>` |
| `lib/domain/models/workout_adapter.dart` | Version bump + migration fallback |
| `lib/presentation/workout_session_screen.dart` | Intra-superset transition, no mid-group rest |
| `lib/presentation/create_workout.dart` | "Group with next" toggle, accent bar, group-level rest field |

---

## Implementation order

All model changes must land in a single commit/PR — the Hive adapter version bump and migration wrapper must ship together with the UI.

```
superset.dart + superset_adapter.dart (new model)
→ exercise.dart / workout.dart (field changes + migration)
→ create_workout.dart (group toggle UI)
→ workout_session_screen.dart (intra-group transition)
→ workout_preview (grouping indicator)
```

---

## Open questions

- **Rest field placement in edit UI:** show rest on the last exercise card of the group, or on a group-level header row? Recommend group-level header to avoid ambiguity.
