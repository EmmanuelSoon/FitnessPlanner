import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

void main() {
  group('WorkoutSession JSON round-trip', () {
    test('round-trips a completed session with logged sets', () {
      final session = WorkoutSession(
        id: 's1',
        workoutId: 'w1',
        workoutName: 'Push Day',
        startedAt: DateTime(2026, 3, 1, 8, 0),
        endedAt: DateTime(2026, 3, 1, 8, 45),
        completed: true,
        sets: [
          LoggedSet(
            exerciseName: 'Bench',
            targetReps: 8,
            targetWeight: 60,
            actualReps: 8,
            actualWeight: 60,
            skipped: false,
          ),
        ],
      );

      final restored = WorkoutSession.fromJson(session.toJson());

      expect(restored.id, 's1');
      expect(restored.workoutId, 'w1');
      expect(restored.workoutName, 'Push Day');
      expect(restored.startedAt, session.startedAt);
      expect(restored.endedAt, session.endedAt);
      expect(restored.completed, isTrue);
      expect(restored.sets, hasLength(1));
      expect(restored.sets.first.exerciseName, 'Bench');
    });

    test('round-trips a session with no logged sets', () {
      final session = WorkoutSession(
        id: 's2',
        workoutId: 'w1',
        workoutName: 'Push Day',
        startedAt: DateTime(2026, 3, 1, 8, 0),
        endedAt: DateTime(2026, 3, 1, 8, 5),
        completed: false,
        sets: const [],
      );

      expect(WorkoutSession.fromJson(session.toJson()).sets, isEmpty);
    });
  });

  group('duration', () {
    test('is the difference between startedAt and endedAt', () {
      final session = WorkoutSession(
        id: 's1',
        workoutId: 'w1',
        workoutName: 'Push Day',
        startedAt: DateTime(2026, 3, 1, 8, 0),
        endedAt: DateTime(2026, 3, 1, 8, 45),
        completed: true,
        sets: const [],
      );

      expect(session.duration, const Duration(minutes: 45));
    });
  });
}
