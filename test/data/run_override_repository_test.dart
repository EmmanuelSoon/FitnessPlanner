import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/data/run_override_repository.dart';
import 'package:fitness_planner/domain/models/run_override.dart';

import '../support/fixtures.dart';
import '../support/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  late Box<RunOverride> box;
  late RunOverrideRepository repository;

  setUp(() async {
    tempDir = initTestHive();
    box = await Hive.openBox<RunOverride>('run_overrides');
    repository = RunOverrideRepository(box);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('get() returns null when no override is set for the date', () {
    expect(repository.get('m1', DateTime(2026, 1, 6)), isNull);
  });

  test('save() then get() round-trips a setRun override through the adapter', () async {
    final override = buildRunOverride();

    await repository.save(override);

    final restored = repository.get(override.mesocycleId, override.date);
    expect(restored, isNotNull);
    expect(restored!.kind, RunOverrideKind.setRun);
    expect(restored.plannedRun?.targetDistanceMeters, 5000);
  });

  test('save() then get() round-trips a clearRun override with a null plannedRun', () async {
    final override = buildRunOverride(kind: RunOverrideKind.clearRun);

    await repository.save(override);

    final restored = repository.get(override.mesocycleId, override.date);
    expect(restored!.kind, RunOverrideKind.clearRun);
    expect(restored.plannedRun, isNull);
  });

  test('forMeso() returns only overrides for the given mesocycle', () async {
    await repository.save(buildRunOverride(mesocycleId: 'm1', date: DateTime(2026, 1, 6)));
    await repository.save(buildRunOverride(mesocycleId: 'm2', date: DateTime(2026, 1, 6)));

    final result = repository.forMeso('m1');

    expect(result, hasLength(1));
    expect(result.single.mesocycleId, 'm1');
  });

  test('clear() removes the override for the date', () async {
    final override = buildRunOverride();
    await repository.save(override);

    await repository.clear(override.mesocycleId, override.date);

    expect(repository.get(override.mesocycleId, override.date), isNull);
  });
}
