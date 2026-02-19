import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'exercise.dart';

class Workout {
  final String name;
  final List<Exercise> exercises;

  Workout({required this.name, required this.exercises});

  // Generate complete workout sequence
  List<Exercise> generateWorkoutSequence() {
    final List<Exercise> sequence = [];
    for (final exercise in exercises) {
      sequence.addAll(
        List.generate(
          exercise.sets,
          (index) => Exercise(
            name: exercise.name,
            reps: exercise.reps,
            sets: 1,
            restTime: exercise.restTime,
          ),
        ),
      );
    }
    return sequence;
  }

  // Get total duration of workout
  Duration get totalDuration {
    Duration total = Duration.zero;
    final sequence = generateWorkoutSequence();

    for (int i = 0; i < sequence.length; i++) {
      total += const Duration(seconds: 30); // Exercise time
      if (i < sequence.length - 1) {
        total += sequence[i].restTime;
      }
    }

    return total;
  }
}
