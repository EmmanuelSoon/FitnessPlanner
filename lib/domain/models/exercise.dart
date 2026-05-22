class Exercise {
  String name;
  int reps;
  int sets;
  Duration restTime;
  double weight;

  Exercise({
    required this.name,
    required this.reps,
    required this.sets,
    required this.restTime,
    this.weight = 0.0,
  });

  List<Exercise> generateSequence() {
    final List<Exercise> sequence = [];
    for (int i = 0; i < sets; i++) {
      sequence.add(
        Exercise(name: name, reps: reps, sets: 1, restTime: restTime, weight: weight),
      );
    }
    return sequence;
  }
}
