class LoggedSet {
  final String exerciseName;
  final int targetReps;
  final double targetWeight;
  final int actualReps;
  final double actualWeight;
  final bool skipped;
  final int? heldSeconds;
  final int? targetSeconds;
  /// Muscle group tag, denormalized from the source [Exercise] at log time —
  /// null when the exercise was never manually tagged, in which case
  /// downstream consumers fall back to a library lookup by name.
  final String? category;

  LoggedSet({
    required this.exerciseName,
    required this.targetReps,
    required this.targetWeight,
    required this.actualReps,
    required this.actualWeight,
    required this.skipped,
    this.heldSeconds,
    this.targetSeconds,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'targetReps': targetReps,
    'targetWeight': targetWeight,
    'actualReps': actualReps,
    'actualWeight': actualWeight,
    'skipped': skipped,
    if (heldSeconds != null) 'heldSeconds': heldSeconds,
    if (targetSeconds != null) 'targetSeconds': targetSeconds,
    if (category != null) 'category': category,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseName: json['exerciseName'] as String,
    targetReps: json['targetReps'] as int,
    targetWeight: (json['targetWeight'] as num).toDouble(),
    actualReps: json['actualReps'] as int,
    actualWeight: (json['actualWeight'] as num).toDouble(),
    skipped: json['skipped'] as bool,
    heldSeconds: json['heldSeconds'] as int?,
    targetSeconds: json['targetSeconds'] as int?,
    category: json['category'] as String?,
  );
}
