# Plan: Create Workout Feature

## Context
The Setup phase is complete (Riverpod, Hive, main.dart wired up). The Create Workout screen exists but is non-functional: ExerciseCard is display-only (no editable fields), the Exercise model is missing a weight field, and the WorkoutPreviewScreen has no save button — so workouts cannot be persisted. This plan finishes the Create Workout MVP tasks from the README.

---

## Step 0 — Mark Setup complete in README.md

In `README.md`, change the three Setup checkboxes from `[ ]` to `[x]`.

---

## Step 1 — Add `weight` field to Exercise model

**File:** `lib/domain/models/exercise.dart`

- Add `double weight` field (default `0.0`) to `Exercise`
- Update the constructor to include `weight`
- Update `generateSequence()` to pass `weight` through to each sequence item

**File:** `lib/domain/models/exercise_adapter.dart`

- In `write()`: append `writer.writeDouble(obj.weight)` after existing fields
- In `read()`: append `final weight = reader.readDouble()` and pass to constructor
- **Dev note:** Hive binary format is positional — existing stored data won't have this byte. During development, clear the box once via `Hive.deleteBoxFromDisk('workouts')` in `main()` (remove after first run).

---

## Step 2 — Convert ExerciseCard to editable StatefulWidget

**File:** `lib/presentation/create_workout.dart`

Convert `ExerciseCard` from `StatelessWidget` to `StatefulWidget`. Because `Exercise` has mutable fields, the card can mutate the object directly — no callback to parent needed.

**Changes in `ExerciseCard`:**

- Add `TextEditingController`s for: `name`, `reps`, `sets`, `restTime` (seconds), `weight`
- Initialize each controller from the exercise object in `initState()`
- Dispose all controllers in `dispose()`
- Replace the display `Text` widgets with `TextFormField`s:
  - `name` → full-width text field, `keyboardType: TextInputType.text`
  - `reps`, `sets` → compact numeric fields side-by-side, `keyboardType: TextInputType.number`
  - `restTime` → numeric field labeled "Rest (sec)", `keyboardType: TextInputType.number`
  - `weight` → numeric field labeled "Weight (kg)", `keyboardType: TextInputType.numberWithOptions(decimal: true)`
- Each `onChanged` updates the `exercise` field directly:
  ```dart
  onChanged: (v) => exercise.name = v,
  onChanged: (v) => exercise.reps = int.tryParse(v) ?? exercise.reps,
  onChanged: (v) => exercise.sets = int.tryParse(v) ?? exercise.sets,
  onChanged: (v) => exercise.restTime = Duration(seconds: int.tryParse(v) ?? exercise.restTime.inSeconds),
  onChanged: (v) => exercise.weight = double.tryParse(v) ?? exercise.weight,
  ```

**Changes in `_CreateWorkoutScreenState._submitWorkout()`:**

- Add validation: if any exercise has an empty name, show a `ScaffoldMessenger` snackbar and return early.
- Generate a unique workout ID: `DateTime.now().millisecondsSinceEpoch.toString()`

---

## Step 3 — Save workout from WorkoutPreviewScreen

**File:** `lib/presentation/create_workout.dart`

- Change `WorkoutPreviewScreen` from `StatelessWidget` to `ConsumerStatefulWidget` (Riverpod)
- Add a "Save Workout" `ElevatedButton` at the bottom
- On press:
  1. Call `ref.read(workoutRepositoryProvider).save(workout)`
  2. Show `ScaffoldMessenger` snackbar: "Workout saved!"
  3. Pop back to the create screen (`Navigator.pop`)
- Import `flutter_riverpod` and `workout_repository.dart`

---

## Verification

1. Run the app: `flutter run`
2. Tap "Add Exercise" — each card should show editable fields (name, reps, sets, rest, weight)
3. Fill in exercise details, enter a workout name, tap "Generate Workout"
4. Preview screen shows the sequence
5. Tap "Save Workout" — snackbar appears and screen pops
6. Confirm no crashes; hot-restart the app and verify the workout box persisted (can add a debug print in `workoutRepositoryProvider.getAll()`)
