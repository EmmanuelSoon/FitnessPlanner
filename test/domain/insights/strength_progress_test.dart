import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/strength_progress.dart';
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

LoggedSet _weighted({
  String exerciseName = 'Bench Press',
  required double weight,
  int reps = 8,
  bool skipped = false,
}) => LoggedSet(
  exerciseName: exerciseName,
  targetReps: reps,
  targetWeight: weight,
  actualReps: reps,
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

LiftSessionPoint _point(
  DateTime date,
  double value, {
  double? best,
  int setsCounted = 3,
  int setsPerformed = 3,
  LiftMetric metric = LiftMetric.estimatedOneRm,
  String sessionId = 's',
}) => LiftSessionPoint(
  date: date,
  sessionId: sessionId,
  value: value,
  best: best ?? value,
  setsCounted: setsCounted,
  setsPerformed: setsPerformed,
  metric: metric,
);

void main() {
  group('metricFor', () {
    test('classifies as holdSeconds when any performed set was timed', () {
      expect(metricFor([_timed(heldSeconds: 60)]), LiftMetric.holdSeconds);
    });

    test('classifies as estimatedOneRm when any performed set carried weight', () {
      expect(metricFor([_weighted(weight: 60)]), LiftMetric.estimatedOneRm);
    });

    test('classifies as repsPerSet when no set carried weight or a hold', () {
      expect(metricFor([_bodyweight(reps: 10)]), LiftMetric.repsPerSet);
    });
  });

  group('allLiftSeries', () {
    test('a single set becomes a point equal to that set\'s value', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 100, reps: 5)],
      );

      final series = allLiftSeries([session]);

      expect(series['Bench Press']!.single.value, 100 * (1 + 5 / 30));
    });

    test('two sets are both counted in the mean', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 100, reps: 1), _weighted(weight: 90, reps: 1)],
      );

      final point = allLiftSeries([session])['Bench Press']!.single;

      expect(point.value, 95); // mean of 100 and 90
    });

    test('only the top three sets count toward the mean when more are logged', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [
          _weighted(weight: 100, reps: 1),
          _weighted(weight: 90, reps: 1),
          _weighted(weight: 80, reps: 1),
          _weighted(weight: 10, reps: 1),
          _weighted(weight: 5, reps: 1),
        ],
      );

      final point = allLiftSeries([session])['Bench Press']!.single;

      expect(point.value, 90); // mean of 100, 90, 80
    });

    test('setsCounted reflects how many sets fed the mean, capped at three', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: List.generate(5, (_) => _weighted(weight: 100, reps: 1)),
      );

      expect(allLiftSeries([session])['Bench Press']!.single.setsCounted, 3);
    });

    test('setsPerformed reflects every performed set, not just the counted ones', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: List.generate(5, (_) => _weighted(weight: 100, reps: 1)),
      );

      expect(allLiftSeries([session])['Bench Press']!.single.setsPerformed, 5);
    });

    test('best is the heaviest single set, independent of the mean', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 100, reps: 1), _weighted(weight: 40, reps: 1)],
      );

      expect(allLiftSeries([session])['Bench Press']!.single.best, 100);
    });

    test('skipped sets are ignored entirely', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 100, reps: 1, skipped: true), _weighted(weight: 60, reps: 1)],
      );

      final point = allLiftSeries([session])['Bench Press']!.single;

      expect(point.value, 60);
    });

    test('a session where every set is above the 12-rep validity cap produces no point', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 60, reps: 20)],
      );

      expect(allLiftSeries([session])['Bench Press'], isEmpty);
    });

    test('points are ordered chronologically regardless of input order', () {
      final older = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 60, reps: 1)],
      );
      final newer = _session(
        id: 's2',
        startedAt: DateTime(2026, 1, 12),
        sets: [_weighted(weight: 65, reps: 1)],
      );

      final series = allLiftSeries([newer, older])['Bench Press']!;

      expect(series.map((p) => p.value).toList(), [60, 65]);
    });

    test('bodyweight lifts are tracked by reps per set', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_bodyweight(reps: 8), _bodyweight(reps: 12)],
      );

      final point = allLiftSeries([session])['Pull-up']!.single;

      expect(point.value, 10); // mean of 8 and 12
    });

    test('timed lifts are tracked by hold duration', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_timed(heldSeconds: 60), _timed(heldSeconds: 90)],
      );

      final point = allLiftSeries([session])['Plank']!.single;

      expect(point.value, 75); // mean of 60 and 90
    });

    test('different exercises logged in the same session get independent series', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 5),
        sets: [_weighted(weight: 100, reps: 1), _weighted(exerciseName: 'Squat', weight: 140, reps: 1)],
      );

      final series = allLiftSeries([session]);

      expect(series['Bench Press']!.single.value, 100);
      expect(series['Squat']!.single.value, 140);
    });

    test('an exercise never logged has no entry in the map', () {
      final session = _session(id: 's1', startedAt: DateTime(2026, 1, 5), sets: [_weighted(weight: 100, reps: 1)]);

      expect(allLiftSeries([session]).containsKey('Squat'), isFalse);
    });
  });

  group('computeLiftProgress', () {
    test('returns null for an empty series', () {
      expect(computeLiftProgress([], exerciseName: 'Bench Press'), isNull);
    });

    test('a single point is reported as insufficientData', () {
      final progress = computeLiftProgress(
        [_point(DateTime(2026, 1, 5), 100)],
        exerciseName: 'Bench Press',
      );

      expect(progress!.status, LiftStatus.insufficientData);
    });

    test('startValue is the mean of the first three points', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 110),
        _point(DateTime(2026, 1, 29), 110),
        _point(DateTime(2026, 2, 5), 110),
      ];

      final progress = computeLiftProgress(series, exerciseName: 'Bench Press');

      expect(progress!.startValue, 100);
    });

    test('currentValue is the mean of the last three points', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 110),
        _point(DateTime(2026, 1, 29), 110),
        _point(DateTime(2026, 2, 5), 110),
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 2, 6),
      );

      expect(progress!.currentValue, 110);
    });

    test('status is progressing when the gain clears the noise floor and the best is recent', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 110),
        _point(DateTime(2026, 1, 29), 110),
        _point(DateTime(2026, 2, 5), 110),
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 2, 6),
      );

      expect(progress!.status, LiftStatus.progressing);
    });

    test('status is holding when the delta is within the 2.5% noise floor', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 101),
        _point(DateTime(2026, 1, 29), 101),
        _point(DateTime(2026, 2, 5), 101),
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 2, 6),
      );

      expect(progress!.status, LiftStatus.holding);
    });

    test('status is regressing when the drop clears the noise floor and the best is recent', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 95),
        _point(DateTime(2026, 1, 29), 95),
        _point(DateTime(2026, 2, 5), 95),
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 2, 6),
      );

      expect(progress!.status, LiftStatus.regressing);
    });

    test('status is holding when six or more weeks have passed since the best value, '
        'overriding what the delta alone would suggest', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 95),
        _point(DateTime(2026, 1, 29), 95),
        _point(DateTime(2026, 2, 5), 95),
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 2, 5).add(const Duration(days: 10)),
      );

      expect(progress!.status, LiftStatus.holding);
    });

    test('weeksSinceBest counts from the earliest session that reached the peak value', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 100),
        _point(DateTime(2026, 1, 22), 95),
        _point(DateTime(2026, 1, 29), 95),
        _point(DateTime(2026, 2, 5), 95),
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 2, 5), // 35 days after the first 100
      );

      expect(progress!.weeksSinceBest, 5);
    });

    test('deload weeks are excluded when picking the current-value endpoint', () {
      final restWeekStart = weekStartOf(DateTime(2026, 1, 29)); // last point's week
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 110),
        _point(DateTime(2026, 1, 15), 110),
        _point(DateTime(2026, 1, 22), 110),
        _point(DateTime(2026, 1, 29), 40), // rest-week outlier, excluded
      ];

      final progress = computeLiftProgress(
        series,
        exerciseName: 'Bench Press',
        now: DateTime(2026, 1, 30),
        excludedWeekStarts: {restWeekStart},
      );

      expect(progress!.currentValue, 110); // mean of the three points before the rest week
    });

    test('isExtrapolated is true when the series spans less than 42 days', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 8), 100),
        _point(DateTime(2026, 1, 15), 105),
      ];

      final progress = computeLiftProgress(series, exerciseName: 'Bench Press');

      expect(progress!.isExtrapolated, isTrue);
    });

    test('isExtrapolated is false when the series spans 42 days or more', () {
      final series = [
        _point(DateTime(2026, 1, 1), 100),
        _point(DateTime(2026, 1, 22), 100),
        _point(DateTime(2026, 2, 12), 105),
      ];

      final progress = computeLiftProgress(series, exerciseName: 'Bench Press');

      expect(progress!.isExtrapolated, isFalse);
    });

    test('excludedHighRepSessions is threaded through from the caller', () {
      final progress = computeLiftProgress(
        [_point(DateTime(2026, 1, 1), 100), _point(DateTime(2026, 1, 8), 105)],
        exerciseName: 'Bench Press',
        excludedHighRepSessions: 2,
      );

      expect(progress!.excludedHighRepSessions, 2);
    });
  });

  group('rankedLifts', () {
    LiftSessionPoint p(DateTime date, double value) => _point(date, value);

    test('excludes a lift with fewer than four sessions', () {
      final series = {
        'Bench Press': [
          p(DateTime(2026, 1, 1), 100),
          p(DateTime(2026, 1, 8), 105),
          p(DateTime(2026, 1, 15), 110),
        ],
      };

      expect(rankedLifts(series), isEmpty);
    });

    test('excludes a lift spanning fewer than 21 days even with four sessions', () {
      final series = {
        'Bench Press': [
          p(DateTime(2026, 1, 1), 100),
          p(DateTime(2026, 1, 3), 101),
          p(DateTime(2026, 1, 5), 102),
          p(DateTime(2026, 1, 7), 103), // 6-day span
        ],
      };

      expect(rankedLifts(series), isEmpty);
    });

    test('includes a lift meeting both the session-count and span thresholds', () {
      final series = {
        'Bench Press': [
          p(DateTime(2026, 1, 1), 100),
          p(DateTime(2026, 1, 8), 103),
          p(DateTime(2026, 1, 15), 106),
          p(DateTime(2026, 1, 22), 110), // 21-day span
        ],
      };

      expect(rankedLifts(series, now: DateTime(2026, 1, 23)), hasLength(1));
    });

    test('sorts lifts by percent-per-30-days descending', () {
      final fastGainer = [
        p(DateTime(2026, 1, 1), 100),
        p(DateTime(2026, 1, 8), 100),
        p(DateTime(2026, 1, 15), 100),
        p(DateTime(2026, 1, 22), 120),
      ];
      final slowGainer = [
        p(DateTime(2026, 1, 1), 100),
        p(DateTime(2026, 1, 8), 100),
        p(DateTime(2026, 1, 15), 100),
        p(DateTime(2026, 1, 22), 105),
      ];
      final series = {'Squat': slowGainer, 'Bench Press': fastGainer};

      final ranked = rankedLifts(series, now: DateTime(2026, 1, 23));

      expect(ranked.map((l) => l.exerciseName).toList(), ['Bench Press', 'Squat']);
    });

    test('the only filter restricts the ledger to a single metric', () {
      final weighted = [
        _point(DateTime(2026, 1, 1), 100, metric: LiftMetric.estimatedOneRm),
        _point(DateTime(2026, 1, 8), 100, metric: LiftMetric.estimatedOneRm),
        _point(DateTime(2026, 1, 15), 100, metric: LiftMetric.estimatedOneRm),
        _point(DateTime(2026, 1, 22), 105, metric: LiftMetric.estimatedOneRm),
      ];
      final bodyweight = [
        _point(DateTime(2026, 1, 1), 8, metric: LiftMetric.repsPerSet),
        _point(DateTime(2026, 1, 8), 8, metric: LiftMetric.repsPerSet),
        _point(DateTime(2026, 1, 15), 8, metric: LiftMetric.repsPerSet),
        _point(DateTime(2026, 1, 22), 10, metric: LiftMetric.repsPerSet),
      ];
      final series = {'Bench Press': weighted, 'Pull-up': bodyweight};

      final ranked = rankedLifts(series, only: LiftMetric.repsPerSet, now: DateTime(2026, 1, 23));

      expect(ranked.map((l) => l.exerciseName).toList(), ['Pull-up']);
    });
  });
}
