import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

void main() {
  group('RunSession JSON round-trip', () {
    test('round-trips a fully populated manual run', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1, 7, 0),
        endedAt: DateTime(2026, 3, 1, 7, 30),
        distanceMeters: 5000,
        avgHeartRate: 150,
        calories: 320.5,
        cadenceSpm: 170,
        runType: RunType.tempo,
        notes: 'Felt good',
        source: RunSource.manual,
        externalId: 'hc-123',
      );

      final restored = RunSession.fromJson(run.toJson());

      expect(restored.id, 'r1');
      expect(restored.startedAt, run.startedAt);
      expect(restored.endedAt, run.endedAt);
      expect(restored.distanceMeters, 5000);
      expect(restored.avgHeartRate, 150);
      expect(restored.calories, 320.5);
      expect(restored.cadenceSpm, 170);
      expect(restored.runType, RunType.tempo);
      expect(restored.notes, 'Felt good');
      expect(restored.source, RunSource.manual);
      expect(restored.externalId, 'hc-123');
    });

    test('round-trips a minimal run, defaulting runType/source when absent', () {
      final json = {
        'id': 'r2',
        'startedAt': DateTime(2026, 3, 1, 7, 0).toIso8601String(),
        'endedAt': DateTime(2026, 3, 1, 7, 20).toIso8601String(),
        'distanceMeters': 3000.0,
      };

      final restored = RunSession.fromJson(json);

      expect(restored.runType, RunType.other);
      expect(restored.source, RunSource.manual);
      expect(restored.avgHeartRate, isNull);
      expect(restored.externalId, isNull);
    });
  });

  group('derived getters', () {
    test('duration is endedAt - startedAt', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1, 7, 0),
        endedAt: DateTime(2026, 3, 1, 7, 30),
        distanceMeters: 5000,
      );

      expect(run.duration, const Duration(minutes: 30));
    });

    test('distanceKm converts meters to km', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1, 7, 0),
        endedAt: DateTime(2026, 3, 1, 7, 30),
        distanceMeters: 5250,
      );

      expect(run.distanceKm, 5.25);
    });

    test('pacePerKm computes seconds-per-km rounded to the nearest second', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1, 7, 0),
        endedAt: DateTime(2026, 3, 1, 7, 25), // 25 min for 5km -> 5:00/km
        distanceMeters: 5000,
      );

      expect(run.pacePerKm, const Duration(minutes: 5));
      expect(run.formattedPace, '5:00');
    });

    test('pacePerKm is null when distance is zero, avoiding divide-by-zero', () {
      final run = RunSession(
        id: 'r1',
        startedAt: DateTime(2026, 3, 1, 7, 0),
        endedAt: DateTime(2026, 3, 1, 7, 25),
        distanceMeters: 0,
      );

      expect(run.pacePerKm, isNull);
      expect(run.formattedPace, '--:--');
    });
  });
}
