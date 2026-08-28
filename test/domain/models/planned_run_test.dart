import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

void main() {
  group('PlannedRun JSON round-trip', () {
    test('round-trips a run with distance and duration targets', () {
      const run = PlannedRun(
        type: RunType.long,
        targetDistanceMeters: 10000,
        targetDuration: Duration(minutes: 55),
      );

      final restored = PlannedRun.fromJson(run.toJson());

      expect(restored.type, RunType.long);
      expect(restored.targetDistanceMeters, 10000);
      expect(restored.targetDuration, const Duration(minutes: 55));
    });

    test('round-trips a run with no targets set', () {
      const run = PlannedRun(type: RunType.easy);

      final restored = PlannedRun.fromJson(run.toJson());

      expect(restored.targetDistanceMeters, isNull);
      expect(restored.targetDuration, isNull);
    });
  });

  group('targetDistanceKm', () {
    test('converts meters to km', () {
      const run = PlannedRun(type: RunType.easy, targetDistanceMeters: 7500);
      expect(run.targetDistanceKm, 7.5);
    });

    test('is null when no distance target is set', () {
      const run = PlannedRun(type: RunType.easy);
      expect(run.targetDistanceKm, isNull);
    });
  });

  group('summaryLabel', () {
    test('includes only the parts that are set, formatting whole km without a decimal', () {
      const run = PlannedRun(type: RunType.easy, targetDistanceMeters: 5000);
      expect(run.summaryLabel, 'Easy · 5 km');
    });

    test('includes a fractional km and a duration when both are set', () {
      const run = PlannedRun(
        type: RunType.tempo,
        targetDistanceMeters: 8300,
        targetDuration: Duration(minutes: 40),
      );
      expect(run.summaryLabel, 'Tempo · 8.3 km · 40 min');
    });

    test('is just the type label when no targets are set', () {
      const run = PlannedRun(type: RunType.race);
      expect(run.summaryLabel, 'Race');
    });

    test('labels every RunType', () {
      const labels = {
        RunType.easy: 'Easy',
        RunType.tempo: 'Tempo',
        RunType.interval: 'Interval',
        RunType.long: 'Long',
        RunType.race: 'Race',
        RunType.treadmill: 'Treadmill',
        RunType.other: 'Run',
      };
      for (final entry in labels.entries) {
        expect(PlannedRun(type: entry.key).summaryLabel, entry.value);
      }
    });
  });
}
