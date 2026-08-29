import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/domain/models/workout.dart';

import '../support/fixtures.dart';
import '../support/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  late Box<Workout> box;
  late WorkoutRepository repository;

  setUp(() async {
    tempDir = initTestHive();
    box = await Hive.openBox<Workout>('workouts');
    repository = WorkoutRepository(box);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('getAll() returns an empty list on an empty box', () {
    expect(repository.getAll(), isEmpty);
  });

  test('save() then getAll() round-trips a workout through the adapter', () async {
    final workout = buildWorkout();

    await repository.save(workout);

    final restored = repository.getAll().single;
    expect(restored.id, workout.id);
    expect(restored.name, workout.name);
    expect(restored.exercises.single.exercises, hasLength(2));
  });

  test('delete() removes the workout', () async {
    final workout = buildWorkout();
    await repository.save(workout);

    await repository.delete(workout.id);

    expect(repository.getAll(), isEmpty);
  });
}
