class Exercise {
  String name;
  int reps;
  int sets;
  Duration restTime;

  Exercise({
    required this.name,
    required this.reps,
    required this.sets,
    required this.restTime,
  });

  // Generate exercise sequence based on sets
  List<Exercise> generateSequence() {
    final List<Exercise> sequence = [];
    for (int i = 0; i < sets; i++) {
      sequence.add(
        Exercise(name: name, reps: reps, sets: 1, restTime: restTime),
      );
    }
    return sequence;
  }
}
