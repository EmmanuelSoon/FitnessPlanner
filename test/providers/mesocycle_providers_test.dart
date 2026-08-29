import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_planner/data/mesocycle_repository.dart';
import 'package:fitness_planner/data/override_repository.dart';
import 'package:fitness_planner/data/run_override_repository.dart';
import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/domain/models/day_override.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_override.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/providers/mesocycle_providers.dart';
import 'package:fitness_planner/providers/reminder_provider.dart';
import 'package:fitness_planner/providers/workout_providers.dart';
import 'package:fitness_planner/services/notification_service.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';

class MockNotificationService extends Mock implements NotificationService {}

DayOverride? _fallbackOverrideFn(DateTime d) => null;
PlannedRun? _fallbackPlannedRunFn(DateTime d) => null;

void main() {
  late FakeMesocycleRepository fakeMesoRepo;
  late FakeOverrideRepository fakeOverrideRepo;
  late FakeRunOverrideRepository fakeRunOverrideRepo;
  late FakeWorkoutRepository fakeWorkoutRepo;
  late MockNotificationService mockNotificationService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_fallbackOverrideFn);
    registerFallbackValue(_fallbackPlannedRunFn);
    registerFallbackValue(<Workout>[]);
    registerFallbackValue(const TimeOfDay(hour: 0, minute: 0));
  });

  void verifyRescheduled({int times = 1}) {
    verify(() => mockNotificationService.rescheduleAll(
          meso: any(named: 'meso'),
          overrideForDate: any(named: 'overrideForDate'),
          plannedRunForDate: any(named: 'plannedRunForDate'),
          workouts: any(named: 'workouts'),
          time: any(named: 'time'),
          enabled: any(named: 'enabled'),
        )).called(times);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeMesoRepo = FakeMesocycleRepository();
    fakeOverrideRepo = FakeOverrideRepository();
    fakeRunOverrideRepo = FakeRunOverrideRepository();
    fakeWorkoutRepo = FakeWorkoutRepository();
    mockNotificationService = MockNotificationService();
    when(() => mockNotificationService.rescheduleAll(
          meso: any(named: 'meso'),
          overrideForDate: any(named: 'overrideForDate'),
          plannedRunForDate: any(named: 'plannedRunForDate'),
          workouts: any(named: 'workouts'),
          time: any(named: 'time'),
          enabled: any(named: 'enabled'),
        )).thenAnswer((_) async {});

    container = ProviderContainer(overrides: [
      mesocycleRepositoryProvider.overrideWithValue(fakeMesoRepo),
      overrideRepositoryProvider.overrideWithValue(fakeOverrideRepo),
      runOverrideRepositoryProvider.overrideWithValue(fakeRunOverrideRepo),
      workoutRepositoryProvider.overrideWithValue(fakeWorkoutRepo),
      notificationServiceProvider.overrideWithValue(mockNotificationService),
    ]);

    // Warm up everything rescheduleNotifications reads synchronously, so
    // mutation calls below don't silently skip the reschedule.
    await container.read(reminderProvider.future);
    await container.read(activeMesoIdProvider.future);
    await container.read(workoutsProvider.future);
    await container.read(mesocyclesProvider.future);
  });

  tearDown(() => container.dispose());

  group('ActiveMesoIdNotifier', () {
    test('build() is null when nothing is persisted', () {
      expect(container.read(activeMesoIdProvider).value, isNull);
    });

    test('setActive() persists and updates state', () async {
      await container.read(activeMesoIdProvider.notifier).setActive('m1');

      expect(container.read(activeMesoIdProvider).value, 'm1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_mesocycle_id'), 'm1');
    });

    test('setActive(null) clears the persisted value', () async {
      await container.read(activeMesoIdProvider.notifier).setActive('m1');

      await container.read(activeMesoIdProvider.notifier).setActive(null);

      expect(container.read(activeMesoIdProvider).value, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('active_mesocycle_id'), isFalse);
    });
  });

  group('MesocyclesNotifier', () {
    test('save() adds the mesocycle and triggers a reschedule', () async {
      await container.read(mesocyclesProvider.notifier).save(buildMesocycle(id: 'm1'));

      expect(fakeMesoRepo.store.containsKey('m1'), isTrue);
      expect(container.read(mesocyclesProvider).value?.map((m) => m.id), ['m1']);
      verifyRescheduled();
    });

    test('delete() removes the mesocycle, clears the active id if it was active, and reschedules', () async {
      await container.read(mesocyclesProvider.notifier).save(buildMesocycle(id: 'm1'));
      await container.read(activeMesoIdProvider.notifier).setActive('m1');
      clearInteractions(mockNotificationService);

      await container.read(mesocyclesProvider.notifier).delete('m1');

      expect(fakeMesoRepo.store.containsKey('m1'), isFalse);
      expect(container.read(activeMesoIdProvider).value, isNull);
      verifyRescheduled();
    });

    test('appendAdjustment() replaces an existing adjustment with the same effectiveDate', () async {
      await container.read(mesocyclesProvider.notifier).save(buildMesocycle(id: 'm1'));

      await container.read(mesocyclesProvider.notifier).appendAdjustment(
            'm1',
            CycleAdjustment(
              effectiveDate: DateTime(2026, 2, 2),
              type: AdjustmentType.earlyRest,
              targetCycleWeekIndex: 3,
            ),
          );
      await container.read(mesocyclesProvider.notifier).appendAdjustment(
            'm1',
            CycleAdjustment(
              effectiveDate: DateTime(2026, 2, 2),
              type: AdjustmentType.setCurrentWeek,
              targetCycleWeekIndex: 1,
            ),
          );

      final stored = fakeMesoRepo.store['m1']!;
      expect(stored.adjustments, hasLength(1));
      expect(stored.adjustments.single.type, AdjustmentType.setCurrentWeek);
    });

    test('appendAdjustment() sorts adjustments by effectiveDate ascending', () async {
      await container.read(mesocyclesProvider.notifier).save(buildMesocycle(id: 'm1'));

      await container.read(mesocyclesProvider.notifier).appendAdjustment(
            'm1',
            CycleAdjustment(effectiveDate: DateTime(2026, 3, 1), type: AdjustmentType.earlyRest),
          );
      await container.read(mesocyclesProvider.notifier).appendAdjustment(
            'm1',
            CycleAdjustment(effectiveDate: DateTime(2026, 1, 1), type: AdjustmentType.earlyRest),
          );

      final stored = fakeMesoRepo.store['m1']!;
      expect(
        stored.adjustments.map((a) => a.effectiveDate),
        [DateTime(2026, 1, 1), DateTime(2026, 3, 1)],
      );
    });
  });

  group('OverridesNotifier', () {
    setUp(() async {
      await container.read(mesocyclesProvider.notifier).save(buildMesocycle(id: 'm1'));
      await container.read(activeMesoIdProvider.notifier).setActive('m1');
      await container.read(overridesProvider.future);
      clearInteractions(mockNotificationService);
    });

    test('setWorkout() saves a setWorkout override and reschedules', () async {
      await container.read(overridesProvider.notifier).setWorkout(DateTime(2026, 1, 6), 'w1');

      final stored = fakeOverrideRepo.get('m1', DateTime(2026, 1, 6));
      expect(stored?.kind, OverrideKind.setWorkout);
      expect(stored?.workoutId, 'w1');
      verifyRescheduled();
    });

    test('setRest() saves a rest override', () async {
      await container.read(overridesProvider.notifier).setRest(DateTime(2026, 1, 6));

      expect(fakeOverrideRepo.get('m1', DateTime(2026, 1, 6))?.kind, OverrideKind.rest);
    });

    test('clearOverride() removes the override', () async {
      await container.read(overridesProvider.notifier).setRest(DateTime(2026, 1, 6));

      await container.read(overridesProvider.notifier).clearOverride(DateTime(2026, 1, 6));

      expect(fakeOverrideRepo.get('m1', DateTime(2026, 1, 6)), isNull);
    });

    test('move() sets rest on the source day and setWorkout on the destination day', () async {
      await container.read(overridesProvider.notifier).move(
            DateTime(2026, 1, 6),
            DateTime(2026, 1, 7),
            'w1',
          );

      expect(fakeOverrideRepo.get('m1', DateTime(2026, 1, 6))?.kind, OverrideKind.rest);
      final dest = fakeOverrideRepo.get('m1', DateTime(2026, 1, 7));
      expect(dest?.kind, OverrideKind.setWorkout);
      expect(dest?.workoutId, 'w1');
    });
  });

  group('RunOverridesNotifier', () {
    const run = PlannedRun(type: RunType.easy, targetDistanceMeters: 5000);

    setUp(() async {
      await container.read(mesocyclesProvider.notifier).save(buildMesocycle(id: 'm1'));
      await container.read(activeMesoIdProvider.notifier).setActive('m1');
      await container.read(runOverridesProvider.future);
      clearInteractions(mockNotificationService);
    });

    test('setRun() saves a setRun override and reschedules', () async {
      await container.read(runOverridesProvider.notifier).setRun(DateTime(2026, 1, 6), run);

      final stored = fakeRunOverrideRepo.get('m1', DateTime(2026, 1, 6));
      expect(stored?.kind, RunOverrideKind.setRun);
      expect(stored?.plannedRun?.targetDistanceMeters, 5000);
      verifyRescheduled();
    });

    test('clearRun() saves a clearRun override', () async {
      await container.read(runOverridesProvider.notifier).clearRun(DateTime(2026, 1, 6));

      expect(fakeRunOverrideRepo.get('m1', DateTime(2026, 1, 6))?.kind, RunOverrideKind.clearRun);
    });

    test('clearOverride() removes the override entirely', () async {
      await container.read(runOverridesProvider.notifier).setRun(DateTime(2026, 1, 6), run);

      await container.read(runOverridesProvider.notifier).clearOverride(DateTime(2026, 1, 6));

      expect(fakeRunOverrideRepo.get('m1', DateTime(2026, 1, 6)), isNull);
    });

    test('moveRun() clears the source day and sets the run on the destination day', () async {
      await container.read(runOverridesProvider.notifier).moveRun(
            DateTime(2026, 1, 6),
            DateTime(2026, 1, 7),
            run,
          );

      expect(fakeRunOverrideRepo.get('m1', DateTime(2026, 1, 6))?.kind, RunOverrideKind.clearRun);
      final dest = fakeRunOverrideRepo.get('m1', DateTime(2026, 1, 7));
      expect(dest?.kind, RunOverrideKind.setRun);
      expect(dest?.plannedRun?.targetDistanceMeters, 5000);
    });
  });
}
