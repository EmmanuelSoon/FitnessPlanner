import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/data/mesocycle_repository.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';

import '../support/fixtures.dart';
import '../support/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  late Box<Mesocycle> box;
  late MesocycleRepository repository;

  setUp(() async {
    tempDir = initTestHive();
    box = await Hive.openBox<Mesocycle>('mesocycles');
    repository = MesocycleRepository(box);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('getAll() returns an empty list on an empty box', () {
    expect(repository.getAll(), isEmpty);
  });

  test('save() then getAll() round-trips a mesocycle through the adapter', () async {
    final meso = buildMesocycle();

    await repository.save(meso);

    final restored = repository.getAll().single;
    expect(restored.id, meso.id);
    expect(restored.name, meso.name);
    expect(restored.weekdayWorkouts, meso.weekdayWorkouts);
  });

  test('delete() removes the mesocycle', () async {
    final meso = buildMesocycle();
    await repository.save(meso);

    await repository.delete(meso.id);

    expect(repository.getAll(), isEmpty);
  });
}
