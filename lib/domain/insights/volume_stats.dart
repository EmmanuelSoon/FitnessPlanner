import 'package:fitness_planner/domain/models/workout_session.dart';

/// One calendar week's training volume, as two separate figures that are
/// never summed together: tonnage (weighted sets only) and rep volume
/// (weighted + bodyweight sets). Timed holds contribute to neither — they
/// have no reps and their weight field (if any) isn't a repeated lift.
class WeekVolume {
  final DateTime weekStart;
  final double tonnageKg;
  final int repVolume;
  final int sessionCount;

  const WeekVolume({
    required this.weekStart,
    required this.tonnageKg,
    required this.repVolume,
    required this.sessionCount,
  });
}

/// One [WeekVolume] bucket per week for the last [weeks] weeks, chronological,
/// ending with the week containing [now] (defaults to the current time).
/// Weeks run Monday–Sunday. Weeks with no logged sessions are included with
/// zeroed figures, so a trend chart shows gaps rather than skipping them.
List<WeekVolume> weeklyVolume(
  List<WorkoutSession> sessions, {
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

  final tonnageByWeek = <DateTime, double>{
    for (final start in bucketStarts) start: 0,
  };
  final repsByWeek = <DateTime, int>{
    for (final start in bucketStarts) start: 0,
  };
  final sessionCountByWeek = <DateTime, int>{
    for (final start in bucketStarts) start: 0,
  };

  for (final session in sessions) {
    final bucket = weekStartOf(session.startedAt);
    if (!tonnageByWeek.containsKey(bucket)) continue;

    sessionCountByWeek[bucket] = sessionCountByWeek[bucket]! + 1;
    for (final set in session.sets) {
      if (set.skipped || set.heldSeconds != null) continue;
      tonnageByWeek[bucket] = tonnageByWeek[bucket]! + set.actualWeight * set.actualReps;
      repsByWeek[bucket] = repsByWeek[bucket]! + set.actualReps;
    }
  }

  return [
    for (final start in bucketStarts)
      WeekVolume(
        weekStart: start,
        tonnageKg: tonnageByWeek[start]!,
        repVolume: repsByWeek[start]!,
        sessionCount: sessionCountByWeek[start]!,
      ),
  ];
}

/// Signed percent change from [previous] to [current]; null when
/// [previous] is zero, since a percent change against no baseline has no
/// meaningful value to show.
double? percentChange(double current, double previous) {
  if (previous == 0) return null;
  return (current - previous) / previous * 100;
}

/// The Monday that starts [dt]'s calendar week, at local midnight.
///
/// Computed entirely from calendar fields (year/month/day), never by
/// subtracting a fixed [Duration] off a wall-clock instant — the latter
/// drifts by an hour across a DST transition, which would shift a bucket
/// boundary off midnight and silently exclude a week's sessions from the
/// totals.
DateTime weekStartOf(DateTime dt) {
  final delta = dt.weekday - DateTime.monday;
  return DateTime(dt.year, dt.month, dt.day - delta);
}
