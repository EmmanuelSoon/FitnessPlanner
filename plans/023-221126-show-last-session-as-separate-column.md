# 023 — Show last-session reps/weight as a separate column instead of overriding edits

## Bug

Reported: editing a workout's reps/sets, saving, going back to the homepage,
and opening that workout again shows the *previous* reps/weight instead of
the edit just made.

## Root cause

The save path is correct — `CreateWorkoutScreen` → `WorkoutsNotifier.saveWorkout`
→ `WorkoutRepository.save` (`lib/data/workout_repository.dart:14`) writes the
edited `Workout` to Hive keyed by `workout.id`, and `workoutsProvider` refreshes
fine.

The bug is in `WorkoutStartPreviewScreen` (`lib/presentation/workout_start_preview_screen.dart:39-78`),
which opens when you tap a workout from the homepage. It looks up the most
recent logged `WorkoutSession` for that workout, and for every exercise
matched by name, overrides the exercise's `reps`/`weight` with the
*previously logged actual values*, falling back to the template only when no
prior session exists:

```dart
reps: last?.actualReps ?? e.reps,
weight: last?.actualWeight ?? e.weight,
```

This is intentional "prefill from last time" behavior (added in #36), but it
silently discards template edits for any exercise that was already logged in
a previous session — making a successful edit look like it didn't save.

## Fix

Stop overriding the editable fields. Add the last session's values as their
own read-only column instead, so both numbers are visible and the editable
fields always default to the (possibly just-edited) template.

1. In `_WorkoutStartPreviewScreenState.initState`, build `_exercises` straight
   from `widget.workout.exercises` (template `reps`/`weight`, no `lastSetFor`
   override). Keep a separate `Map<String, LoggedSet>` (or equivalent lookup)
   from exercise name → most recent `LoggedSet`, for display only.
2. Thread that lookup into `_PreviewExerciseCard` (e.g. a nullable
   `lastSet: LoggedSet?` param per exercise).
3. Add a new read-only column, styled like the existing `_ReadOnlyField`,
   labeled `LAST TIME`, rendered only when `lastSet != null`:
   - Non-timed exercise: value is `'${lastSet.actualReps} × ${fmtWeight(lastSet.actualWeight)}kg'`.
   - Timed exercise: value is `'${lastSet.heldSeconds}s'` if `heldSeconds` is
     present, otherwise omit the column for that exercise.
   Placed after the WEIGHT field, before REST, in the same field `Row`.
4. No change to `sets` — that value already comes from the template and was
   never overridden.

## Files touched

- `lib/presentation/workout_start_preview_screen.dart` — remove the
  `lastSetFor`-based override in `initState`; keep the lookup for display;
  add the `LAST TIME` read-only column to `_PreviewExerciseCard`.
- `test/widgets/workout_start_preview_screen_test.dart` — update/replace the
  existing "prefills reps/weight from the most recent prior session" test
  (which currently asserts the override) with a new test asserting the
  editable fields show the *template* values even when a prior session with
  different actuals exists, plus a new test asserting the `LAST TIME` column
  renders the prior session's actual values alongside it.

## Test plan (TDD — behavior change)

1. Update the fixture session in the "prefill" test so the prior session's
   actuals genuinely differ from the template (today's fixture happens to
   match template values, which doesn't exercise the distinction).
2. Write a failing test: with a prior session logging different reps/weight
   than the template, the screen shows the *template* values in the
   editable REPS/WEIGHT fields (not the session's actuals).
3. Write a failing test: the same screen also shows a `LAST TIME` column
   with the prior session's actual reps/weight.
4. Write a failing test: with no prior session, no `LAST TIME` column is
   rendered for that exercise.
5. Confirm all three fail against current code.
6. Implement the changes in `workout_start_preview_screen.dart`.
7. Confirm tests pass; run full `flutter test` and `flutter analyze`.

## Non-goals

- Not changing `WorkoutSessionScreen`, `WarmupScreen`, or how sessions are
  logged — only how the pre-start preview screen displays prior data.
- Not adding a "last time" column for `sets` or `rest` — those were never
  overridden and aren't part of the reported bug.
