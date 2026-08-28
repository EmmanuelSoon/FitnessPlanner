import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

void main() {
  group('CycleAdjustment JSON round-trip', () {
    test('round-trips with a targetCycleWeekIndex', () {
      final adj = CycleAdjustment(
        effectiveDate: DateTime(2026, 3, 2),
        type: AdjustmentType.earlyRest,
        targetCycleWeekIndex: 3,
      );

      final restored = CycleAdjustment.fromJson(adj.toJson());

      expect(restored.effectiveDate, DateTime(2026, 3, 2));
      expect(restored.type, AdjustmentType.earlyRest);
      expect(restored.targetCycleWeekIndex, 3);
    });

    test('round-trips with a null targetCycleWeekIndex', () {
      final adj = CycleAdjustment(
        effectiveDate: DateTime(2026, 3, 2),
        type: AdjustmentType.setCurrentWeek,
      );

      expect(CycleAdjustment.fromJson(adj.toJson()).targetCycleWeekIndex, isNull);
    });
  });

  group('Mesocycle JSON round-trip', () {
    test('round-trips full weekday maps and adjustments', () {
      final meso = Mesocycle(
        id: 'm1',
        name: 'Hypertrophy block',
        trainingWeeks: 4,
        restWeeks: 1,
        originalAnchor: DateTime(2026, 1, 5),
        weekdayWorkouts: {1: 'push', 2: null, 3: 'pull'},
        weekdayRuns: {
          2: const PlannedRun(type: RunType.easy, targetDistanceMeters: 5000),
          5: null,
        },
        adjustments: [
          CycleAdjustment(
            effectiveDate: DateTime(2026, 2, 2),
            type: AdjustmentType.earlyRest,
            targetCycleWeekIndex: 4,
          ),
        ],
      );

      final restored = Mesocycle.fromJson(meso.toJson());

      expect(restored.id, 'm1');
      expect(restored.name, 'Hypertrophy block');
      expect(restored.trainingWeeks, 4);
      expect(restored.restWeeks, 1);
      expect(restored.originalAnchor, DateTime(2026, 1, 5));
      expect(restored.weekdayWorkouts, {1: 'push', 2: null, 3: 'pull'});
      expect(restored.weekdayRuns[2]?.targetDistanceMeters, 5000);
      expect(restored.weekdayRuns[5], isNull);
      expect(restored.adjustments, hasLength(1));
      expect(restored.adjustments.first.targetCycleWeekIndex, 4);
    });

    test('defaults weekdayRuns and adjustments to empty when absent from JSON', () {
      final json = {
        'id': 'm1',
        'name': 'Minimal block',
        'trainingWeeks': 3,
        'restWeeks': 1,
        'originalAnchor': DateTime(2026, 1, 5).toIso8601String(),
        'weekdayWorkouts': <String, dynamic>{},
      };

      final restored = Mesocycle.fromJson(json);

      expect(restored.weekdayRuns, isEmpty);
      expect(restored.adjustments, isEmpty);
    });
  });

  group('copyWith', () {
    test('overrides only the given fields, keeping the rest', () {
      final meso = Mesocycle(
        id: 'm1',
        name: 'Original',
        trainingWeeks: 3,
        restWeeks: 1,
        originalAnchor: DateTime(2026, 1, 5),
        weekdayWorkouts: const {1: 'push'},
      );

      final copy = meso.copyWith(name: 'Renamed');

      expect(copy.id, 'm1');
      expect(copy.name, 'Renamed');
      expect(copy.trainingWeeks, 3);
      expect(copy.weekdayWorkouts, {1: 'push'});
    });
  });
}
