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
List<ExerciseTrendPoint> computeExerciseTrend(
  List<WorkoutSession> sessions,
  String exerciseName,
) {
  final sorted = [...sessions]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  final points = <ExerciseTrendPoint>[];
  for (final session in sorted) {
    final performed = session.sets
        .where((s) => s.exerciseName == exerciseName && !s.skipped)
        .toList();
    if (performed.isEmpty) continue;

    points.add(
      ExerciseTrendPoint(
        date: session.startedAt,
        value: _bestValue(performed),
        unit: _unitFor(performed),
        metricLabel: _metricLabelFor(performed),
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

bool _isTimed(List<LoggedSet> performed) =>
    performed.any((s) => s.heldSeconds != null);

bool _isWeighted(List<LoggedSet> performed) =>
    performed.any((s) => s.actualWeight > 0);

double _bestValue(List<LoggedSet> performed) {
  if (_isTimed(performed)) {
    return performed
        .map((s) => (s.heldSeconds ?? 0).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }
  if (_isWeighted(performed)) {
    return performed.map((s) => s.actualWeight).reduce((a, b) => a > b ? a : b);
  }
  return performed
      .map((s) => s.actualReps.toDouble())
      .reduce((a, b) => a > b ? a : b);
}

String _unitFor(List<LoggedSet> performed) {
  if (_isTimed(performed)) return 's';
  if (_isWeighted(performed)) return 'kg';
  return 'reps';
}

String _metricLabelFor(List<LoggedSet> performed) {
  if (_isTimed(performed)) return 'Longest hold';
  if (_isWeighted(performed)) return 'Top set';
  return 'Best set';
}
