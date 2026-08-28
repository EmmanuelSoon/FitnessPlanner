import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';

void main() {
  group('Superset JSON round-trip', () {
    test('round-trips a single-exercise superset', () {
      final superset = Superset(
        id: 's1',
        exercises: [
          Exercise(name: 'Squat', reps: 5, sets: 1, restTime: Duration.zero, weight: 100),
        ],
        sets: 3,
        restAfterSet: const Duration(seconds: 120),
      );

      final restored = Superset.fromJson(superset.toJson());

      expect(restored.id, 's1');
      expect(restored.exercises, hasLength(1));
      expect(restored.exercises.first.name, 'Squat');
      expect(restored.sets, 3);
      expect(restored.restAfterSet, const Duration(seconds: 120));
      expect(restored.isSuperset, isFalse);
    });

    test('round-trips a multi-exercise superset', () {
      final superset = Superset(
        exercises: [
          Exercise(name: 'Bench', reps: 8, sets: 1, restTime: Duration.zero),
          Exercise(name: 'Fly', reps: 12, sets: 1, restTime: Duration.zero),
        ],
        sets: 3,
        restAfterSet: const Duration(seconds: 90),
      );

      final restored = Superset.fromJson(superset.toJson());

      expect(restored.exercises.map((e) => e.name), ['Bench', 'Fly']);
      expect(restored.isSuperset, isTrue);
    });

    test('generates a random id when none is supplied', () {
      final superset = Superset(
        exercises: [Exercise(name: 'Row', reps: 8, sets: 1, restTime: Duration.zero)],
        sets: 1,
        restAfterSet: Duration.zero,
      );

      expect(superset.id, isNotEmpty);
    });
  });

  group('generateSlots', () {
    test('single exercise: every round gets restAfterSet', () {
      final superset = Superset(
        exercises: [Exercise(name: 'Squat', reps: 5, sets: 1, restTime: Duration.zero, weight: 100)],
        sets: 3,
        restAfterSet: const Duration(seconds: 120),
      );

      final slots = superset.generateSlots();

      expect(slots, hasLength(3));
      for (final slot in slots) {
        expect(slot.name, 'Squat');
        expect(slot.restTime, const Duration(seconds: 120));
      }
    });

    test('multi-exercise superset: only the last exercise in each round rests', () {
      final superset = Superset(
        exercises: [
          Exercise(name: 'Bench', reps: 8, sets: 1, restTime: Duration.zero),
          Exercise(name: 'Fly', reps: 12, sets: 1, restTime: Duration.zero),
        ],
        sets: 2,
        restAfterSet: const Duration(seconds: 90),
      );

      final slots = superset.generateSlots();

      expect(slots.map((e) => e.name), ['Bench', 'Fly', 'Bench', 'Fly']);
      expect(slots[0].restTime, Duration.zero);
      expect(slots[1].restTime, const Duration(seconds: 90));
      expect(slots[2].restTime, Duration.zero);
      expect(slots[3].restTime, const Duration(seconds: 90));
    });
  });

  group('fromLegacyExercise', () {
    test('wraps a legacy Exercise, moving its sets/restTime onto the Superset', () {
      final legacy = Exercise(
        name: 'Deadlift',
        reps: 5,
        sets: 4,
        restTime: const Duration(seconds: 150),
        weight: 140,
      );

      final superset = Superset.fromLegacyExercise(legacy);

      expect(superset.exercises, [legacy]);
      expect(superset.sets, 4);
      expect(superset.restAfterSet, const Duration(seconds: 150));
    });
  });
}
