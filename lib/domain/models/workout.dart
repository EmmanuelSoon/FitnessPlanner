import 'exercise.dart';

class Workout {
  final String id;
  final String name;
  final List<Exercise> exercises;

  Workout({required this.id, required this.name, required this.exercises});

  List<Exercise> generateWorkoutSequence() {
    return exercises.expand((e) => e.generateSequence()).toList();
  }

  Duration get totalDuration {
    final sequence = generateWorkoutSequence();
    Duration total = Duration.zero;
    for (int i = 0; i < sequence.length; i++) {
      total += const Duration(seconds: 30);
      if (i < sequence.length - 1) total += sequence[i].restTime;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
    id: json['id'] as String,
    name: json['name'] as String,
    exercises: (json['exercises'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
