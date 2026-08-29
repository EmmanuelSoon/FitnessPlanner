import 'package:fitness_planner/domain/models/day_override.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_override.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

/// Small builder functions for the test objects used across repository,
/// provider, and widget tests. Every field is overridable via named params.

Workout buildWorkout({String id = 'w1', String name = 'Push Day'}) => Workout(
  id: id,
  name: name,
  exercises: [
    Superset(
      id: 'sup1',
      exercises: [
        Exercise(
          name: 'Bench Press',
          reps: 8,
          sets: 3,
          restTime: const Duration(seconds: 90),
          weight: 60,
        ),
        Exercise(
          name: 'Incline Fly',
          reps: 10,
          sets: 3,
          restTime: const Duration(seconds: 60),
        ),
      ],
      sets: 3,
      restAfterSet: const Duration(seconds: 90),
    ),
  ],
);

WorkoutSession buildWorkoutSession({
  String id = 'ws1',
  String workoutId = 'w1',
  DateTime? startedAt,
}) {
  final start = startedAt ?? DateTime(2026, 1, 5, 9);
  return WorkoutSession(
    id: id,
    workoutId: workoutId,
    workoutName: 'Push Day',
    startedAt: start,
    endedAt: start.add(const Duration(hours: 1)),
    completed: true,
    sets: [
      LoggedSet(
        exerciseName: 'Bench Press',
        targetReps: 8,
        targetWeight: 60,
        actualReps: 8,
        actualWeight: 60,
        skipped: false,
      ),
    ],
  );
}

Mesocycle buildMesocycle({String id = 'm1', String name = 'Hypertrophy block'}) =>
    Mesocycle(
      id: id,
      name: name,
      trainingWeeks: 4,
      restWeeks: 1,
      originalAnchor: DateTime(2026, 1, 5),
      weekdayWorkouts: const {1: 'w1', 2: null, 3: 'w1'},
    );

RunSession buildRunSession({String id = 'r1', DateTime? startedAt}) {
  final start = startedAt ?? DateTime(2026, 1, 5, 7);
  return RunSession(
    id: id,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 30)),
    distanceMeters: 5000,
    runType: RunType.easy,
  );
}

DayOverride buildDayOverride({
  String mesocycleId = 'm1',
  DateTime? date,
  OverrideKind kind = OverrideKind.rest,
  String? workoutId,
}) => DayOverride(
  mesocycleId: mesocycleId,
  date: date ?? DateTime(2026, 1, 6),
  kind: kind,
  workoutId: workoutId,
);

RunOverride buildRunOverride({
  String mesocycleId = 'm1',
  DateTime? date,
  RunOverrideKind kind = RunOverrideKind.setRun,
  PlannedRun? plannedRun,
}) => RunOverride(
  mesocycleId: mesocycleId,
  date: date ?? DateTime(2026, 1, 6),
  kind: kind,
  plannedRun:
      plannedRun ??
      (kind == RunOverrideKind.setRun
          ? const PlannedRun(type: RunType.easy, targetDistanceMeters: 5000)
          : null),
);
