import 'exercise.dart';

/// Returns the default 6-exercise warm-up (~5 min).
/// Call this factory to get a fresh, independent copy each time (fields are mutable).
List<Exercise> defaultWarmupExercises() => [
  Exercise(name: 'Jumping Jacks',               reps: 0, timedDuration: const Duration(seconds: 30)),
  Exercise(name: 'High Knees',                  reps: 0, timedDuration: const Duration(seconds: 30)),
  Exercise(name: 'Arm Circles',                 reps: 0, timedDuration: const Duration(seconds: 30)),
  Exercise(name: 'Cross-Body Shoulder Stretch', reps: 0, timedDuration: const Duration(seconds: 30)),
  Exercise(name: 'Standing Quad Stretch',       reps: 0, timedDuration: const Duration(seconds: 30)),
  Exercise(name: 'Standing Hamstring Stretch',  reps: 0, timedDuration: const Duration(seconds: 30)),
];
