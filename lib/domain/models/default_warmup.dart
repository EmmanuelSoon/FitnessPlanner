import 'exercise.dart';

/// Default 6-exercise, ~5-minute warm-up applied to every new workout.
/// The user can remove or reorder exercises before saving.
List<Exercise> createDefaultWarmup() => [
  Exercise(
    name: 'Jumping Jacks',
    reps: 0,
    sets: 1,
    restTime: Duration.zero,
    timedDuration: const Duration(seconds: 30),
  ),
  Exercise(
    name: 'High Knees',
    reps: 0,
    sets: 1,
    restTime: Duration.zero,
    timedDuration: const Duration(seconds: 30),
  ),
  Exercise(
    name: 'Arm Circles',
    reps: 0,
    sets: 1,
    restTime: Duration.zero,
    timedDuration: const Duration(seconds: 30),
  ),
  Exercise(
    name: 'Cross-Body Shoulder Stretch',
    reps: 0,
    sets: 1,
    restTime: Duration.zero,
    timedDuration: const Duration(seconds: 30),
  ),
  Exercise(
    name: 'Standing Quad Stretch',
    reps: 0,
    sets: 1,
    restTime: Duration.zero,
    timedDuration: const Duration(seconds: 30),
  ),
  Exercise(
    name: 'Standing Hamstring Stretch',
    reps: 0,
    sets: 1,
    restTime: Duration.zero,
    timedDuration: const Duration(seconds: 30),
  ),
];
