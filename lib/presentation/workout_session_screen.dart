import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/providers/session_providers.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  final Workout workout;
  const WorkoutSessionScreen({super.key, required this.workout});

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late final List<Exercise> _sequence;
  late final DateTime _startedAt;

  int _index = 0;
  final List<LoggedSet> _logged = [];

  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;
  bool _isPaused = false;

  final _actualRepsCtrl = TextEditingController();
  final _actualWeightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sequence = widget.workout.generateWorkoutSequence();
    _startedAt = DateTime.now();
    _prefillControllers();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _actualRepsCtrl.dispose();
    _actualWeightCtrl.dispose();
    super.dispose();
  }

  void _prefillControllers() {
    if (_index < _sequence.length) {
      final e = _sequence[_index];
      _actualRepsCtrl.text = e.reps.toString();
      _actualWeightCtrl.text = e.weight.toString();
    }
  }

  void _finishSet() {
    final e = _sequence[_index];
    final actualReps = int.tryParse(_actualRepsCtrl.text) ?? e.reps;
    final actualWeight = double.tryParse(_actualWeightCtrl.text) ?? e.weight;
    _logged.add(LoggedSet(
      exerciseName: e.name,
      targetReps: e.reps,
      targetWeight: e.weight,
      actualReps: actualReps,
      actualWeight: actualWeight,
      skipped: false,
    ));
    _advance();
  }

  void _skipSet() {
    final e = _sequence[_index];
    _logged.add(LoggedSet(
      exerciseName: e.name,
      targetReps: e.reps,
      targetWeight: e.weight,
      actualReps: 0,
      actualWeight: 0,
      skipped: true,
    ));
    _advance();
  }

  void _advance() {
    if (_index >= _sequence.length - 1) {
      _finishWorkout(completed: true);
      return;
    }
    final restSeconds = _sequence[_index].restTime.inSeconds;
    setState(() {
      _isResting = true;
      _restSecondsRemaining = restSeconds;
      _isPaused = false;
    });
    _startRestTimer();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _restSecondsRemaining--);
      if (_restSecondsRemaining <= 3 && _restSecondsRemaining > 0) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
      }
      if (_restSecondsRemaining <= 0) {
        t.cancel();
        _endRest();
      }
    });
  }

  void _togglePause() {
    if (_isPaused) {
      setState(() => _isPaused = false);
      _startRestTimer();
    } else {
      _restTimer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  void _skipRest() {
    _restTimer?.cancel();
    _endRest();
  }

  void _endRest() {
    setState(() {
      _index++;
      _isResting = false;
      _isPaused = false;
    });
    _prefillControllers();
  }

  Future<void> _finishWorkout({required bool completed}) async {
    _restTimer?.cancel();
    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workoutId: widget.workout.id,
      workoutName: widget.workout.name,
      startedAt: _startedAt,
      endedAt: DateTime.now(),
      completed: completed,
      sets: List.unmodifiable(_logged),
    );
    await ref.read(sessionsProvider.notifier).saveSession(session);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(completed ? 'Workout complete!' : 'Progress saved.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _handleBackPressed() async {
    if (_logged.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit workout?'),
        content: const Text('Save your partial progress to history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _finishWorkout(completed: false);
    } else if (choice == 'discard') {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout.name),
          leading: BackButton(onPressed: _handleBackPressed),
          actions: _isResting
              ? [
                  IconButton(
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    onPressed: _togglePause,
                  ),
                ]
              : [],
        ),
        body: _isResting ? _buildRestView() : _buildExerciseView(),
      ),
    );
  }

  Widget _buildExerciseView() {
    final e = _sequence[_index];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set ${_index + 1} of ${_sequence.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(e.name, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Target: ${e.reps} reps${e.weight > 0 ? ' × ${e.weight}kg' : ''}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _actualRepsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Actual Reps'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _actualWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _finishSet,
            child: const Text('Finish Set'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _skipSet,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestView() {
    final nextIndex = _index + 1;
    final nextExercise =
        nextIndex < _sequence.length ? _sequence[nextIndex] : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isPaused ? 'Paused' : 'Rest',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            '$_restSecondsRemaining',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _restSecondsRemaining <= 3 ? Colors.red : null,
                ),
          ),
          if (nextExercise != null) ...[
            const SizedBox(height: 24),
            Text(
              'Up next: ${nextExercise.name} × ${nextExercise.reps} reps'
              '${nextExercise.weight > 0 ? ' (${nextExercise.weight}kg)' : ''}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 32),
          TextButton(
            onPressed: _skipRest,
            child: const Text('Skip Rest'),
          ),
        ],
      ),
    );
  }
}
