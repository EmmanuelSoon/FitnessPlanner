import 'package:fitness_planner/domain/insights/insights_shared.dart';
import 'package:fitness_planner/domain/insights/strength_progress.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

/// One session's performance for a single exercise, classified as a
/// weighted top set, a bodyweight best set, or a timed hold — mirroring
/// the classification `SessionBreakdown` already uses per set
/// (`heldSeconds != null` → timed, else weight vs. reps).
class ExerciseTrendPoint {
  final DateTime date;
  final double value;
  final String unit;
  final String metricLabel;

  const ExerciseTrendPoint({
    required this.date,
    required this.value,
    required this.unit,
    required this.metricLabel,
  });
}

/// One point per session (chronological) that logged a performed
/// (non-skipped) set of [exerciseName]. Sessions where every set for the
/// exercise was skipped, or the exercise wasn't logged at all, produce no
/// point.
///
/// The exercise's kind (timed / weighted / bodyweight) is classified once
/// across *all* its performed sets, not per session — a session logged
/// with no weight recorded (e.g. left at 0kg) still reads as a weighted
/// "Top set" of 0kg rather than flipping the whole trend to reps.
List<ExerciseTrendPoint> computeExerciseTrend(
  List<WorkoutSession> sessions,
  String exerciseName,
) {
  final sorted = chronological(sessions);

  final performedBySession = <List<LoggedSet>>[];
  final allPerformed = <LoggedSet>[];
  for (final session in sorted) {
    final performed = session.sets
        .where((s) => s.exerciseName == exerciseName && !s.skipped)
        .toList();
    performedBySession.add(performed);
    allPerformed.addAll(performed);
  }
  if (allPerformed.isEmpty) return [];

  final kind = metricFor(allPerformed);
  final unit = _unitFor(kind);
  final metricLabel = _metricLabelFor(kind);

  final points = <ExerciseTrendPoint>[];
  for (var i = 0; i < sorted.length; i++) {
    final performed = performedBySession[i];
    if (performed.isEmpty) continue;
    points.add(
      ExerciseTrendPoint(
        date: sorted[i].startedAt,
        value: _bestValue(kind, performed),
        unit: unit,
        metricLabel: metricLabel,
      ),
    );
  }
  return points;
}

/// Distinct exercise names across [sessions], most-recently-logged first.
List<String> exerciseNamesLogged(List<WorkoutSession> sessions) {
  final sorted = [...sessions]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final seen = <String>{};
  final names = <String>[];
  for (final session in sorted) {
    for (final set in session.sets) {
      if (seen.add(set.exerciseName)) names.add(set.exerciseName);
    }
  }
  return names;
}

double _bestValue(LiftMetric kind, List<LoggedSet> performed) {
  switch (kind) {
    case LiftMetric.holdSeconds:
      return performed
          .map((s) => (s.heldSeconds ?? 0).toDouble())
          .reduce((a, b) => a > b ? a : b);
    case LiftMetric.estimatedOneRm:
      return performed.map((s) => s.actualWeight).reduce((a, b) => a > b ? a : b);
    case LiftMetric.repsPerSet:
      return performed
          .map((s) => s.actualReps.toDouble())
          .reduce((a, b) => a > b ? a : b);
  }
}

String _unitFor(LiftMetric kind) => switch (kind) {
  LiftMetric.holdSeconds => 's',
  LiftMetric.estimatedOneRm => 'kg',
  LiftMetric.repsPerSet => 'reps',
};

String _metricLabelFor(LiftMetric kind) => switch (kind) {
  LiftMetric.holdSeconds => 'Longest hold',
  LiftMetric.estimatedOneRm => 'Top set',
  LiftMetric.repsPerSet => 'Best set',
};
