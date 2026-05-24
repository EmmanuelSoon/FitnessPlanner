class LoggedSet {
  final String exerciseName;
  final int targetReps;
  final double targetWeight;
  final int actualReps;
  final double actualWeight;
  final bool skipped;

  LoggedSet({
    required this.exerciseName,
    required this.targetReps,
    required this.targetWeight,
    required this.actualReps,
    required this.actualWeight,
    required this.skipped,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'targetReps': targetReps,
    'targetWeight': targetWeight,
    'actualReps': actualReps,
    'actualWeight': actualWeight,
    'skipped': skipped,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseName: json['exerciseName'] as String,
    targetReps: json['targetReps'] as int,
    targetWeight: (json['targetWeight'] as num).toDouble(),
    actualReps: json['actualReps'] as int,
    actualWeight: (json['actualWeight'] as num).toDouble(),
    skipped: json['skipped'] as bool,
  );
}
