import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/volume_stats.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

WorkoutSession _session({
  required String id,
  required DateTime startedAt,
  required List<LoggedSet> sets,
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(hours: 1)),
      completed: true,
      sets: sets,
    );

LoggedSet _weighted({double weight = 60, int reps = 8, bool skipped = false}) =>
    LoggedSet(
      exerciseName: 'Bench Press',
      targetReps: reps,
      targetWeight: weight,
      actualReps: reps,
      actualWeight: weight,
      skipped: skipped,
    );

LoggedSet _bodyweight({int reps = 12, bool skipped = false}) => LoggedSet(
      exerciseName: 'Push-up',
      targetReps: reps,
      targetWeight: 0,
      actualReps: reps,
      actualWeight: 0,
      skipped: skipped,
    );

LoggedSet _timed({int heldSeconds = 30}) => LoggedSet(
      exerciseName: 'Plank',
      targetReps: 0,
      targetWeight: 0,
      actualReps: 0,
      actualWeight: 0,
      skipped: false,
      heldSeconds: heldSeconds,
      targetSeconds: heldSeconds,
    );

void main() {
  group('weeklyVolume', () {
    test('returns a zeroed bucket per week when there are no sessions', () {
      final weeks = weeklyVolume([], weeks: 8, now: DateTime(2026, 3, 9));

      expect(weeks, hasLength(8));
      expect(
        weeks.every((w) => w.tonnageKg == 0 && w.repVolume == 0 && w.sessionCount == 0),
        isTrue,
      );
    });

    test('buckets are in chronological order ending with the current week', () {
      final weeks = weeklyVolume([], weeks: 8, now: DateTime(2026, 3, 9));

      // 2026-03-09 is a Monday; the current week's bucket starts on it.
      expect(weeks.last.weekStart, DateTime(2026, 3, 9));
      expect(weeks.first.weekStart, DateTime(2026, 3, 9 - 7 * 7));
      // Compared as UTC calendar dates rather than via `.difference()` on
      // the local `weekStart` values: `.difference()` measures elapsed
      // time, which a DST transition between two buckets would shift off
      // exactly 7*24h even though they're still 7 calendar days apart.
      for (var i = 1; i < weeks.length; i++) {
        final prevUtc = DateTime.utc(
          weeks[i - 1].weekStart.year,
          weeks[i - 1].weekStart.month,
          weeks[i - 1].weekStart.day,
        );
        final curUtc = DateTime.utc(
          weeks[i].weekStart.year,
          weeks[i].weekStart.month,
          weeks[i].weekStart.day,
        );
        expect(curUtc.difference(prevUtc), const Duration(days: 7));
      }
    });

    test('every bucket start is exact local midnight, regardless of the time of day `now` carries', () {
      // Regression: bucket starts must come from calendar-field arithmetic
      // (year/month/day), not from subtracting a fixed Duration off a
      // wall-clock instant — the latter drifts by an hour across a DST
      // transition and would shift a bucket off midnight, causing it to
      // silently miss the sessions it should have collected.
      final weeks = weeklyVolume([], weeks: 8, now: DateTime(2026, 3, 9, 23, 45, 30));

      for (final w in weeks) {
        expect(w.weekStart.hour, 0);
        expect(w.weekStart.minute, 0);
        expect(w.weekStart.second, 0);
        expect(w.weekStart.millisecond, 0);
      }
    });

    test('sums tonnage as weight times reps for performed weighted sets in a week', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 10), // Tuesday, current week
        sets: [_weighted(weight: 60, reps: 8), _weighted(weight: 40, reps: 10)],
      );

      final weeks = weeklyVolume([session], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.tonnageKg, 60 * 8 + 40 * 10);
    });

    test('sums rep volume across weighted and bodyweight performed sets, never combined with tonnage', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 10),
        sets: [_weighted(weight: 60, reps: 8), _bodyweight(reps: 12)],
      );

      final weeks = weeklyVolume([session], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.repVolume, 8 + 12);
      expect(weeks.single.tonnageKg, 60 * 8);
    });

    test('excludes skipped sets from both tonnage and rep volume', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 10),
        sets: [_weighted(weight: 60, reps: 8, skipped: true)],
      );

      final weeks = weeklyVolume([session], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.tonnageKg, 0);
      expect(weeks.single.repVolume, 0);
    });

    test('timed holds contribute nothing to tonnage or rep volume', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 10),
        sets: [_timed(heldSeconds: 45)],
      );

      final weeks = weeklyVolume([session], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.tonnageKg, 0);
      expect(weeks.single.repVolume, 0);
    });

    test('counts distinct sessions logged within a week, regardless of set count', () {
      final a = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 10),
        sets: [_weighted(), _weighted()],
      );
      final b = _session(
        id: 's2',
        startedAt: DateTime(2026, 3, 11),
        sets: [_bodyweight()],
      );

      final weeks = weeklyVolume([a, b], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.sessionCount, 2);
    });

    test('sessions outside the requested week window are excluded', () {
      final tooOld = _session(
        id: 's1',
        startedAt: DateTime(2026, 1, 1),
        sets: [_weighted(weight: 100, reps: 5)],
      );

      final weeks = weeklyVolume([tooOld], weeks: 4, now: DateTime(2026, 3, 9));

      expect(weeks.every((w) => w.tonnageKg == 0), isTrue);
    });

    test('a session lands in the bucket for the Monday starting its week', () {
      final sunday = _session(
        id: 's1',
        startedAt: DateTime(2026, 3, 15, 23), // Sunday, end of the week starting 3/9
        sets: [_weighted(weight: 50, reps: 5)],
      );

      final weeks = weeklyVolume([sunday], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.weekStart, DateTime(2026, 3, 9));
      expect(weeks.single.tonnageKg, 50 * 5);
    });
  });

  group('percentChange', () {
    test('returns the signed percent change from previous to current', () {
      expect(percentChange(120, 100), 20);
      expect(percentChange(80, 100), -20);
    });

    test('returns null when there is no baseline to compare against', () {
      expect(percentChange(50, 0), isNull);
    });
  });
}
