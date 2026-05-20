import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/workout.dart';

const _kWorkoutsBox = 'workouts';

class WorkoutRepository {
  final Box<Workout> _box;

  WorkoutRepository(this._box);

  List<Workout> getAll() => _box.values.toList();

  Future<void> save(Workout workout) => _box.put(workout.id, workout);

  Future<void> delete(String id) => _box.delete(id);
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(Hive.box<Workout>(_kWorkoutsBox));
});
