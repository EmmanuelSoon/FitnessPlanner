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
        .map(
          (s) => Superset(
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
          ),
        )
        .toList();
  }

  // ─── Exercise rows (mirrors create_workout.dart's superset grouping) ──
  List<Widget> _buildExerciseRows() {
    final items = <({int supersetIdx, Superset superset, Exercise exercise})>[];
    for (int si = 0; si < _exercises.length; si++) {
      for (final ex in _exercises[si].exercises) {
        items.add((supersetIdx: si, superset: _exercises[si], exercise: ex));
      }
    }

    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isSingle = item.superset.exercises.length == 1;
      final exIdx = item.superset.exercises.indexOf(item.exercise);
      final isFirstInGroup = exIdx == 0;
      final isLastInGroup = exIdx == item.superset.exercises.length - 1;

      result.add(
        _PreviewExerciseCard(
          superset: item.superset,
          exercise: item.exercise,
          showSets: isSingle || isFirstInGroup,
          showRest: isSingle || isLastInGroup,
          isInGroup: !isSingle,
          onRepsChanged: (v) => setState(() => item.exercise.reps = v),
          onWeightChanged: (v) => setState(() => item.exercise.weight = v),
          onSetsChanged: (v) => setState(() => item.superset.sets = v),
          onRestChanged: (v) => setState(() => item.superset.restAfterSet = v),
        ),
      );

      final isLast = i == items.length - 1;
      if (!isLast && items[i + 1].supersetIdx == item.supersetIdx) {
        result.add(const _GroupConnector());
      } else if (!isLast) {
        result.add(const SizedBox(height: 10));
      }
    }
    return result;
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
                children: _buildExerciseRows(),
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

// Mirrors the visual language of create_workout.dart's _ExerciseSlotCard
// (index pill, superset badge, field grid) — lets you tweak sets, reps,
// weight, and rest for today's session without renaming/removing exercises
// or changing timed-hold duration.
class _PreviewExerciseCard extends StatelessWidget {
  final Superset superset;
  final Exercise exercise;
  final bool showSets;
  final bool showRest;
  final bool isInGroup;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onSetsChanged;
  final ValueChanged<Duration> onRestChanged;

  const _PreviewExerciseCard({
    required this.superset,
    required this.exercise,
    required this.showSets,
    required this.showRest,
    required this.isInGroup,
    required this.onRepsChanged,
    required this.onWeightChanged,
    required this.onSetsChanged,
    required this.onRestChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final isTimed = exercise.timedDuration != null;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isInGroup
                      ? c.accent.withValues(alpha: 0.15)
                      : c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 12,
                  color: isInGroup ? c.accent : c.inkDim,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exercise.name,
                  style: bodyStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (isTimed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⏱ Timed',
                    style: bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.inkDim,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (showSets) ...[
                _TappableField(
                  label: 'SETS',
                  value: '${superset.sets}',
                  onTap: () =>
                      openSetsPicker(context, superset.sets, onSetsChanged),
                ),
                const SizedBox(width: 6),
              ],
              if (isTimed)
                _ReadOnlyField(
                  label: 'DURATION',
                  value: '${exercise.timedDuration!.inSeconds}s',
                )
              else
                _TappableField(
                  label: 'REPS',
                  value: '${exercise.reps}',
                  onTap: () =>
                      openRepsPicker(context, exercise.reps, onRepsChanged),
                ),
              const SizedBox(width: 6),
              _TappableField(
                label: 'WEIGHT',
                value: '${fmtWeight(exercise.weight)} kg',
                onTap: () =>
                    openWeightPicker(context, exercise.weight, onWeightChanged),
              ),
              if (showRest) ...[
                const SizedBox(width: 6),
                _TappableField(
                  label: 'REST',
                  value: _fmtDuration(superset.restAfterSet),
                  onTap: () => openDurationPicker(
                    context,
                    'REST',
                    superset.restAfterSet,
                    onRestChanged,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Static accent connector between grouped superset cards ──────────────
class _GroupConnector extends StatelessWidget {
  const _GroupConnector();

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          margin: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'SUPERSET',
            style: bodyStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: c.accent,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(kRadius - 6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: bodyStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: c.inkMute,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: displayStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.inkDim,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TappableField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(kRadius - 6),
            border: Border.all(color: c.hairlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: bodyStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.inkMute,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: displayStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
