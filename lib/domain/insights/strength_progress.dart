import 'package:fitness_planner/domain/insights/insights_shared.dart';
import 'package:fitness_planner/domain/insights/volume_stats.dart' show weekStartOf;
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

/// Which unit a lift's history is tracked in, decided once across its
/// entire logged history so a single odd session never flips the unit
/// mid-series.
enum LiftMetric { estimatedOneRm, repsPerSet, holdSeconds }

/// Classifies [performed] (already filtered to non-skipped sets for one
/// exercise) into the metric that exercise should be tracked by.
LiftMetric metricFor(List<LoggedSet> performed) {
  if (performed.any((s) => s.heldSeconds != null)) return LiftMetric.holdSeconds;
  if (performed.any((s) => s.actualWeight > 0)) return LiftMetric.estimatedOneRm;
  return LiftMetric.repsPerSet;
}

/// One session's performance for a lift: the mean of its top three sets
/// ([value]), so one miscounted rep or a light back-off set can't swing the
/// point, alongside the single heaviest/best set ([best]) so the ledger and
/// a records list can never silently disagree.
class LiftSessionPoint {
  final DateTime date;
  final String sessionId;
  final double value;
  final double best;
  final int setsCounted;
  final int setsPerformed;
  final LiftMetric metric;

  const LiftSessionPoint({
    required this.date,
    required this.sessionId,
    required this.value,
    required this.best,
    required this.setsCounted,
    required this.setsPerformed,
    required this.metric,
  });
}

enum LiftStatus { progressing, holding, regressing, insufficientData }

/// A lift's progress over the points it was offered: averaged endpoints
/// (mean of the first/last three points, not single sessions), so the
/// summary isn't hostage to two noisy sessions.
class LiftProgress {
  final String exerciseName;
  final LiftMetric metric;
  final double startValue;
  final double currentValue;
  final double absoluteDelta;
  final double? percentDelta;
  final double? percentPer30Days;
  final int sessionCount;
  final int excludedHighRepSessions;
  final DateTime firstDate;
  final DateTime lastDate;
  final int spanDays;
  final DateTime? bestDate;
  final int weeksSinceBest;
  final bool isExtrapolated;
  final LiftStatus status;

  const LiftProgress({
    required this.exerciseName,
    required this.metric,
    required this.startValue,
    required this.currentValue,
    required this.absoluteDelta,
    required this.percentDelta,
    required this.percentPer30Days,
    required this.sessionCount,
    required this.excludedHighRepSessions,
    required this.firstDate,
    required this.lastDate,
    required this.spanDays,
    required this.bestDate,
    required this.weeksSinceBest,
    required this.isExtrapolated,
    required this.status,
  });
}

const int _kMinRankableSessions = 4;
const int _kMinRankableSpanDays = 21;
const int _kExtrapolationSpanDays = 42;
const double _kStallPercentFloor = 2.5;
const int _kStallWeeksSinceBest = 6;

double? _valueFor(LiftMetric metric, LoggedSet set) {
  switch (metric) {
    case LiftMetric.estimatedOneRm:
      return estimatedOneRm(set.actualWeight, set.actualReps);
    case LiftMetric.repsPerSet:
      return set.actualReps.toDouble();
    case LiftMetric.holdSeconds:
      return (set.heldSeconds ?? 0).toDouble();
  }
}

