import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/day_override.dart';

void main() {
  group('DayOverride JSON round-trip', () {
    test('round-trips a setWorkout override', () {
      final override = DayOverride(
        mesocycleId: 'm1',
        date: DateTime(2026, 3, 2),
        kind: OverrideKind.setWorkout,
        workoutId: 'w1',
      );

      final restored = DayOverride.fromJson(override.toJson());

      expect(restored.mesocycleId, 'm1');
      expect(restored.date, DateTime(2026, 3, 2));
      expect(restored.kind, OverrideKind.setWorkout);
      expect(restored.workoutId, 'w1');
    });

    test('round-trips a rest override with no workoutId', () {
      final override = DayOverride(
        mesocycleId: 'm1',
        date: DateTime(2026, 3, 2),
        kind: OverrideKind.rest,
      );

      final restored = DayOverride.fromJson(override.toJson());

      expect(restored.kind, OverrideKind.rest);
      expect(restored.workoutId, isNull);
    });
  });
}
