enum OverrideKind { setWorkout, rest }

class DayOverride {
  final String mesocycleId;
  final DateTime date; // normalized to 00:00 local
  final OverrideKind kind;
  final String? workoutId; // required when kind == setWorkout

  const DayOverride({
    required this.mesocycleId,
    required this.date,
    required this.kind,
    this.workoutId,
  });

  Map<String, dynamic> toJson() => {
    'mesocycleId': mesocycleId,
    'date': date.toIso8601String(),
    'kind': kind.name,
    if (workoutId != null) 'workoutId': workoutId,
  };

  factory DayOverride.fromJson(Map<String, dynamic> json) => DayOverride(
    mesocycleId: json['mesocycleId'] as String,
    date: DateTime.parse(json['date'] as String),
    kind: OverrideKind.values.byName(json['kind'] as String),
    workoutId: json['workoutId'] as String?,
  );
}
