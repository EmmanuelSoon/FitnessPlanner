import 'exercise.dart';

/// Groups one or more exercises performed back-to-back with a shared set count
/// and a single rest period that fires only after the last exercise of each round.
///
/// A single-exercise [Superset] is behaviourally identical to the old Exercise
/// model (sets + restAfterSet replace the former Exercise.sets + Exercise.restTime).
class Superset {
  String id;
  List<Exercise> exercises; // ≥1
  int sets;
  Duration restAfterSet; // fires after the last exercise of each round

  Superset({
    String? id,
    required this.exercises,
    required this.sets,
    required this.restAfterSet,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  bool get isSuperset => exercises.length > 1;

  /// Returns the flat list of execution slots for the session screen.
  ///
  /// For each round, every exercise except the last gets [restTime] = zero
  /// (instant intra-superset transition). The last exercise in each round
  /// gets [restAfterSet].
  ///
  /// Example — 3 sets of [Bench, Fly] with 90 s rest:
  ///   Bench(rest=0) → Fly(rest=90s) → Bench(rest=0) → Fly(rest=90s) → …
  List<Exercise> generateSlots() {
    final result = <Exercise>[];
    for (int round = 0; round < sets; round++) {
      for (int i = 0; i < exercises.length; i++) {
        final isLastInRound = i == exercises.length - 1;
        result.add(Exercise(
          name: exercises[i].name,
          reps: exercises[i].reps,
          sets: 1,
          restTime: isLastInRound ? restAfterSet : Duration.zero,
          weight: exercises[i].weight,
          timedDuration: exercises[i].timedDuration,
        ));
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'sets': sets,
        'restAfterSetMicroseconds': restAfterSet.inMicroseconds,
      };

  factory Superset.fromJson(Map<String, dynamic> json) => Superset(
        id: json['id'] as String?,
        exercises: (json['exercises'] as List)
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        sets: json['sets'] as int,
        restAfterSet: Duration(
            microseconds: json['restAfterSetMicroseconds'] as int),
      );

  /// Migration helper: wraps a legacy [Exercise] (which carried its own
  /// `sets` and `restTime` fields) in a single-exercise [Superset].
  factory Superset.fromLegacyExercise(Exercise e) => Superset(
        exercises: [e],
        sets: e.sets,
        restAfterSet: e.restTime,
      );
}
