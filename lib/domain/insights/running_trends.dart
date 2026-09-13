import 'package:fitness_planner/domain/insights/volume_stats.dart' show weekBucketStarts, weekStartOf;
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
/// [type] restricts the buckets to one [RunType] — an easy run and a
/// tempo run in the same week would otherwise blend into one pace that
/// describes neither, since their paces mean structurally different
/// things. Null (the default) keeps every type, unchanged from before.
List<WeekRunStats> weeklyRunStats(
  List<RunSession> runs, {
  int weeks = 8,
  DateTime? now,
  RunType? type,
}) {
  final bucketStarts = weekBucketStarts(weeks: weeks, now: now);

  final distanceByWeek = <DateTime, double>{for (final start in bucketStarts) start: 0};
  final durationSecondsByWeek = <DateTime, int>{for (final start in bucketStarts) start: 0};
  final runCountByWeek = <DateTime, int>{for (final start in bucketStarts) start: 0};

  for (final run in runs) {
    if (type != null && run.runType != type) continue;
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

/// The distinct [RunType]s logged anywhere in [runs], in the enum's own
/// declared order — used to build a type filter that never offers a type
/// the user has never actually logged.
List<RunType> runTypesPresent(List<RunSession> runs) {
  final present = runs.map((r) => r.runType).toSet();
  return [for (final t in RunType.values) if (present.contains(t)) t];
}
