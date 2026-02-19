import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/workout.dart';

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String _workoutName = '';
  final List<Exercise> _exercises = [];

  void _addExercise() {
    setState(() {
      _exercises.add(
        Exercise(
          name: '',
          reps: 1,
          sets: 1,
          restTime: const Duration(seconds: 30),
        ),
      );
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _submitWorkout() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final workout = Workout(name: _workoutName, exercises: _exercises);
      final sequence = workout.generateWorkoutSequence();
      // Navigate to preview screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WorkoutPreviewScreen(workout: workout, sequence: sequence),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Workout')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Workout Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a workout name';
                  }
                  return null;
                },
                onSaved: (value) {
                  setState(() {
                    _workoutName = value!;
                  });
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _exercises.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _exercises.length) {
                      return Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: _addExercise,
                          child: Text('Add Exercise'),
                        ),
                      );
                    }
                    final exercise = _exercises[index];
                    return ExerciseCard(
                      exercise: exercise,
                      onRemove: () => _removeExercise(index),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _submitWorkout,
                child: const Text('Generate Workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onRemove;
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Exercise: ${exercise.name}'),
            Row(
              children: [
                Text('Reps: ${exercise.reps}'),
                const SizedBox(width: 16),
                Text('Sets: ${exercise.sets}'),
                const SizedBox(width: 16),
                Text('Rest: ${exercise.restTime.inSeconds} sec'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onRemove, child: const Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutPreviewScreen extends StatelessWidget {
  final Workout workout;
  final List<Exercise> sequence;
  const WorkoutPreviewScreen({
    super.key,
    required this.workout,
    required this.sequence,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Workout Preview: ${workout.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Total Duration: ${workout.totalDuration.inSeconds} seconds'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: sequence.length,
                itemBuilder: (context, index) {
                  final exercise = sequence[index];
                  return ListTile(
                    title: Text('${exercise.name} x${exercise.sets}'),
                    subtitle: Text(
                      'Reps: ${exercise.reps} | Rest: ${exercise.restTime.inSeconds} sec',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
