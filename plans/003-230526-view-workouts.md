# View Workouts Feature

## Context
The Create Workout flow was implemented in the previous PR. The app currently launches directly into `CreateWorkoutScreen` and there is no way to view, edit, or delete saved workouts. Additionally, `main.dart` calls `Hive.deleteBoxFromDisk('workouts')` on every launch, wiping all saved data. This feature adds a workout list as the home screen and hooks up edit/delete.

---

## Files to Create

### `lib/providers/workout_providers.dart`
Add a reactive `AsyncNotifier` that wraps the repository:

```dart
final workoutsProvider =
    AsyncNotifierProvider<WorkoutsNotifier, List<Workout>>(WorkoutsNotifier.new);

class WorkoutsNotifier extends AsyncNotifier<List<Workout>> {
  @override
  Future<List<Workout>> build() async => ref.read(workoutRepositoryProvider).getAll();

  Future<void> saveWorkout(Workout workout) async {
    await ref.read(workoutRepositoryProvider).save(workout);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteWorkout(String id) async {
    await ref.read(workoutRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}
```

### `lib/presentation/workout_list_screen.dart`
`ConsumerWidget`. Uses `ref.watch(workoutsProvider).when(...)`.

**Layout:**
- `AppBar`: "My Workouts"
- FAB (`Icons.add`) → `Navigator.push(CreateWorkoutScreen())`
- `loading` → centered `CircularProgressIndicator`
- `error` → error text
- empty data → `_EmptyState` (icon + "No workouts yet" + "Create your first workout" button)
- populated data → `ListView.builder` of workout cards

**Workout card shows:** name (headline), exercise count, total duration in minutes

**Edit:** trailing edit icon → `Navigator.push(CreateWorkoutScreen(existingWorkout: workout))`

**Delete:** trailing delete icon → `AlertDialog` confirmation → `ref.read(workoutsProvider.notifier).deleteWorkout(workout.id)`

No explicit refresh needed after navigation — `ref.invalidateSelf()` in the notifier auto-rebuilds `ref.watch(workoutsProvider)`.

---

## Files to Modify

### `lib/main.dart`
1. Remove `await Hive.deleteBoxFromDisk('workouts');` (wipes data on every launch)
2. Change `home: const CreateWorkoutScreen()` → `home: const WorkoutListScreen()`
3. Add import for `workout_list_screen.dart`

### `lib/presentation/create_workout.dart`

**`CreateWorkoutScreen`:**
- Add `final Workout? existingWorkout;` constructor param (null = create, non-null = edit)
- In `initState`, pre-populate `_workoutName` and deep-copy exercises when `existingWorkout != null`
  - Deep copy is required — `ExerciseCard` mutates `Exercise` in-place; without copying you'd corrupt the Hive-cached object before save
- Add `initialValue: _workoutName` to the name `TextFormField`
- Update `_submitWorkout`: preserve existing id in edit mode → `id: widget.existingWorkout?.id ?? DateTime.now().millisecondsSinceEpoch.toString()`
- Post-save routing: in edit mode, pop back; in create mode, reset form
- Update `AppBar` title: "Create Workout" vs "Edit Workout"

**`WorkoutPreviewScreen._saveWorkout`:**
- Change from `ref.read(workoutRepositoryProvider).save(...)` to `ref.read(workoutsProvider.notifier).saveWorkout(...)` so the list auto-refreshes
- Add import for `workout_providers.dart`

---

## Implementation Order
1. `lib/providers/workout_providers.dart` — no deps on new screens
2. Modify `lib/presentation/create_workout.dart` — add edit support + notifier call in Preview
3. Create `lib/presentation/workout_list_screen.dart` — depends on notifier + updated CreateWorkoutScreen
4. Modify `lib/main.dart` — depends on WorkoutListScreen existing

---

## Verification
1. Run the app — home screen shows empty state
2. Tap FAB → create a workout → save → list shows one card with name, exercise count, duration
3. Restart app — workout persists (Hive delete line removed)
4. Tap edit icon on a card → form pre-filled → change name → save → list reflects new name
5. Tap delete icon → confirm → card removed from list
6. Tap edit icon → back button → no changes saved
