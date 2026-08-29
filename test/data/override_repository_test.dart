import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/data/override_repository.dart';
import 'package:fitness_planner/domain/models/day_override.dart';

import '../support/fixtures.dart';
import '../support/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  late Box<DayOverride> box;
  late OverrideRepository repository;

  setUp(() async {
    tempDir = initTestHive();
    box = await Hive.openBox<DayOverride>('overrides');
    repository = OverrideRepository(box);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('get() returns null when no override is set for the date', () {
    expect(repository.get('m1', DateTime(2026, 1, 6)), isNull);
  });

  test('save() then get() round-trips an override through the adapter', () async {
    final override = buildDayOverride(
      kind: OverrideKind.setWorkout,
      workoutId: 'w1',
    );

    await repository.save(override);

    final restored = repository.get(override.mesocycleId, override.date);
    expect(restored, isNotNull);
    expect(restored!.kind, OverrideKind.setWorkout);
    expect(restored.workoutId, 'w1');
  });

  test('forMeso() returns only overrides for the given mesocycle', () async {
    await repository.save(buildDayOverride(mesocycleId: 'm1', date: DateTime(2026, 1, 6)));
    await repository.save(buildDayOverride(mesocycleId: 'm2', date: DateTime(2026, 1, 6)));

    final result = repository.forMeso('m1');

    expect(result, hasLength(1));
    expect(result.single.mesocycleId, 'm1');
  });

  test('clear() removes the override for the date', () async {
    final override = buildDayOverride();
    await repository.save(override);

    await repository.clear(override.mesocycleId, override.date);

    expect(repository.get(override.mesocycleId, override.date), isNull);
  });
}
