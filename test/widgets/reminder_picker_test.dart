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
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/presentation/widgets/reminder_picker.dart';
import 'package:fitness_planner/providers/mesocycle_providers.dart';
import 'package:fitness_planner/providers/reminder_provider.dart';
import 'package:fitness_planner/services/notification_service.dart';

import '../support/fake_repositories.dart';
import '../support/pump_app.dart';

class MockNotificationService extends Mock implements NotificationService {}

DayOverride? _fallbackOverrideFn(DateTime d) => null;
PlannedRun? _fallbackPlannedRunFn(DateTime d) => null;

void main() {
  late MockNotificationService mockNotificationService;

  setUpAll(() {
    registerFallbackValue(_fallbackOverrideFn);
    registerFallbackValue(_fallbackPlannedRunFn);
    registerFallbackValue(<Workout>[]);
    registerFallbackValue(const TimeOfDay(hour: 0, minute: 0));
  });

  setUp(() {
    mockNotificationService = MockNotificationService();
    when(() => mockNotificationService.rescheduleAll(
          meso: any(named: 'meso'),
          overrideForDate: any(named: 'overrideForDate'),
          plannedRunForDate: any(named: 'plannedRunForDate'),
          workouts: any(named: 'workouts'),
          time: any(named: 'time'),
          enabled: any(named: 'enabled'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationService.requestPermissions())
        .thenAnswer((_) async => true);
  });

  // Builds a container against whatever SharedPreferences values are mocked
  // at call time, so a test can seed reminder_enabled before the reminder
  // provider first resolves.
  Future<ProviderContainer> buildContainer() async {
    final container = ProviderContainer(overrides: [
      mesocycleRepositoryProvider.overrideWithValue(FakeMesocycleRepository()),
      overrideRepositoryProvider.overrideWithValue(FakeOverrideRepository()),
      runOverrideRepositoryProvider.overrideWithValue(FakeRunOverrideRepository()),
      workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
      notificationServiceProvider.overrideWithValue(mockNotificationService),
    ]);
    await container.read(reminderProvider.future);
    await container.read(mesocyclesProvider.future);
    return container;
  }

  Future<ProviderContainer> pumpOpener(WidgetTester tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpApp(
      tester,
      Builder(builder: (context) {
        return TextButton(
          onPressed: () => showReminderPicker(context),
          child: const Text('open'),
        );
      }),
      container: container,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('starts disabled with the time picker hidden', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpOpener(tester);

    expect(find.text('Pre-workout reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsNothing);
  });

  testWidgets('enabling the switch reveals the time row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpOpener(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Reminder time'), findsOneWidget);
  });

  // Newly *enabling* the switch routes through the real
  // NotificationService.instance.requestPermissions() singleton (left
  // unmocked — see PR 3's notes: only rescheduleAll got a provider seam),
  // which throws under flutter_test with no platform plugin registered.
  // These two cases instead cover Save starting from an already-enabled
  // reminder, so that permission-request branch is never entered.
  group('when the reminder starts already enabled', () {
    testWidgets('Save reschedules notifications without requesting permission', (tester) async {
      SharedPreferences.setMockInitialValues({'reminder_enabled': true});
      final container = await pumpOpener(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(reminderProvider).value?.enabled, isTrue);
      verifyNever(() => mockNotificationService.requestPermissions());
      verify(() => mockNotificationService.rescheduleAll(
            meso: any(named: 'meso'),
            overrideForDate: any(named: 'overrideForDate'),
            plannedRunForDate: any(named: 'plannedRunForDate'),
            workouts: any(named: 'workouts'),
            time: any(named: 'time'),
            enabled: any(named: 'enabled'),
          )).called(greaterThanOrEqualTo(1));
    });

    testWidgets('toggling off then Save persists disabled', (tester) async {
      SharedPreferences.setMockInitialValues({'reminder_enabled': true});
      final container = await pumpOpener(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(reminderProvider).value?.enabled, isFalse);
    });
  });
}
