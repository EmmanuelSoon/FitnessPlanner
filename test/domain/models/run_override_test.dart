import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_override.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

void main() {
  group('RunOverride JSON round-trip', () {
    test('round-trips a setRun override with a nested PlannedRun', () {
      final override = RunOverride(
        mesocycleId: 'm1',
        date: DateTime(2026, 3, 2),
        kind: RunOverrideKind.setRun,
        plannedRun: const PlannedRun(type: RunType.long, targetDistanceMeters: 12000),
      );

      final restored = RunOverride.fromJson(override.toJson());

      expect(restored.mesocycleId, 'm1');
      expect(restored.date, DateTime(2026, 3, 2));
      expect(restored.kind, RunOverrideKind.setRun);
      expect(restored.plannedRun?.type, RunType.long);
      expect(restored.plannedRun?.targetDistanceMeters, 12000);
    });

    test('round-trips a clearRun override with no plannedRun', () {
      final override = RunOverride(
        mesocycleId: 'm1',
        date: DateTime(2026, 3, 2),
        kind: RunOverrideKind.clearRun,
      );

      final restored = RunOverride.fromJson(override.toJson());

      expect(restored.kind, RunOverrideKind.clearRun);
      expect(restored.plannedRun, isNull);
    });
  });
}
