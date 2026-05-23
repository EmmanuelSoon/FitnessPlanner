import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/domain/models/workout.dart';

final workoutsProvider =
    AsyncNotifierProvider<WorkoutsNotifier, List<Workout>>(WorkoutsNotifier.new);

class WorkoutsNotifier extends AsyncNotifier<List<Workout>> {
  @override
  Future<List<Workout>> build() async => ref.read(workoutRepositoryProvider).getAll();

  Future<void> saveWorkout(Workout workout) async {
    await ref.read(workoutRepositoryProvider).save(workout);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteWorkout(String id) async {
    await ref.read(workoutRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}
