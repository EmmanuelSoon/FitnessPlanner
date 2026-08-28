import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/day_override.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_override.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/schedule/schedule_logic.dart';

void main() {
  group('mondayOf / normalizeDate', () {
    test('mondayOf returns the Monday 00:00 of the containing week', () {
      // 2026-01-07 is a Wednesday.
      final wed = DateTime(2026, 1, 7, 15, 30);
      expect(mondayOf(wed), DateTime(2026, 1, 5));
    });

    test('mondayOf is idempotent on a Monday', () {
      final mon = DateTime(2026, 1, 5, 9);
      expect(mondayOf(mon), DateTime(2026, 1, 5));
    });

    test('normalizeDate strips the time-of-day', () {
      expect(normalizeDate(DateTime(2026, 3, 2, 23, 59)), DateTime(2026, 3, 2));
    });
  });

  group('cycleWeekIndexForDate / isRestWeek', () {
    final anchor = mondayOf(DateTime(2026, 1, 1));
    final meso = Mesocycle(
      id: 'm1',
      name: 'Test block',
      trainingWeeks: 3,
      restWeeks: 1,
      originalAnchor: anchor,
      weekdayWorkouts: const {},
    );

    test('week 0 at the anchor is training', () {
      expect(cycleWeekIndexForDate(meso, anchor), 0);
      expect(isRestWeek(meso, anchor), isFalse);
    });

    test('advances one index per week through the cycle', () {
      expect(cycleWeekIndexForDate(meso, anchor.add(const Duration(days: 7))), 1);
      expect(cycleWeekIndexForDate(meso, anchor.add(const Duration(days: 14))), 2);
    });

    test('the 4th week (index 3) is the rest week', () {
      final restDate = anchor.add(const Duration(days: 21));
      expect(cycleWeekIndexForDate(meso, restDate), 3);
      expect(isRestWeek(meso, restDate), isTrue);
    });

    test('wraps back to index 0 on the next cycle', () {
      expect(cycleWeekIndexForDate(meso, anchor.add(const Duration(days: 28))), 0);
    });

    test('dates before the anchor floor-mod into the tail of the previous cycle', () {
      final before = anchor.subtract(const Duration(days: 7));
      expect(cycleWeekIndexForDate(meso, before), 3);
      expect(isRestWeek(meso, before), isTrue);
    });
  });

  group('cycleWeekIndexForDate with adjustments', () {
    final anchor = mondayOf(DateTime(2026, 1, 1));
    final meso = Mesocycle(
      id: 'm1',
      name: 'Test block',
      trainingWeeks: 3,
      restWeeks: 1,
      originalAnchor: anchor,
      weekdayWorkouts: const {},
    );

    test('a single adjustment retargets the cycle from its effective date', () {
      // Force the week starting anchor+7d to be cycle-week-index 2.
      final adjusted = meso.copyWith(adjustments: [
        CycleAdjustment(
          effectiveDate: anchor.add(const Duration(days: 7)),
          type: AdjustmentType.setCurrentWeek,
          targetCycleWeekIndex: 2,
        ),
      ]);

      // Before the adjustment's effective date, original anchor still applies.
      expect(cycleWeekIndexForDate(adjusted, anchor), 0);
      // At and after the effective date, the adjustment applies.
      expect(cycleWeekIndexForDate(adjusted, anchor.add(const Duration(days: 7))), 2);
      expect(cycleWeekIndexForDate(adjusted, anchor.add(const Duration(days: 14))), 3);
    });

    test('the later of two applicable adjustments wins', () {
      final adjusted = meso.copyWith(adjustments: [
        CycleAdjustment(
          effectiveDate: anchor.add(const Duration(days: 7)),
          type: AdjustmentType.setCurrentWeek,
          targetCycleWeekIndex: 2,
        ),
        CycleAdjustment(
          effectiveDate: anchor.add(const Duration(days: 14)),
          type: AdjustmentType.setCurrentWeek,
          targetCycleWeekIndex: 1,
        ),
      ]);

      // 3 weeks after anchor: both adjustments have taken effect, the later
      // (day 14, targetIdx=1) one wins -> phase anchor = day14 - 7d = day7,
      // so day21 is 2 weeks after that virtual anchor -> index 2.
      expect(cycleWeekIndexForDate(adjusted, anchor.add(const Duration(days: 21))), 2);
    });

    test('earlyRestAdjustment starts a rest week immediately and resumes training after', () {
      final today = anchor.add(const Duration(days: 10)); // mid training-week-2
      final adj = earlyRestAdjustment(meso, today);
      final adjusted = meso.copyWith(adjustments: [adj]);

      final restStart = mondayOf(today);
      expect(isRestWeek(adjusted, restStart), isTrue);
      // One rest week later, the next cycle's training week-1 begins.
      final nextWeek = restStart.add(const Duration(days: 7));
      expect(cycleWeekIndexForDate(adjusted, nextWeek), 0);
      expect(isRestWeek(adjusted, nextWeek), isFalse);
    });

    test('setCurrentWeekAdjustment pins the given date\'s week to the requested index', () {
      final today = anchor.add(const Duration(days: 3));
      final adj = setCurrentWeekAdjustment(today, 1);
      final adjusted = meso.copyWith(adjustments: [adj]);

      expect(cycleWeekIndexForDate(adjusted, mondayOf(today)), 1);
    });
  });

  group('statusForDate', () {
    test('training week label', () {
      final anchor = mondayOf(DateTime(2026, 1, 1));
      final meso = Mesocycle(
        id: 'm1',
        name: 'Test',
        trainingWeeks: 3,
        restWeeks: 1,
        originalAnchor: anchor,
        weekdayWorkouts: const {},
      );
      final status = statusForDate(meso, anchor.add(const Duration(days: 14)));
      expect(status.isTraining, isTrue);
      expect(status.weekOfBlock, 3);
      expect(status.totalWeeks, 3);
      expect(status.label, 'WEEK 3 OF 3 · TRAINING');
    });

    test('single rest week label', () {
      final anchor = mondayOf(DateTime(2026, 1, 1));
      final meso = Mesocycle(
        id: 'm1',
        name: 'Test',
        trainingWeeks: 3,
        restWeeks: 1,
        originalAnchor: anchor,
        weekdayWorkouts: const {},
      );
      final status = statusForDate(meso, anchor.add(const Duration(days: 21)));
      expect(status.isTraining, isFalse);
      expect(status.label, 'REST WEEK');
    });

    test('multi-week rest block label', () {
      final anchor = mondayOf(DateTime(2026, 1, 1));
      final meso = Mesocycle(
        id: 'm1',
        name: 'Test',
        trainingWeeks: 2,
        restWeeks: 2,
        originalAnchor: anchor,
        weekdayWorkouts: const {},
      );
      final week1 = statusForDate(meso, anchor.add(const Duration(days: 14)));
      expect(week1.label, 'REST WEEK 1 OF 2');
      final week2 = statusForDate(meso, anchor.add(const Duration(days: 21)));
      expect(week2.label, 'REST WEEK 2 OF 2');
    });
  });

  group('workoutIdForDate', () {
    final anchor = mondayOf(DateTime(2026, 1, 1)); // Monday
    final meso = Mesocycle(
      id: 'm1',
      name: 'Test',
      trainingWeeks: 1,
      restWeeks: 1,
      originalAnchor: anchor,
      weekdayWorkouts: {DateTime.monday: 'push-day'},
    );
    final trainingMonday = anchor; // index 0, training
    final restMonday = anchor.add(const Duration(days: 7)); // index 1, rest

    test('no override, training week -> template workout', () {
      expect(workoutIdForDate(meso, null, trainingMonday), 'push-day');
    });

    test('no override, rest week -> suppressed to null', () {
      expect(workoutIdForDate(meso, null, restMonday), isNull);
    });

    test('rest override wins over the template, even in a training week', () {
      final ov = DayOverride(
        mesocycleId: 'm1',
        date: normalizeDate(trainingMonday),
        kind: OverrideKind.rest,
      );
      expect(workoutIdForDate(meso, ov, trainingMonday), isNull);
    });

    test('setWorkout override wins over the template, even in a rest week', () {
      final ov = DayOverride(
        mesocycleId: 'm1',
        date: normalizeDate(restMonday),
        kind: OverrideKind.setWorkout,
        workoutId: 'override-workout',
      );
      expect(workoutIdForDate(meso, ov, restMonday), 'override-workout');
    });
  });

  group('plannedRunForDate', () {
    final anchor = mondayOf(DateTime(2026, 1, 1));
    final templateRun = const PlannedRun(type: RunType.easy, targetDistanceMeters: 5000);
    final meso = Mesocycle(
      id: 'm1',
      name: 'Test',
      trainingWeeks: 1,
      restWeeks: 1,
      originalAnchor: anchor,
      weekdayWorkouts: const {},
      weekdayRuns: {DateTime.monday: templateRun},
    );
    final trainingMonday = anchor;
    final restMonday = anchor.add(const Duration(days: 7));

    test('no override, training week -> template run', () {
      expect(plannedRunForDate(meso, null, trainingMonday), templateRun);
    });

    test('no override, rest week -> suppressed to null', () {
      expect(plannedRunForDate(meso, null, restMonday), isNull);
    });

    test('clearRun override wins over the template', () {
      final ov = RunOverride(
        mesocycleId: 'm1',
        date: normalizeDate(trainingMonday),
        kind: RunOverrideKind.clearRun,
      );
      expect(plannedRunForDate(meso, ov, trainingMonday), isNull);
    });

    test('setRun override wins over the template, even in a rest week', () {
      final overrideRun = const PlannedRun(type: RunType.tempo, targetDistanceMeters: 8000);
      final ov = RunOverride(
        mesocycleId: 'm1',
        date: normalizeDate(restMonday),
        kind: RunOverrideKind.setRun,
        plannedRun: overrideRun,
      );
      expect(plannedRunForDate(meso, ov, restMonday), overrideRun);
    });
  });

  group('adjustment builders', () {
    test('earlyRestAdjustment targets the first rest-week index of the meso', () {
      final anchor = mondayOf(DateTime(2026, 1, 1));
      final meso = Mesocycle(
        id: 'm1',
        name: 'Test',
        trainingWeeks: 3,
        restWeeks: 2,
        originalAnchor: anchor,
        weekdayWorkouts: const {},
      );
      final today = DateTime(2026, 2, 4); // some Wednesday
      final adj = earlyRestAdjustment(meso, today);
      expect(adj.type, AdjustmentType.earlyRest);
      expect(adj.effectiveDate, mondayOf(today));
      expect(adj.targetCycleWeekIndex, 3);
    });

    test('setCurrentWeekAdjustment carries the requested index', () {
      final today = DateTime(2026, 2, 4);
      final adj = setCurrentWeekAdjustment(today, 5);
      expect(adj.type, AdjustmentType.setCurrentWeek);
      expect(adj.effectiveDate, mondayOf(today));
      expect(adj.targetCycleWeekIndex, 5);
    });
  });
}
