import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

import '../support/fixtures.dart';
import '../support/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  late Box<RunSession> box;
  late RunRepository repository;

  setUp(() async {
    tempDir = initTestHive();
    box = await Hive.openBox<RunSession>('runs');
    repository = RunRepository(box);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('getAll() returns an empty list on an empty box', () {
    expect(repository.getAll(), isEmpty);
  });

  test('save() then getAll() round-trips a run through the adapter', () async {
    final run = buildRunSession();

    await repository.save(run);

    final restored = repository.getAll().single;
    expect(restored.id, run.id);
    expect(restored.distanceMeters, run.distanceMeters);
    expect(restored.runType, run.runType);
  });

  test('delete() removes the run', () async {
    final run = buildRunSession();
    await repository.save(run);

    await repository.delete(run.id);

    expect(repository.getAll(), isEmpty);
  });

  test('getAll() sorts by startedAt, newest first', () async {
    final older = buildRunSession(id: 'r-older', startedAt: DateTime(2026, 1, 1));
    final newer = buildRunSession(id: 'r-newer', startedAt: DateTime(2026, 1, 10));

    await repository.save(older);
    await repository.save(newer);

    final all = repository.getAll();
    expect(all.map((r) => r.id), [newer.id, older.id]);
  });

  test('forDate() returns only runs started on the given calendar day', () async {
    final onDate = buildRunSession(id: 'r-on', startedAt: DateTime(2026, 1, 5, 7));
    final otherDate = buildRunSession(id: 'r-other', startedAt: DateTime(2026, 1, 6, 7));

    await repository.save(onDate);
    await repository.save(otherDate);

    final result = repository.forDate(DateTime(2026, 1, 5));

    expect(result.map((r) => r.id), [onDate.id]);
  });

  test('exists() returns true only for a stored id', () async {
    final run = buildRunSession();
    await repository.save(run);

    expect(repository.exists(run.id), isTrue);
    expect(repository.exists('missing'), isFalse);
  });
}
