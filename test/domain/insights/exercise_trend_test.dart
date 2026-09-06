import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/exercise_trend.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

WorkoutSession _session({
  required String id,
  required DateTime startedAt,
  required List<LoggedSet> sets,
}) => WorkoutSession(
  id: id,
  workoutId: 'w1',
  workoutName: 'Push Day',
  startedAt: startedAt,
  endedAt: startedAt.add(const Duration(minutes: 45)),
  completed: true,
  sets: sets,
);

LoggedSet _weighted({
  String exerciseName = 'Bench Press',
  required double weight,
  double reps = 8,
  bool skipped = false,
}) => LoggedSet(
  exerciseName: exerciseName,
  targetReps: reps.round(),
  targetWeight: weight,
  actualReps: reps.round(),
  actualWeight: weight,
  skipped: skipped,
);

LoggedSet _bodyweight({
  String exerciseName = 'Pull-up',
  required int reps,
  bool skipped = false,
}) => LoggedSet(
  exerciseName: exerciseName,
  targetReps: reps,
  targetWeight: 0,
  actualReps: reps,
  actualWeight: 0,
  skipped: skipped,
);

LoggedSet _timed({
  String exerciseName = 'Plank',
  required int heldSeconds,
  bool skipped = false,
}) => LoggedSet(
  exerciseName: exerciseName,
  targetReps: 0,
  targetWeight: 0,
  actualReps: 0,
  actualWeight: 0,
  skipped: skipped,
  heldSeconds: heldSeconds,
  targetSeconds: heldSeconds,
);

void main() {
  group('computeExerciseTrend', () {
    test('returns no points when there are no sessions', () {
      expect(computeExerciseTrend([], 'Bench Press'), isEmpty);
    });

    test('ignores sessions where every set for the exercise was skipped', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 60, skipped: true)],
      );

      expect(computeExerciseTrend([session], 'Bench Press'), isEmpty);
    });

    test('weighted exercise: point is the heaviest performed set that session', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 60), _weighted(weight: 65), _weighted(weight: 62.5)],
      );

      final points = computeExerciseTrend([session], 'Bench Press');

      expect(points, hasLength(1));
      expect(points.single.value, 65);
      expect(points.single.unit, 'kg');
      expect(points.single.metricLabel, 'Top set');
      expect(points.single.date, DateTime(2026, 1, 5));
    });

    test('bodyweight exercise: point is the highest performed rep count that session', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_bodyweight(reps: 8), _bodyweight(reps: 11), _bodyweight(reps: 9)],
      );

      final points = computeExerciseTrend([session], 'Pull-up');

      expect(points.single.value, 11);
      expect(points.single.unit, 'reps');
      expect(points.single.metricLabel, 'Best set');
    });

    test('timed exercise: point is the longest performed hold that session', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_timed(heldSeconds: 90), _timed(heldSeconds: 120), _timed(heldSeconds: 100)],
      );

      final points = computeExerciseTrend([session], 'Plank');

      expect(points.single.value, 120);
      expect(points.single.unit, 's');
      expect(points.single.metricLabel, 'Longest hold');
    });

    test('only counts performed sets, skipping skipped ones, when picking the best', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 70, skipped: true), _weighted(weight: 60)],
      );

      expect(computeExerciseTrend([session], 'Bench Press').single.value, 60);
    });

    test('only includes sets matching the requested exercise name', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 65), _weighted(exerciseName: 'Squat', weight: 100)],
      );

      expect(computeExerciseTrend([session], 'Bench Press').single.value, 65);
    });

    test('returns one chronologically ordered point per session, regardless of input order', () {
      final older = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 60)],
      );
      final newer = _session(
        id: 's2',
        startedAt: DateTime(2026, 1, 12),
        sets: [_weighted(weight: 65)],
      );

      final points = computeExerciseTrend([newer, older], 'Bench Press');

      expect(points.map((p) => p.value).toList(), [60, 65]);
      expect(points.map((p) => p.date).toList(), [older.startedAt, newer.startedAt]);
    });
  });

  group('exerciseNamesLogged', () {
    test('returns no names when there are no sessions', () {
      expect(exerciseNamesLogged([]), isEmpty);
    });

    test('returns distinct names ordered by most recent use first', () {
      final older = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(exerciseName: 'Bench Press', weight: 60)],
      );
      final newer = _session(
        id: 's2',
        startedAt: DateTime(2026, 1, 12),
        sets: [
          _bodyweight(exerciseName: 'Pull-up', reps: 8),
          _weighted(exerciseName: 'Bench Press', weight: 65),
        ],
      );

      // Passed out of chronological order on purpose.
      final names = exerciseNamesLogged([older, newer]);

      expect(names, ['Pull-up', 'Bench Press']);
    });
  });
}
