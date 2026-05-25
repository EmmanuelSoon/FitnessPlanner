import 'exercise.dart';
import 'superset.dart';
import 'workout_slot.dart';

class Workout {
  final String id;
  final String name;
  final List<Superset> exercises; // each Superset is one exercise group (1–N exercises)
  final List<Exercise> warmup;   // pre-workout warm-up exercises (informational only)

  Workout({
    required this.id,
    required this.name,
    required this.exercises,
    List<Exercise>? warmup,
  }) : warmup = warmup ?? const [];

  /// Flat list of execution steps, including rest information.
  List<WorkoutSlot> generateWorkoutSlots() {
    final slots = <WorkoutSlot>[];
    for (int i = 0; i < exercises.length; i++) {
      slots.addAll(exercises[i].generateSlots(isLastInWorkout: i == exercises.length - 1));
    }
    return slots;
  }

  Duration get totalDuration {
    final slots = generateWorkoutSlots();
    Duration total = Duration.zero;
    for (final slot in slots) {
      total += const Duration(seconds: 30); // ~30s per set
      total += slot.restAfter;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((s) => s.toJson()).toList(),
    'warmup': warmup.map((e) => e.toJson()).toList(),
  };

  factory Workout.fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List? ?? [];
    List<Superset> supersets;

    if (exercisesJson.isEmpty) {
      supersets = [];
    } else {
      final first = exercisesJson.first as Map<String, dynamic>;
      if (first.containsKey('exercises')) {
        // ── New superset format ──────────────────────────────────────────
        supersets = exercisesJson
            .map((e) => Superset.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // ── Legacy Exercise format — migrate to single-exercise Supersets ─
        supersets = exercisesJson.map((e) {
          final exJson = e as Map<String, dynamic>;
          final legacySets = exJson['sets'] as int? ?? 3;
          final legacyRestMicros =
              exJson['restTimeMicroseconds'] as int? ?? 60000000;
          final exercise = Exercise.fromJson(exJson);
          return Superset(
            id: '${exercise.name}_${DateTime.now().microsecondsSinceEpoch}',
            exercises: [exercise],
            sets: legacySets,
            restAfterSet: Duration(microseconds: legacyRestMicros),
          );
        }).toList();
      }
    }

    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      exercises: supersets,
      warmup: (json['warmup'] as List? ?? [])
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
