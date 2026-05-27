# MVP Setup Plan

## Context

The app currently has domain models and a CreateWorkoutScreen but main.dart is still the default Flutter counter app. Nothing is wired together, there is no state management, and no persistence layer. This plan sets up that foundational infrastructure so the app is launchable and ready for feature work.

Libraries chosen: **flutter_riverpod** (state management) + **hive_flutter** (local persistence).

---

## Files to Create

| File | Purpose |
|---|---|
| `lib/domain/models/exercise_adapter.dart` | Hive TypeAdapter for Exercise (typeId: 0) |
| `lib/domain/models/workout_adapter.dart` | Hive TypeAdapter for Workout (typeId: 1) |
| `lib/data/workout_repository.dart` | Hive-backed CRUD repo + Riverpod provider |

## Files to Modify

| File | Change |
|---|---|
| `pubspec.yaml` | Add `flutter_riverpod: ^2.6.1` and `hive_flutter: ^1.1.0` |
| `lib/domain/models/workout.dart` | Add `id` field; remove unused `flutter/material.dart` + `flutter/foundation.dart` imports |
| `lib/main.dart` | Full replacement — Hive init, register adapters, open box, ProviderScope, home → CreateWorkoutScreen |

---

## Step-by-Step Implementation

### 1. pubspec.yaml — add dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.6.1
  hive_flutter: ^1.1.0
```

Run `flutter pub get` after saving.

### 2. workout.dart — add id, fix imports

- Remove `import 'package:flutter/material.dart'` and `import 'package:flutter/foundation.dart'` (both unused)
- Add `final String id` as a required field
- Keep `generateWorkoutSequence()` and `totalDuration` unchanged

### 3. exercise_adapter.dart

Manual `TypeAdapter<Exercise>` with `typeId = 0`.

Duration stored as `int` microseconds (read: `Duration(microseconds: v)`, write: `obj.restTime.inMicroseconds`).

Field write order: name (String), reps (int), sets (int), restTime as microseconds (int).

### 4. workout_adapter.dart

Manual `TypeAdapter<Workout>` with `typeId = 1`.

Write exercises list as: count (int) then each exercise via `ExerciseAdapter` directly (no separate box/registration).

Field write order: id (String), name (String), exercise count (int), then each exercise.

### 5. workout_repository.dart

```dart
class WorkoutRepository {
  final Box<Workout> _box;
  WorkoutRepository(this._box);

  List<Workout> getAll() => _box.values.toList();
  Future<void> save(Workout workout) => _box.put(workout.id, workout);
  Future<void> delete(String id) => _box.delete(id);
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Hive.box<Workout>('workouts'));
});
```

Box name `'workouts'` is used here and in main.dart — must match exactly.

### 6. main.dart — full replacement

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ExerciseAdapter());  // typeId 0 — must be before WorkoutAdapter
  Hive.registerAdapter(WorkoutAdapter());   // typeId 1
  await Hive.openBox<Workout>('workouts');

  runApp(const ProviderScope(child: FitnessPlannerApp()));
}

class FitnessPlannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Planner',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const CreateWorkoutScreen(),
    );
  }
}
```

### 7. Fix compile error in create_workout.dart

Adding `id` as required to `Workout` will break `_submitWorkout()`. Add a temporary placeholder to keep the app runnable:

```dart
final workout = Workout(id: '', name: _workoutName, exercises: _exercises);
```

This is intentional — the Create Workout section will replace this with a proper repository save call.

---

## Verification

1. `flutter analyze` — zero errors
2. `flutter run` — app launches to CreateWorkoutScreen with no crash
3. No "ProviderScope not found" errors in debug console
4. Hot restart works — Hive box re-opens cleanly