/// One point per session (chronological) for every exercise logged across
/// [sessions], in a single walk over the sessions and their sets — a
/// per-exercise builder called once per name would rescan the full history
/// once per name.
Map<String, List<LiftSessionPoint>> allLiftSeries(List<WorkoutSession> sessions) {
  final sorted = chronological(sessions);

  final byExercise = <String, List<({DateTime date, String sessionId, List<LoggedSet> sets})>>{};
  for (final session in sorted) {
    final setsByExercise = <String, List<LoggedSet>>{};
    for (final set in session.sets) {
      if (set.skipped) continue;
      setsByExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    setsByExercise.forEach((name, sets) {
      byExercise.putIfAbsent(name, () => []).add((date: session.startedAt, sessionId: session.id, sets: sets));
    });
  }

  final result = <String, List<LiftSessionPoint>>{};
  byExercise.forEach((name, perSession) {
    final metric = metricFor(perSession.expand((e) => e.sets).toList());
    final points = <LiftSessionPoint>[];
    for (final entry in perSession) {
      final values = <double>[];
      for (final set in entry.sets) {
        final value = _valueFor(metric, set);
        if (value != null) values.add(value);
      }
      if (values.isEmpty) continue;
      values.sort((a, b) => b.compareTo(a));
      final counted = values.take(3).toList();
      points.add(
        LiftSessionPoint(
          date: entry.date,
          sessionId: entry.sessionId,
          value: counted.reduce((a, b) => a + b) / counted.length,
          best: values.first,
          setsCounted: counted.length,
          setsPerformed: entry.sets.length,
          metric: metric,
        ),
      );
    }
    result[name] = points;
  });
  return result;
}

double _meanOf(List<LiftSessionPoint> points) =>
    points.map((p) => p.value).reduce((a, b) => a + b) / points.length;

/// A lift's progress summary over [series], or null if it has no points at
/// all. [excludedWeekStarts] (deload weeks, keyed by [weekStartOf]) are
/// dropped from endpoint selection only — they still count toward
/// [sessionCount] and the full history used to find the best-ever value.
LiftProgress? computeLiftProgress(
  List<LiftSessionPoint> series, {
  required String exerciseName,
  DateTime? now,
  Set<DateTime> excludedWeekStarts = const {},
  int excludedHighRepSessions = 0,
}) {
  if (series.isEmpty) return null;
  final resolvedNow = now ?? DateTime.now();

  final firstDate = series.first.date;
  final lastDate = series.last.date;
  final spanDays = lastDate.difference(firstDate).inDays;

  // The best-ever value is tracked across the *full* history regardless of
  // deload exclusion — it's asking "when did this lift last peak", not
  // "what should the window endpoints be". Ties keep the earliest date.
  final bestPoint = series.reduce((a, b) => a.value >= b.value ? a : b);
  final weeksSinceBest = resolvedNow.difference(bestPoint.date).inDays ~/ 7;

  if (series.length < 2) {
    return LiftProgress(
      exerciseName: exerciseName,
      metric: series.first.metric,
      startValue: series.first.value,
      currentValue: series.first.value,
      absoluteDelta: 0,
      percentDelta: null,
      percentPer30Days: null,
      sessionCount: series.length,
      excludedHighRepSessions: excludedHighRepSessions,
      firstDate: firstDate,
      lastDate: lastDate,
      spanDays: spanDays,
      bestDate: bestPoint.date,
      weeksSinceBest: weeksSinceBest,
      isExtrapolated: true,
      status: LiftStatus.insufficientData,
    );
  }

  final eligible = series.where((p) => !excludedWeekStarts.contains(weekStartOf(p.date))).toList();
  final endpointSource = eligible.isEmpty ? series : eligible;

  final startValue = _meanOf(endpointSource.take(3).toList());
  final currentValue = _meanOf(
    endpointSource.sublist(endpointSource.length - (endpointSource.length < 3 ? endpointSource.length : 3)),
  );
  final absoluteDelta = currentValue - startValue;
  final percentDelta = startValue == 0 ? null : (absoluteDelta / startValue) * 100;
  final percentPer30Days = (percentDelta == null || spanDays <= 0) ? null : percentDelta * 30 / spanDays;

  final LiftStatus status;
  if (percentDelta == null) {
    status = LiftStatus.insufficientData;
  } else if (percentDelta.abs() < _kStallPercentFloor || weeksSinceBest >= _kStallWeeksSinceBest) {
    // Checked before the regression arm: a lift whose peak is six-plus
    // weeks stale reads as "stuck", not "actively getting worse", even if
    // the current window happens to sit below that peak.
    status = LiftStatus.holding;
  } else if (percentDelta <= -_kStallPercentFloor) {
    status = LiftStatus.regressing;
  } else {
    status = LiftStatus.progressing;
  }

  return LiftProgress(
    exerciseName: exerciseName,
    metric: series.first.metric,
    startValue: startValue,
    currentValue: currentValue,
    absoluteDelta: absoluteDelta,
    percentDelta: percentDelta,
    percentPer30Days: percentPer30Days,
    sessionCount: series.length,
    excludedHighRepSessions: excludedHighRepSessions,
    firstDate: firstDate,
    lastDate: lastDate,
    spanDays: spanDays,
    bestDate: bestPoint.date,
    weeksSinceBest: weeksSinceBest,
    isExtrapolated: spanDays < _kExtrapolationSpanDays,
    status: status,
  );
}

/// Every lift with enough data to be worth showing, ranked by
/// [LiftProgress.percentPer30Days] descending. Lifts below the minimum
/// session count or time span are left out entirely rather than shown as
/// "insufficient data" — a half-populated ledger is worse than an empty one
/// with a clear instruction.
List<LiftProgress> rankedLifts(
  Map<String, List<LiftSessionPoint>> allSeries, {
  LiftMetric? only,
  DateTime? now,
  Set<DateTime> excludedWeekStarts = const {},
}) {
  final results = <LiftProgress>[];
  allSeries.forEach((name, series) {
    if (series.isEmpty) return;
    if (only != null && series.first.metric != only) return;
    if (series.length < _kMinRankableSessions) return;
    final spanDays = series.last.date.difference(series.first.date).inDays;
    if (spanDays < _kMinRankableSpanDays) return;

    final progress = computeLiftProgress(
      series,
      exerciseName: name,
      now: now,
      excludedWeekStarts: excludedWeekStarts,
    );
    if (progress != null) results.add(progress);
  });

  results.sort((a, b) {
    final ap = a.percentPer30Days;
    final bp = b.percentPer30Days;
    if (ap == null && bp == null) return 0;
    if (ap == null) return 1;
    if (bp == null) return -1;
    return bp.compareTo(ap);
  });
  return results;
}
