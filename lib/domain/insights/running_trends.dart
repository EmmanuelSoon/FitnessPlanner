import 'package:fitness_planner/domain/insights/volume_stats.dart' show weekStartOf;
import 'package:fitness_planner/domain/models/run_session.dart';

/// One calendar week's running activity. [avgPaceSecPerKm] is the week's
/// total time over its total distance (not a mean of each run's own pace,
/// which would weight a short run and a long one equally) — null when no
/// distance was covered that week, since a pace with no distance behind it
/// has no meaningful value to show.
class WeekRunStats {
  final DateTime weekStart;
  final double distanceKm;
  final int runCount;
  final double? avgPaceSecPerKm;

  const WeekRunStats({
    required this.weekStart,
    required this.distanceKm,
    required this.runCount,
    required this.avgPaceSecPerKm,
  });
}

/// One [WeekRunStats] bucket per week for the last [weeks] weeks,
/// chronological, ending with the week containing [now] (defaults to the
/// current time). Weeks run Monday-Sunday, same buckets as [weekStartOf]
/// uses for training volume. Weeks with no logged runs are included with
/// zeroed figures, so a trend chart shows gaps rather than skipping them.
List<WeekRunStats> weeklyRunStats(
  List<RunSession> runs, {
  int weeks = 8,
  DateTime? now,
}) {
  final currentWeekStart = weekStartOf(now ?? DateTime.now());
  final bucketStarts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(
        currentWeekStart.year,
        currentWeekStart.month,
        currentWeekStart.day - 7 * i,
      ),
  ];

  final distanceByWeek = <DateTime, double>{for (final start in bucketStarts) start: 0};
  final durationSecondsByWeek = <DateTime, int>{for (final start in bucketStarts) start: 0};
  final runCountByWeek = <DateTime, int>{for (final start in bucketStarts) start: 0};

  for (final run in runs) {
    final bucket = weekStartOf(run.startedAt);
    if (!distanceByWeek.containsKey(bucket)) continue;

    runCountByWeek[bucket] = runCountByWeek[bucket]! + 1;
    distanceByWeek[bucket] = distanceByWeek[bucket]! + run.distanceKm;
    durationSecondsByWeek[bucket] = durationSecondsByWeek[bucket]! + run.duration.inSeconds;
  }

  return [
    for (final start in bucketStarts)
      WeekRunStats(
        weekStart: start,
        distanceKm: distanceByWeek[start]!,
        runCount: runCountByWeek[start]!,
        avgPaceSecPerKm: distanceByWeek[start]! > 0
            ? durationSecondsByWeek[start]! / distanceByWeek[start]!
            : null,
      ),
  ];
}
