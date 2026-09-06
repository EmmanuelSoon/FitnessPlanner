import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

enum PersonalRecordType {
  heaviestWeight,
  mostReps,
  longestHold,
  bestEst1Rm,
  sessionTonnage,
  // Lower is better, unlike every type above — tracked via `_Progress`'s
  // `lowerIsBetter` flag instead of its default "bigger wins" comparison.
  fastestPace,
}

/// A current personal best: [type] paired with either the exercise it was
/// set on (the four per-exercise types) or a session's workout name
/// (`sessionTonnage`). [previousValue] is the best value this one
/// replaced, for a "+2.5 kg on previous best" delta line — null the first
/// time the metric is ever logged, since there's nothing to compare
/// against yet.
class PersonalRecord {
  final PersonalRecordType type;
  final String label;
  final double value;
  final int? reps;
  final double? previousValue;
  final DateTime achievedAt;
  final String sessionId;

  const PersonalRecord({
    required this.type,
    required this.label,
    required this.value,
    this.reps,
    this.previousValue,
    required this.achievedAt,
    required this.sessionId,
  }) : assert(
         type != PersonalRecordType.heaviestWeight || reps != null,
         'heaviestWeight records must carry the reps performed at that weight',
       );
}

/// Tracks one metric's best-so-far as sessions are offered in chronological
/// order, remembering the value it replaces so the eventual [PersonalRecord]
/// can show a delta against the previous best.
class _Progress {
  final bool lowerIsBetter;
  double? best;
  double? previousBest;
  int? reps;
  String? label;
  DateTime? achievedAt;
  String? sessionId;

  _Progress({this.lowerIsBetter = false});

  void offer(double value, String label, DateTime at, String sessId, {int? reps}) {
    final isBetter = best == null || (lowerIsBetter ? value < best! : value > best!);
    if (isBetter) {
      previousBest = best;
      best = value;
      this.label = label;
      achievedAt = at;
      sessionId = sessId;
      this.reps = reps;
    }
  }

  PersonalRecord? toRecord(PersonalRecordType type) {
    final best = this.best;
    if (best == null) return null;
    return PersonalRecord(
      type: type,
      label: label!,
      value: best,
      reps: reps,
      previousValue: previousBest,
      achievedAt: achievedAt!,
      sessionId: sessionId!,
    );
  }
}

/// The current personal-best for each [PersonalRecordType]: one per
/// exercise for the four per-exercise strength types, plus one overall
/// each for `sessionTonnage` and `fastestPace`.
List<PersonalRecord> computePersonalRecords(
  List<WorkoutSession> sessions,
  List<RunSession> runs,
) {
  final sorted = [...sessions]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final sortedRuns = [...runs]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  final heaviestWeight = <String, _Progress>{};
  final mostReps = <String, _Progress>{};
  final longestHold = <String, _Progress>{};
  final bestEst1Rm = <String, _Progress>{};
  final sessionTonnage = _Progress();
  final fastestPace = _Progress(lowerIsBetter: true);

  for (final session in sorted) {
    final bestWeightSet = <String, ({double weight, int reps})>{};
    final bestReps = <String, int>{};
    final bestHold = <String, int>{};
    final bestEpley = <String, double>{};
    var tonnage = 0.0;

    for (final set in session.sets) {
      if (set.skipped) continue;

      if (set.heldSeconds != null) {
        final current = bestHold[set.exerciseName];
        if (current == null || set.heldSeconds! > current) {
          bestHold[set.exerciseName] = set.heldSeconds!;
        }
        continue;
      }

      if (set.actualWeight > 0) {
        tonnage += set.actualWeight * set.actualReps;

        final current = bestWeightSet[set.exerciseName];
        if (current == null || set.actualWeight > current.weight) {
          bestWeightSet[set.exerciseName] = (weight: set.actualWeight, reps: set.actualReps);
        }

        final epley = set.actualWeight * (1 + set.actualReps / 30);
        final currentEpley = bestEpley[set.exerciseName];
        if (currentEpley == null || epley > currentEpley) {
          bestEpley[set.exerciseName] = epley;
        }
      } else {
        final current = bestReps[set.exerciseName];
        if (current == null || set.actualReps > current) {
          bestReps[set.exerciseName] = set.actualReps;
        }
      }
    }

    bestWeightSet.forEach((exercise, set) {
      heaviestWeight
          .putIfAbsent(exercise, () => _Progress())
          .offer(set.weight, exercise, session.startedAt, session.id, reps: set.reps);
    });
    bestReps.forEach((exercise, reps) {
      mostReps
          .putIfAbsent(exercise, () => _Progress())
          .offer(reps.toDouble(), exercise, session.startedAt, session.id);
    });
    bestHold.forEach((exercise, seconds) {
      longestHold
          .putIfAbsent(exercise, () => _Progress())
          .offer(seconds.toDouble(), exercise, session.startedAt, session.id);
    });
    bestEpley.forEach((exercise, epley) {
      bestEst1Rm
          .putIfAbsent(exercise, () => _Progress())
          .offer(epley, exercise, session.startedAt, session.id);
    });
    if (tonnage > 0) {
      sessionTonnage.offer(tonnage, session.workoutName, session.startedAt, session.id);
    }
  }

  for (final run in sortedRuns) {
    final pace = run.pacePerKm;
    if (pace == null) continue;
    fastestPace.offer(pace.inSeconds.toDouble(), 'Running', run.startedAt, run.id);
  }

  final records = <PersonalRecord>[
    for (final p in heaviestWeight.values) ?p.toRecord(PersonalRecordType.heaviestWeight),
    for (final p in mostReps.values) ?p.toRecord(PersonalRecordType.mostReps),
    for (final p in longestHold.values) ?p.toRecord(PersonalRecordType.longestHold),
    for (final p in bestEst1Rm.values) ?p.toRecord(PersonalRecordType.bestEst1Rm),
    ?sessionTonnage.toRecord(PersonalRecordType.sessionTonnage),
    ?fastestPace.toRecord(PersonalRecordType.fastestPace),
  ];

  // Multiple records can share the same `achievedAt` (several PRs set in
  // one session) — break ties by type, then label, so which ones surface
  // in a `.take(2)` "recent" slice is deterministic rather than dependent
  // on map-iteration order.
  records.sort((a, b) {
    final byDate = b.achievedAt.compareTo(a.achievedAt);
    if (byDate != 0) return byDate;
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    return a.label.compareTo(b.label);
  });
  return records;
}
