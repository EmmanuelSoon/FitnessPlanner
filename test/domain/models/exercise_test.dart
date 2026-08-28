import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/exercise.dart';

void main() {
  group('Exercise JSON round-trip', () {
    test('round-trips a standard reps-based exercise', () {
      final exercise = Exercise(
        name: 'Bench Press',
        reps: 8,
        sets: 3,
        restTime: const Duration(seconds: 90),
        weight: 60.5,
      );

      final restored = Exercise.fromJson(exercise.toJson());

      expect(restored.name, exercise.name);
      expect(restored.reps, exercise.reps);
      expect(restored.sets, exercise.sets);
      expect(restored.restTime, exercise.restTime);
      expect(restored.weight, exercise.weight);
      expect(restored.timedDuration, isNull);
    });

    test('round-trips a bodyweight exercise with default zero weight', () {
      final exercise = Exercise(
        name: 'Push-Up',
        reps: 15,
        sets: 3,
        restTime: const Duration(seconds: 60),
      );

      final restored = Exercise.fromJson(exercise.toJson());

      expect(restored.weight, 0.0);
    });

    test('round-trips a timed exercise', () {
      final exercise = Exercise(
        name: 'Plank',
        reps: 0,
        sets: 1,
        restTime: Duration.zero,
        timedDuration: const Duration(seconds: 45),
      );

      final restored = Exercise.fromJson(exercise.toJson());

      expect(restored.timedDuration, const Duration(seconds: 45));
    });

    test('fromJson defaults weight to 0.0 when absent from the map', () {
      final json = {
        'name': 'Old Exercise',
        'reps': 10,
        'sets': 3,
        'restTimeMicroseconds': const Duration(seconds: 60).inMicroseconds,
      };

      expect(Exercise.fromJson(json).weight, 0.0);
    });
  });

  group('generateSequence', () {
    test('produces one single-set copy per set, preserving fields', () {
      final exercise = Exercise(
        name: 'Squat',
        reps: 5,
        sets: 3,
        restTime: const Duration(seconds: 120),
        weight: 100,
      );

      final sequence = exercise.generateSequence();

      expect(sequence, hasLength(3));
      for (final e in sequence) {
        expect(e.name, 'Squat');
        expect(e.reps, 5);
        expect(e.sets, 1);
        expect(e.restTime, const Duration(seconds: 120));
        expect(e.weight, 100);
      }
    });
  });
}
