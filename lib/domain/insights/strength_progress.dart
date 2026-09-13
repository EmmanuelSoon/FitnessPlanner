import 'package:fitness_planner/domain/insights/insights_shared.dart';
import 'package:fitness_planner/domain/insights/volume_stats.dart' show percentChange, weekStartOf;
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

/// Which category of value governs a lift's history, decided once across
/// its entire logged history so a single odd session never flips the unit
/// mid-series.
///
/// This names the *category* only — each consumer still picks its own
/// per-set value formula for it. `strength_progress.dart` averages true
/// Epley estimates for [weighted] lifts, while `exercise_trend.dart`
/// intentionally keeps plotting raw top-set weight for the same category
/// (per plan 022: swapping in Epley there doesn't fix a single-set chart).
enum LiftMetric { weighted, repsPerSet, holdSeconds }

/// Classifies [performed] (already filtered to non-skipped sets for one
/// exercise) into the metric that exercise should be tracked by.
LiftMetric metricFor(List<LoggedSet> performed) {
  if (performed.any((s) => s.heldSeconds != null)) return LiftMetric.holdSeconds;
  if (performed.any((s) => s.actualWeight > 0)) return LiftMetric.weighted;
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
/// (mean of a window of points, not single sessions), so the summary isn't
/// hostage to two noisy sessions.
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

/// One exercise's points plus how many of its logged sessions produced no
/// point at all — every set fell outside the metric's validity range (e.g.
/// above the Epley rep cap) — so the summary can explain a gap in the line
/// instead of leaving a mystery.
class LiftSeries {
  final List<LiftSessionPoint> points;
  final int excludedHighRepSessions;

  const LiftSeries({required this.points, required this.excludedHighRepSessions});
}

const int _kMinRankableSessions = 4;
const int _kMinRankableSpanDays = 21;
const int _kExtrapolationSpanDays = 42;
const double _kStallPercentFloor = 2.5;
const int _kStallWeeksSinceBest = 6;

double? _valueFor(LiftMetric metric, LoggedSet set) {
  switch (metric) {
    case LiftMetric.weighted:
      return estimatedOneRm(set.actualWeight, set.actualReps);
    case LiftMetric.repsPerSet:
      return set.actualReps.toDouble();
    case LiftMetric.holdSeconds:
      return (set.heldSeconds ?? 0).toDouble();
  }
}

double _mean(List<double> values) => values.reduce((a, b) => a + b) / values.length;

/// One point per session (chronological) for every exercise logged across
/// [sessions], in a single walk over the sessions and their sets — a
/// per-exercise builder called once per name would rescan the full history
/// once per name.
Map<String, LiftSeries> allLiftSeries(List<WorkoutSession> sessions) {
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

  final result = <String, LiftSeries>{};
  byExercise.forEach((name, perSession) {
    final metric = metricFor(perSession.expand((e) => e.sets).toList());
    final points = <LiftSessionPoint>[];
    var excludedSessions = 0;
    for (final entry in perSession) {
      final values = <double>[];
      for (final set in entry.sets) {
        final value = _valueFor(metric, set);
        if (value != null) values.add(value);
      }
      if (values.isEmpty) {
        excludedSessions++;
        continue;
      }
      values.sort((a, b) => b.compareTo(a));
      final counted = values.take(3).toList();
      points.add(
        LiftSessionPoint(
          date: entry.date,
          sessionId: entry.sessionId,
          value: _mean(counted),
          best: values.first,
          setsCounted: counted.length,
          setsPerformed: entry.sets.length,
          metric: metric,
        ),
      );
    }
    result[name] = LiftSeries(points: points, excludedHighRepSessions: excludedSessions);
  });
  return result;
}

/// A lift's progress summary over [series], or null if it has no points at
/// all. [excludedWeekStarts] (deload weeks, keyed by [weekStartOf]) are
/// dropped from endpoint selection only — they still count toward
/// [LiftProgress.sessionCount] and the full history used to find the
/// best-ever value.
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

  // The best-ever value is tracked by each session's heaviest single set
  // (`best`), not its top-three mean — ranking by the mean could crown a
  // session with three merely-good sets over one that also included a
  // genuine PR set, disagreeing with a records list built from `best`, the
  // exact mismatch `best` exists to prevent. Ties keep the earliest date.
  final bestPoint = series.reduce((a, b) => a.best >= b.best ? a : b);
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

  // Window size is capped at 3 (the "top three sessions" convention used
  // elsewhere in this file) but also at half the eligible points, so a 2-
  // or 3-point series can't have its start and current windows overlap
  // into the very same points — which would always report a 0% change
  // regardless of what actually happened.
  final n = endpointSource.length;
  final windowSize = n ~/ 2 < 3 ? n ~/ 2 : 3;
  final startWindow = endpointSource.take(windowSize).toList();
  final endWindow = endpointSource.sublist(n - windowSize);

  final startValue = _mean(startWindow.map((p) => p.value).toList());
  final currentValue = _mean(endWindow.map((p) => p.value).toList());
  final absoluteDelta = currentValue - startValue;
  final percentDelta = percentChange(currentValue, startValue);

  // Normalized by the span the comparison actually covers — the gap
  // between the two averaged windows — not the full logged history, which
  // can read very differently once a deload week is excluded near either
  // edge.
  final endpointSpanDays = endWindow.last.date.difference(startWindow.first.date).inDays;
  final percentPer30Days = (percentDelta == null || endpointSpanDays <= 0)
      ? null
      : percentDelta * 30 / endpointSpanDays;

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
    isExtrapolated: endpointSpanDays < _kExtrapolationSpanDays,
    status: status,
  );
}

/// Every lift with enough data to be worth showing, ranked by
/// [LiftProgress.percentPer30Days] descending. Lifts below the minimum
/// session count or time span are left out entirely rather than shown as
/// "insufficient data" — a half-populated ledger is worse than an empty one
/// with a clear instruction.
List<LiftProgress> rankedLifts(
  Map<String, LiftSeries> allSeries, {
  LiftMetric? only,
  DateTime? now,
  Set<DateTime> excludedWeekStarts = const {},
}) {
  final results = <LiftProgress>[];
  allSeries.forEach((name, series) {
    final points = series.points;
    if (points.isEmpty) return;
    if (only != null && points.first.metric != only) return;
    if (points.length < _kMinRankableSessions) return;
    final spanDays = points.last.date.difference(points.first.date).inDays;
    if (spanDays < _kMinRankableSpanDays) return;

    final progress = computeLiftProgress(
      points,
      exerciseName: name,
      now: now,
      excludedWeekStarts: excludedWeekStarts,
      excludedHighRepSessions: series.excludedHighRepSessions,
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
