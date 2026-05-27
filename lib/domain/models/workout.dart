import 'exercise.dart';
import 'superset.dart';

class Workout {
  final String id;
  final String name;
  final List<Superset> exercises; // list of exercise groups (each ≥1 exercise)
  final List<Exercise> warmup;

  Workout({
    required this.id,
    required this.name,
    required this.exercises,
    List<Exercise>? warmup,
  }) : warmup = warmup ?? [];

  /// Flat ordered slot list used by the session screen and warm-up screen.
  List<Exercise> generateWorkoutSequence() {
    return exercises.expand((s) => s.generateSlots()).toList();
  }

  Duration get totalDuration {
    final sequence = generateWorkoutSequence();
    Duration total = Duration.zero;
    for (int i = 0; i < sequence.length; i++) {
      total += const Duration(seconds: 30);
      if (i < sequence.length - 1) total += sequence[i].restTime;
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
    final rawExercises = (json['exercises'] as List?) ?? [];
    List<Superset> exercises;

    if (rawExercises.isEmpty) {
      exercises = [];
    } else {
      final first = rawExercises.first as Map<String, dynamic>;
      if (first.containsKey('exercises')) {
        // New format: list of Superset JSON objects.
        exercises = rawExercises
            .map((e) => Superset.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Legacy format: list of plain Exercise JSON objects.
        // Wrap each in a single-exercise Superset to preserve sets + restTime.
        exercises = rawExercises.map((e) {
          final ex = Exercise.fromJson(e as Map<String, dynamic>);
          return Superset.fromLegacyExercise(ex);
        }).toList();
      }
    }

    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      exercises: exercises,
      warmup: json['warmup'] != null
          ? (json['warmup'] as List)
              .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
