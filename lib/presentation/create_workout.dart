import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/providers/workout_providers.dart';

class CreateWorkoutScreen extends StatefulWidget {
  final Workout? existingWorkout;
  const CreateWorkoutScreen({super.key, this.existingWorkout});

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String _workoutName = '';
  final List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWorkout;
    if (existing != null) {
      _workoutName = existing.name;
      _exercises.addAll(existing.exercises.map(
        (e) => Exercise(
          name: e.name,
          reps: e.reps,
          sets: e.sets,
          restTime: e.restTime,
          weight: e.weight,
        ),
      ));
    }
  }

  void _addExercise() {
    setState(() {
      _exercises.add(
        Exercise(name: '', reps: 1, sets: 1, restTime: const Duration(seconds: 30)),
      );
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  Future<void> _submitWorkout() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_exercises.any((e) => e.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All exercises must have a name')),
      );
      return;
    }

    final workout = Workout(
      id: widget.existingWorkout?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _workoutName,
      exercises: _exercises,
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutPreviewScreen(
          workout: workout,
          sequence: workout.generateWorkoutSequence(),
        ),
      ),
    );
    if (saved == true) {
      if (widget.existingWorkout != null) {
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _exercises.clear());
        _formKey.currentState?.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingWorkout == null ? 'Create Workout' : 'Edit Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _workoutName,
                decoration: const InputDecoration(labelText: 'Workout Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Please enter a workout name' : null,
                onSaved: (v) => _workoutName = v!,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _exercises.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _exercises.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: _addExercise,
                          child: const Text('Add Exercise'),
                        ),
                      );
                    }
                    return ExerciseCard(
                      exercise: _exercises[index],
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

class ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onRemove;
  const ExerciseCard({super.key, required this.exercise, required this.onRemove});

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameCtrl = TextEditingController(text: e.name);
    _repsCtrl = TextEditingController(text: e.reps.toString());
    _setsCtrl = TextEditingController(text: e.sets.toString());
    _restCtrl = TextEditingController(text: e.restTime.inSeconds.toString());
    _weightCtrl = TextEditingController(text: e.weight.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _repsCtrl.dispose();
    _setsCtrl.dispose();
    _restCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Exercise Name'),
              onChanged: (v) => e.name = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repsCtrl,
                    decoration: const InputDecoration(labelText: 'Reps'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => e.reps = int.tryParse(v) ?? e.reps,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _setsCtrl,
                    decoration: const InputDecoration(labelText: 'Sets'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => e.sets = int.tryParse(v) ?? e.sets,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _restCtrl,
                    decoration: const InputDecoration(labelText: 'Rest (sec)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => e.restTime = Duration(seconds: int.tryParse(v) ?? e.restTime.inSeconds),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => e.weight = double.tryParse(v) ?? e.weight,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onRemove, child: const Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutPreviewScreen extends ConsumerStatefulWidget {
  final Workout workout;
  final List<Exercise> sequence;
  const WorkoutPreviewScreen({super.key, required this.workout, required this.sequence});

  @override
  ConsumerState<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends ConsumerState<WorkoutPreviewScreen> {
  Future<void> _saveWorkout() async {
    await ref.read(workoutsProvider.notifier).saveWorkout(widget.workout);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout saved!')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview: ${widget.workout.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Total Duration: ${widget.workout.totalDuration.inSeconds} seconds'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.sequence.length,
                itemBuilder: (context, index) {
                  final e = widget.sequence[index];
                  return ListTile(
                    title: Text('${e.name} x${e.reps}'),
                    subtitle: Text('Rest: ${e.restTime.inSeconds}s | Weight: ${e.weight}kg'),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _saveWorkout,
              child: const Text('Save Workout'),
            ),
          ],
        ),
      ),
    );
  }
}
