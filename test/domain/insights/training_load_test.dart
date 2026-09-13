import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/training_load.dart';
import 'package:fitness_planner/domain/insights/volume_stats.dart' show weekStartOf;
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
  int? heldSeconds,
}) => LoggedSet(
  exerciseName: exerciseName,
  targetReps: heldSeconds != null ? 0 : 8,
  targetWeight: 60,
  actualReps: heldSeconds != null ? 0 : 8,
  actualWeight: 60,
  skipped: skipped,
  heldSeconds: heldSeconds,
  category: category,
);

// A Monday-aligned anchor so week arithmetic below never depends on knowing
// which weekday a given calendar date actually falls on.
final _week0 = weekStartOf(DateTime(2026, 1, 5));
DateTime _week(int n) => _week0.add(Duration(days: 7 * n));

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

    test('does not flag a skipped set, matching every other insights aggregator', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_set(exerciseName: 'Some Custom Move', skipped: true)],
      );

      expect(unmatchedExerciseNames([session]), isEmpty);
    });
  });

  group('weeklyTrainingLoad', () {
    test('returns one WeekLoad per requested week, oldest first', () {
      final loads = weeklyTrainingLoad([], weeks: 3, now: _week(2));

      expect(loads.map((w) => w.weekStart), [_week(0), _week(1), _week(2)]);
    });

    test('counts a performed set toward its resolved category\'s workingSets', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Bench Press')],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.byCategory['Chest']!.workingSets, 1);
    });

    test('excludes a timed (held) set from workingSets', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Plank', heldSeconds: 30)],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.byCategory['Core']!.workingSets, 0);
    });

    test('counts a timed (held) set toward timedSets', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Plank', heldSeconds: 30)],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.byCategory['Core']!.timedSets, 1);
    });

    test('excludes a skipped set entirely', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Bench Press', skipped: true)],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.byCategory, isEmpty);
    });

    test('exerciseCount counts a repeated exercise once', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Bench Press'), _set(exerciseName: 'Bench Press')],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.byCategory['Chest']!.exerciseCount, 1);
    });

    test('exerciseCount counts two different exercises in the same category separately', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Bench Press'), _set(exerciseName: 'Push-Up')],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.byCategory['Chest']!.exerciseCount, 2);
    });

    test('totalWorkingSets sums working sets across every category', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Bench Press'), _set(exerciseName: 'Squat')],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.totalWorkingSets, 2);
    });

    test('sessionCount counts sessions, not sets', () {
      final session = _session(
        id: 's1',
        startedAt: _week(0),
        sets: [_set(exerciseName: 'Bench Press'), _set(exerciseName: 'Bench Press')],
      );

      final loads = weeklyTrainingLoad([session], weeks: 1, now: _week(0));

      expect(loads.single.sessionCount, 1);
    });

    test('a week with no sessions is included with zero figures rather than omitted', () {
      final loads = weeklyTrainingLoad([], weeks: 1, now: _week(0));

      expect(loads.single.totalWorkingSets, 0);
    });

    test('only the week containing "now" is marked partial', () {
      final loads = weeklyTrainingLoad([], weeks: 2, now: _week(1).add(const Duration(days: 2)));

      expect(loads.map((w) => w.isPartial), [false, true]);
    });
  });

  group('compareToTrailing', () {
    test('reports unknown for a category with fewer than two completed prior weeks', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.band, LoadBand.unknown);
    });

    test('leaves trailingMean null when the band is unknown', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.trailingMean, isNull);
    });

    test('excludes the current partial week from the trailing mean', () {
      final weeks = [
        _weekLoadFor('Legs', 10, weekStart: _week(0)),
        _weekLoadFor('Legs', 10, weekStart: _week(1)),
        _weekLoadFor('Legs', 100, weekStart: _week(2), isPartial: true),
      ];

      final comparisons = compareToTrailing(weeks);

      expect(comparisons.single.trailingMean, 10);
    });

    test('uses only the most recent trailingWeeks completed weeks for the mean', () {
      final weeks = [
        _weekLoadFor('Legs', 4, weekStart: _week(0)),
        _weekLoadFor('Legs', 8, weekStart: _week(1)),
        _weekLoadFor('Legs', 8, weekStart: _week(2)),
        _weekLoadFor('Legs', 8, weekStart: _week(3)),
        _weekLoadFor('Legs', 8, weekStart: _week(4)),
        _weekLoadFor('Legs', 999, weekStart: _week(5), isPartial: true),
      ];

      final comparisons = compareToTrailing(weeks, trailingWeeks: 4);

      expect(comparisons.single.trailingMean, 8);
    });

    test('a current value exactly 25% below the trailing mean is still typical', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0)),
        _weekLoadFor('Legs', 16, weekStart: _week(1)),
        _weekLoadFor('Legs', 12, weekStart: _week(2), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.band, LoadBand.typical);
    });

    test('a current value just below the 25%-under threshold is light', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0)),
        _weekLoadFor('Legs', 16, weekStart: _week(1)),
        _weekLoadFor('Legs', 11, weekStart: _week(2), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.band, LoadBand.light);
    });

    test('a current value exactly 25% above the trailing mean is still typical', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0)),
        _weekLoadFor('Legs', 16, weekStart: _week(1)),
        _weekLoadFor('Legs', 20, weekStart: _week(2), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.band, LoadBand.typical);
    });

    test('a current value just above the 25%-over threshold is heavy', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0)),
        _weekLoadFor('Legs', 16, weekStart: _week(1)),
        _weekLoadFor('Legs', 21, weekStart: _week(2), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.band, LoadBand.heavy);
    });

    test('the comparison\'s workingSets reflects the current week\'s count', () {
      final weeks = [
        _weekLoadFor('Legs', 16, weekStart: _week(0)),
        _weekLoadFor('Legs', 16, weekStart: _week(1)),
        _weekLoadFor('Legs', 21, weekStart: _week(2), isPartial: true),
      ];

      expect(compareToTrailing(weeks).single.workingSets, 21);
    });

    test('includes a category trained in trailing weeks even if untouched this week', () {
      final weeks = [
        _weekLoadFor('Back', 16, weekStart: _week(0)),
        _weekLoadFor('Back', 16, weekStart: _week(1)),
        WeekLoad(weekStart: _week(2), byCategory: const {}, totalWorkingSets: 0, sessionCount: 1, isPartial: true),
      ];

      final comparisons = compareToTrailing(weeks);

      expect(comparisons.single.workingSets, 0);
    });
  });
}

WeekLoad _weekLoadFor(
  String category,
  int workingSets, {
  required DateTime weekStart,
  bool isPartial = false,
}) => WeekLoad(
  weekStart: weekStart,
  byCategory: {
    category: CategoryLoad(category: category, workingSets: workingSets, timedSets: 0, exerciseCount: 1),
  },
  totalWorkingSets: workingSets,
  sessionCount: 1,
  isPartial: isPartial,
);
