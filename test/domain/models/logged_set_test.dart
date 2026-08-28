import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';

void main() {
  group('LoggedSet JSON round-trip', () {
    test('round-trips a completed reps-based set', () {
      final set = LoggedSet(
        exerciseName: 'Bench Press',
        targetReps: 8,
        targetWeight: 60,
        actualReps: 7,
        actualWeight: 62.5,
        skipped: false,
      );

      final restored = LoggedSet.fromJson(set.toJson());

      expect(restored.exerciseName, 'Bench Press');
      expect(restored.targetReps, 8);
      expect(restored.targetWeight, 60);
      expect(restored.actualReps, 7);
      expect(restored.actualWeight, 62.5);
      expect(restored.skipped, isFalse);
      expect(restored.heldSeconds, isNull);
      expect(restored.targetSeconds, isNull);
    });

    test('round-trips a skipped set', () {
      final set = LoggedSet(
        exerciseName: 'Squat',
        targetReps: 5,
        targetWeight: 100,
        actualReps: 0,
        actualWeight: 0,
        skipped: true,
      );

      expect(LoggedSet.fromJson(set.toJson()).skipped, isTrue);
    });

    test('round-trips a timed (held) set', () {
      final set = LoggedSet(
        exerciseName: 'Plank',
        targetReps: 0,
        targetWeight: 0,
        actualReps: 0,
        actualWeight: 0,
        skipped: false,
        heldSeconds: 42,
        targetSeconds: 45,
      );

      final restored = LoggedSet.fromJson(set.toJson());

      expect(restored.heldSeconds, 42);
      expect(restored.targetSeconds, 45);
    });
  });
}
