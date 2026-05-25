import 'exercise.dart';
import 'workout_slot.dart';

/// A group of one or more exercises performed together for [sets] rounds.
/// A single-exercise Superset is a regular straight set; two or more is a
/// true superset (exercises performed back-to-back with no rest in between).
class Superset {
  String id;
  List<Exercise> exercises; // ≥ 1
  int sets;
  Duration restAfterSet; // rest only after the last exercise of each round

  Superset({
    required this.id,
    required this.exercises,
    required this.sets,
    required this.restAfterSet,
  });

  bool get isSuperset => exercises.length > 1;

  /// Flattens this superset into execution [WorkoutSlot]s.
  ///
  /// [isLastInWorkout] — when true the last slot gets no rest (the workout ends).
  List<WorkoutSlot> generateSlots({required bool isLastInWorkout}) {
    final slots = <WorkoutSlot>[];
    for (int setIdx = 0; setIdx < sets; setIdx++) {
      final isLastSet = setIdx == sets - 1;
      for (int exIdx = 0; exIdx < exercises.length; exIdx++) {
        final isLastEx = exIdx == exercises.length - 1;

        // Rest fires only after the last exercise of each set, except on the
        // very last set of the last superset in the workout.
        Duration rest;
        if (isLastEx) {
          rest = (isLastSet && isLastInWorkout)
              ? Duration.zero
              : restAfterSet;
        } else {
          rest = Duration.zero; // intra-superset: no rest between exercises
        }

        slots.add(WorkoutSlot(
          exercise: exercises[exIdx],
          setNum: setIdx + 1,
          totalSets: sets,
          restAfter: rest,
          supersetId: id,
          isIntraSuperset: isSuperset && !isLastEx,
        ));
      }
    }
    return slots;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'sets': sets,
    'restAfterSetMicroseconds': restAfterSet.inMicroseconds,
  };

  factory Superset.fromJson(Map<String, dynamic> json) => Superset(
    id: json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    exercises: (json['exercises'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
    sets: json['sets'] as int? ?? 3,
    restAfterSet: Duration(
      microseconds: json['restAfterSetMicroseconds'] as int? ?? 60000000,
    ),
  );
}
