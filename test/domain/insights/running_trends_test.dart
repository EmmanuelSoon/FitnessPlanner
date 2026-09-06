import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/running_trends.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

RunSession _run({
  required String id,
  required DateTime startedAt,
  required Duration duration,
  required double distanceMeters,
}) =>
    RunSession(
      id: id,
      startedAt: startedAt,
      endedAt: startedAt.add(duration),
      distanceMeters: distanceMeters,
    );

void main() {
  group('weeklyRunStats', () {
    test('returns a zeroed, pace-less bucket per week when there are no runs', () {
      final weeks = weeklyRunStats([], weeks: 8, now: DateTime(2026, 3, 9));

      expect(weeks, hasLength(8));
      expect(
        weeks.every((w) =>
            w.distanceKm == 0 && w.runCount == 0 && w.avgPaceSecPerKm == null),
        isTrue,
      );
    });

    test('buckets are in chronological order ending with the current week', () {
      final weeks = weeklyRunStats([], weeks: 8, now: DateTime(2026, 3, 9));

      // 2026-03-09 is a Monday; the current week's bucket starts on it.
      expect(weeks.last.weekStart, DateTime(2026, 3, 9));
      expect(weeks.first.weekStart, DateTime(2026, 3, 9 - 7 * 7));
    });

    test('sums distance across runs in the same week', () {
      final run1 = _run(
        id: 'r1',
        startedAt: DateTime(2026, 3, 10),
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
      );
      final run2 = _run(
        id: 'r2',
        startedAt: DateTime(2026, 3, 11),
        duration: const Duration(minutes: 25),
        distanceMeters: 4000,
      );

      final weeks = weeklyRunStats([run1, run2], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.distanceKm, 9);
      expect(weeks.single.runCount, 2);
    });

    test('averages pace by total time over total distance, not by averaging per-run paces', () {
      // run1: 30min / 5km = 6 min/km. run2: 12min / 4km = 3 min/km.
      // A simple mean of paces would give 4.5 min/km; the weighted total
      // (42min / 9km) gives ~4.667 min/km instead.
      final run1 = _run(
        id: 'r1',
        startedAt: DateTime(2026, 3, 10),
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
      );
      final run2 = _run(
        id: 'r2',
        startedAt: DateTime(2026, 3, 11),
        duration: const Duration(minutes: 12),
        distanceMeters: 4000,
      );

      final weeks = weeklyRunStats([run1, run2], weeks: 1, now: DateTime(2026, 3, 9));

      final totalSeconds = const Duration(minutes: 42).inSeconds;
      expect(weeks.single.avgPaceSecPerKm, totalSeconds / 9);
    });

    test('a zero-distance run counts toward runCount but not distance or pace', () {
      final run = _run(
        id: 'r1',
        startedAt: DateTime(2026, 3, 10),
        duration: const Duration(minutes: 10),
        distanceMeters: 0,
      );

      final weeks = weeklyRunStats([run], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.runCount, 1);
      expect(weeks.single.distanceKm, 0);
      expect(weeks.single.avgPaceSecPerKm, isNull);
    });

    test('excludes runs outside the requested window', () {
      final old = _run(
        id: 'r1',
        startedAt: DateTime(2026, 1, 1),
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
      );

      final weeks = weeklyRunStats([old], weeks: 1, now: DateTime(2026, 3, 9));

      expect(weeks.single.distanceKm, 0);
      expect(weeks.single.runCount, 0);
    });
  });
}
