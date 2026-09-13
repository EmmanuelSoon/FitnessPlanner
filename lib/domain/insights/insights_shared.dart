import 'package:fitness_planner/domain/models/workout_session.dart';

/// Above this rep count a set is cardiovascular rather than a strength
/// effort, and the Epley formula's error grows too large to trust —
/// [estimatedOneRm] returns null rather than fabricate a number.
const int kEpleyMaxReps = 12;

/// Epley-estimated one-rep max for a single set, or null when the set
/// carries no meaningful estimate: no weight (a bodyweight set belongs to
/// its own reps-based metric), no reps, or more reps than the formula is
/// valid for. A genuine one-rep set returns [weight] itself rather than
/// the formula's `weight * 1.033`, since there's nothing to estimate.
double? estimatedOneRm(double weight, int reps) {
  if (weight <= 0 || reps <= 0 || reps > kEpleyMaxReps) return null;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

/// [sessions] sorted oldest-first, without mutating the input list — shared
/// by every insights computation that needs sessions in chronological
/// order, so a rebuild doesn't re-sort the same list once per computation.
List<WorkoutSession> chronological(List<WorkoutSession> sessions) =>
    [...sessions]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
