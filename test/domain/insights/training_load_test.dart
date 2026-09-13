import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/training_load.dart';
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

LoggedSet _set({
  required String exerciseName,
  String? category,
  bool skipped = false,
}) => LoggedSet(
  exerciseName: exerciseName,
  targetReps: 8,
  targetWeight: 60,
  actualReps: 8,
  actualWeight: 60,
  skipped: skipped,
  category: category,
);

void main() {
  group('resolveCategory', () {
    test('uses the set\'s own category when it was manually tagged', () {
      final set = _set(exerciseName: 'Some Custom Move', category: 'Arms');

      expect(resolveCategory(set), 'Arms');
    });

    test('falls back to a library lookup by exact name when untagged', () {
      final set = _set(exerciseName: 'Bench Press');

      expect(resolveCategory(set), 'Chest');
    });

    test('library lookup ignores case', () {
      final set = _set(exerciseName: 'bench press');

      expect(resolveCategory(set), 'Chest');
    });

    test('library lookup ignores punctuation and spacing, but never fuzzy-matches to a different exercise', () {
      final set = _set(exerciseName: 'Close-Grip Bench Press');

      expect(resolveCategory(set), 'Arms');
    });

    test('falls back to "Other" when untagged and not found in the library', () {
      final set = _set(exerciseName: 'Some Custom Move');

      expect(resolveCategory(set), 'Other');
    });
  });

  group('unmatchedExerciseNames', () {
    test('returns no names when there are no sessions', () {
      expect(unmatchedExerciseNames([]), isEmpty);
    });

    test('returns no names when every set is either tagged or library-matched', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [
          _set(exerciseName: 'Bench Press'),
          _set(exerciseName: 'Some Custom Move', category: 'Arms'),
        ],
      );

      expect(unmatchedExerciseNames([session]), isEmpty);
    });

    test('returns the name of a set that falls through to "Other"', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_set(exerciseName: 'Some Custom Move')],
      );

      expect(unmatchedExerciseNames([session]), {'Some Custom Move'});
    });

    test('does not flag a set the user deliberately tagged "Other"', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_set(exerciseName: 'Some Custom Move', category: 'Other')],
      );

      expect(unmatchedExerciseNames([session]), isEmpty);
    });

    test('de-duplicates the same unmatched name across sessions', () {
      final s1 = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_set(exerciseName: 'Some Custom Move')],
      );
      final s2 = _session(
        id: 's2',
        startedAt: DateTime(2026, 1, 12),
        sets: [_set(exerciseName: 'Some Custom Move')],
      );

      expect(unmatchedExerciseNames([s1, s2]), {'Some Custom Move'});
    });
  });
}
