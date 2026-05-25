import 'exercise.dart';

/// A single execution step in a flattened workout sequence.
/// Supersets produce multiple consecutive slots sharing the same [supersetId].
class WorkoutSlot {
  final Exercise exercise;
  final int setNum;           // 1-based set index within the superset
  final int totalSets;        // total sets in this superset
  final Duration restAfter;   // Duration.zero → instant next step (intra-superset)
  final String supersetId;    // groups all slots that belong to the same Superset
  final bool isIntraSuperset; // true if next slot is part of same superset set (no rest)

  const WorkoutSlot({
    required this.exercise,
    required this.setNum,
    required this.totalSets,
    required this.restAfter,
    required this.supersetId,
    required this.isIntraSuperset,
  });
}
