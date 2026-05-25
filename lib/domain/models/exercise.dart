class Exercise {
  String name;
  int reps;
  int sets;
  Duration restTime;
  double weight;
  /// Non-null ⇒ timed exercise (reps field ignored during warm-up).
  Duration? timedDuration;

  Exercise({
    required this.name,
    required this.reps,
    required this.sets,
    required this.restTime,
    this.weight = 0.0,
    this.timedDuration,
  });

  List<Exercise> generateSequence() {
    return List.generate(
      sets,
      (_) => Exercise(
        name: name,
        reps: reps,
        sets: 1,
        restTime: restTime,
        weight: weight,
        timedDuration: timedDuration,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'reps': reps,
    'sets': sets,
    'restTimeMicroseconds': restTime.inMicroseconds,
    'weight': weight,
    if (timedDuration != null)
      'timedDurationMicroseconds': timedDuration!.inMicroseconds,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    name: json['name'] as String,
    reps: json['reps'] as int,
    sets: json['sets'] as int,
    restTime: Duration(microseconds: json['restTimeMicroseconds'] as int),
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    timedDuration: json['timedDurationMicroseconds'] != null
        ? Duration(microseconds: json['timedDurationMicroseconds'] as int)
        : null,
  );
}
