import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';

void main() {
  Workout buildWorkout() => Workout(
        id: 'w1',
        name: 'Push Day',
        exercises: [
          Superset(
            exercises: [Exercise(name: 'Bench', reps: 8, sets: 1, restTime: Duration.zero, weight: 60)],
            sets: 3,
            restAfterSet: const Duration(seconds: 90),
          ),
        ],
        warmup: [
          Exercise(name: 'Arm Circles', reps: 0, sets: 1, restTime: Duration.zero, timedDuration: const Duration(seconds: 30)),
        ],
        icon: 'dumbbell',
      );

  group('JSON round-trip', () {
    test('round-trips the current (Superset list) format', () {
      final workout = buildWorkout();

      final restored = Workout.fromJson(workout.toJson());

      expect(restored.id, 'w1');
      expect(restored.name, 'Push Day');
      expect(restored.exercises, hasLength(1));
      expect(restored.exercises.first.exercises.first.name, 'Bench');
      expect(restored.warmup, hasLength(1));
      expect(restored.icon, 'dumbbell');
    });

    test('defaults warmup to an empty list and icon to null when omitted', () {
      final workout = Workout(id: 'w2', name: 'No warmup', exercises: []);

      final restored = Workout.fromJson(workout.toJson());

      expect(restored.warmup, isEmpty);
      expect(restored.icon, isNull);
    });

    test('reads the legacy plain-Exercise format by wrapping each in a single-exercise Superset', () {
      final legacyJson = {
        'id': 'w3',
        'name': 'Legacy Workout',
        'exercises': [
          {
            'name': 'Squat',
            'reps': 5,
            'sets': 4,
            'restTimeMicroseconds': const Duration(seconds: 120).inMicroseconds,
            'weight': 100.0,
          },
        ],
      };

      final restored = Workout.fromJson(legacyJson);

      expect(restored.exercises, hasLength(1));
      expect(restored.exercises.first.isSuperset, isFalse);
      expect(restored.exercises.first.exercises.first.name, 'Squat');
      expect(restored.exercises.first.sets, 4);
      expect(restored.exercises.first.restAfterSet, const Duration(seconds: 120));
    });

    test('handles an empty exercises list', () {
      final workout = Workout(id: 'w4', name: 'Empty', exercises: []);

      final restored = Workout.fromJson(workout.toJson());

      expect(restored.exercises, isEmpty);
    });
  });

  group('generateWorkoutSequence', () {
    test('flattens all supersets into one ordered slot list', () {
      final workout = Workout(
        id: 'w1',
        name: 'Full body',
        exercises: [
          Superset(
            exercises: [Exercise(name: 'Squat', reps: 5, sets: 1, restTime: Duration.zero)],
            sets: 2,
            restAfterSet: const Duration(seconds: 60),
          ),
          Superset(
            exercises: [Exercise(name: 'Row', reps: 8, sets: 1, restTime: Duration.zero)],
            sets: 1,
            restAfterSet: const Duration(seconds: 30),
          ),
        ],
      );

      final sequence = workout.generateWorkoutSequence();

      expect(sequence.map((e) => e.name), ['Squat', 'Squat', 'Row']);
    });
  });

  group('totalDuration', () {
    test('sums a fixed 30s per exercise plus rest time between exercises (none after the last)', () {
      final workout = Workout(
        id: 'w1',
        name: 'Two exercises',
        exercises: [
          Superset(
            exercises: [Exercise(name: 'A', reps: 5, sets: 1, restTime: Duration.zero)],
            sets: 2,
            restAfterSet: const Duration(seconds: 60),
          ),
        ],
      );

      // Sequence: A, A -> 2 slots, each with restTime 60s.
      // total = 30 + 30 (30s per exercise) + 60 (rest after the first slot only,
      // since the loop skips rest after the final slot)
      expect(workout.totalDuration, const Duration(minutes: 2));
    });
  });
}
