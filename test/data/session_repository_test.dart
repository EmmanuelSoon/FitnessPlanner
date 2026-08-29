import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

import '../support/fixtures.dart';
import '../support/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  late Box<WorkoutSession> box;
  late SessionRepository repository;

  setUp(() async {
    tempDir = initTestHive();
    box = await Hive.openBox<WorkoutSession>('sessions');
    repository = SessionRepository(box);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('getAll() returns an empty list on an empty box', () {
    expect(repository.getAll(), isEmpty);
  });

  test('save() then getAll() round-trips a session through the adapter', () async {
    final session = buildWorkoutSession();

    await repository.save(session);

    final restored = repository.getAll().single;
    expect(restored.id, session.id);
    expect(restored.workoutId, session.workoutId);
    expect(restored.sets, hasLength(1));
  });

  test('delete() removes the session', () async {
    final session = buildWorkoutSession();
    await repository.save(session);

    await repository.delete(session.id);

    expect(repository.getAll(), isEmpty);
  });

  test('getAll() sorts by startedAt, newest first', () async {
    final older = buildWorkoutSession(id: 'ws-older', startedAt: DateTime(2026, 1, 1));
    final newer = buildWorkoutSession(id: 'ws-newer', startedAt: DateTime(2026, 1, 10));

    await repository.save(older);
    await repository.save(newer);

    final all = repository.getAll();
    expect(all.map((s) => s.id), [newer.id, older.id]);
  });
}
