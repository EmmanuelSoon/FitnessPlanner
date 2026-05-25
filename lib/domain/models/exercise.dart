class Exercise {
  String name;
  int reps;
  double weight;
  Duration? timedDuration; // if non-null → timed exercise; reps field ignored

  Exercise({
    required this.name,
    required this.reps,
    this.weight = 0.0,
    this.timedDuration,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'reps': reps,
    'weight': weight,
    if (timedDuration != null)
      'timedDurationMicroseconds': timedDuration!.inMicroseconds,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    name: json['name'] as String,
    reps: json['reps'] as int? ?? 10,
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    timedDuration: json['timedDurationMicroseconds'] != null
        ? Duration(microseconds: json['timedDurationMicroseconds'] as int)
        : null,
  );
}
