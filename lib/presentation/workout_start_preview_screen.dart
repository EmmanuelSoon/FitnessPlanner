import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/presentation/warmup_screen.dart';
import 'package:fitness_planner/presentation/workout_session_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/number_picker_sheet.dart';
import 'package:fitness_planner/theme/app_theme.dart';

// ─── Preview a workout before starting it ─────────────────────────────────
//
// Prefills each exercise's reps/weight from the most recent prior session
// for this workout (falling back to the workout's own template values),
// and lets the user tweak them before starting the live session.

class WorkoutStartPreviewScreen extends ConsumerStatefulWidget {
  final Workout workout;
  const WorkoutStartPreviewScreen({super.key, required this.workout});

  @override
  ConsumerState<WorkoutStartPreviewScreen> createState() =>
      _WorkoutStartPreviewScreenState();
}

class _WorkoutStartPreviewScreenState
    extends ConsumerState<WorkoutStartPreviewScreen> {
  late final List<Superset> _exercises;

  @override
  void initState() {
    super.initState();

    final sessions = ref.read(sessionsProvider).asData?.value ?? [];
    WorkoutSession? lastSession;
    for (final s in sessions) {
      if (s.workoutId == widget.workout.id) {
        lastSession = s;
        break;
      }
    }

    LoggedSet? lastSetFor(String exerciseName) {
      if (lastSession == null) return null;
      for (final s in lastSession.sets.reversed) {
        if (s.exerciseName == exerciseName) return s;
      }
      return null;
    }

    // Deep-copy the workout's supersets so edits here don't mutate the
    // cached Workout, prefilling reps/weight from the last session.
    _exercises = widget.workout.exercises
        .map((s) => Superset(
              id: s.id,
              sets: s.sets,
              restAfterSet: s.restAfterSet,
              exercises: s.exercises.map((e) {
                final last = lastSetFor(e.name);
                return Exercise(
                  name: e.name,
                  reps: last?.actualReps ?? e.reps,
                  sets: e.sets,
                  restTime: e.restTime,
                  weight: last?.actualWeight ?? e.weight,
                  timedDuration: e.timedDuration,
                );
              }).toList(),
            ))
        .toList();
  }

  void _start() {
    final adjusted = Workout(
      id: widget.workout.id,
      name: widget.workout.name,
      exercises: _exercises,
      warmup: widget.workout.warmup,
      icon: widget.workout.icon,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => adjusted.warmup.isNotEmpty
            ? WarmupScreen(workout: adjusted)
            : WorkoutSessionScreen(workout: adjusted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.workout.name,
                  style: displayStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final superset in _exercises)
                    for (final ex in superset.exercises)
                      _PreviewExerciseTile(
                        exercise: ex,
                        sets: superset.sets,
                        onRepsChanged: (v) => setState(() => ex.reps = v),
                        onWeightChanged: (v) =>
                            setState(() => ex.weight = v),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AppButton(
                label: 'Start workout',
                icon: Icons.play_arrow_rounded,
                full: true,
                onPressed: _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final int sets;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<double> onWeightChanged;

  const _PreviewExerciseTile({
    required this.exercise,
    required this.sets,
    required this.onRepsChanged,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final isTimed = exercise.timedDuration != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: bodyStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sets ${sets == 1 ? 'set' : 'sets'}',
                  style: bodyStyle(fontSize: 12, color: c.inkMute),
                ),
              ],
            ),
          ),
          if (isTimed)
            Text(
              '${exercise.timedDuration!.inSeconds}s hold',
              style: bodyStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.inkDim,
              ),
            )
          else ...[
            _PreviewValue(
              label: 'reps',
              value: '${exercise.reps}',
              c: c,
              onTap: () =>
                  openRepsPicker(context, exercise.reps, onRepsChanged),
            ),
            const SizedBox(width: 20),
            _PreviewValue(
              label: 'kg',
              value: fmtWeight(exercise.weight),
              c: c,
              onTap: () =>
                  openWeightPicker(context, exercise.weight, onWeightChanged),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewValue extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;
  final VoidCallback onTap;

  const _PreviewValue({
    required this.label,
    required this.value,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: displayStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: c.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: bodyStyle(fontSize: 10, color: c.inkMute),
          ),
        ],
      ),
    );
  }
}
