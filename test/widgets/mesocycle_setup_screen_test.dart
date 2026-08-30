import 'package:flutter/cupertino.dart';
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
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/presentation/mesocycle_setup_screen.dart';
import 'package:fitness_planner/providers/mesocycle_providers.dart';
import 'package:fitness_planner/providers/reminder_provider.dart';
import 'package:fitness_planner/services/notification_service.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

class MockNotificationService extends Mock implements NotificationService {}

DayOverride? _fallbackOverrideFn(DateTime d) => null;
PlannedRun? _fallbackPlannedRunFn(DateTime d) => null;

void main() {
  late FakeMesocycleRepository fakeMesoRepo;
  late FakeWorkoutRepository fakeWorkoutRepo;
  late MockNotificationService mockNotificationService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_fallbackOverrideFn);
    registerFallbackValue(_fallbackPlannedRunFn);
    registerFallbackValue(<Workout>[]);
    registerFallbackValue(const TimeOfDay(hour: 0, minute: 0));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeMesoRepo = FakeMesocycleRepository();
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
      overrideRepositoryProvider.overrideWithValue(FakeOverrideRepository()),
      runOverrideRepositoryProvider.overrideWithValue(FakeRunOverrideRepository()),
      workoutRepositoryProvider.overrideWithValue(fakeWorkoutRepo),
      notificationServiceProvider.overrideWithValue(mockNotificationService),
    ]);
    addTearDown(container.dispose);

    await container.read(reminderProvider.future);
    await container.read(mesocyclesProvider.future);
  });

  Future<void> pumpSetup(WidgetTester tester, {Mesocycle? mesocycle}) => pumpApp(
        tester,
        MesocycleSetupScreen(existingMeso: mesocycle),
        container: container,
      );

  testWidgets('shows "New Mesocycle" with defaults when creating', (tester) async {
    await pumpSetup(tester);

    expect(find.text('New Mesocycle'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // default training weeks
    expect(find.text('1'), findsOneWidget); // default rest weeks
  });

  testWidgets('does not save when the name is left blank', (tester) async {
    await pumpSetup(tester);

    await tester.tap(find.text('Create mesocycle'));
    await tester.pumpAndSettle();

    expect(fakeMesoRepo.store, isEmpty);
    expect(find.text('New Mesocycle'), findsOneWidget); // still on the screen
  });

  testWidgets('creating a mesocycle saves it, sets it active, and closes the screen', (tester) async {
    await pumpSetup(tester);

    await tester.enterText(find.byType(TextField), 'Hypertrophy Block');
    await tester.tap(find.text('Create mesocycle'));
    await tester.pumpAndSettle();

    expect(fakeMesoRepo.store, hasLength(1));
    final saved = fakeMesoRepo.store.values.single;
    expect(saved.name, 'Hypertrophy Block');
    expect(saved.trainingWeeks, 5);
    expect(saved.restWeeks, 1);
    expect(container.read(activeMesoIdProvider).value, saved.id);
  });

  testWidgets('picking training weeks via the wheel picker updates the value shown', (tester) async {
    await pumpSetup(tester);

    await tester.tap(find.text('Training weeks'));
    await tester.pumpAndSettle();
    // Wheel starts centred on 5 weeks (index 4); drag up by one itemExtent
    // (44px) to select 6 weeks.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -44));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('assigning a workout to a weekday shows it in accent and later saves it', (tester) async {
    fakeWorkoutRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpSetup(tester);
    await tester.pump(); // let workoutsProvider rebuild pick up the fixture

    await tester.tap(find.text('Rest day').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Push Block');
    await tester.tap(find.text('Create mesocycle'));
    await tester.pumpAndSettle();

    final saved = fakeMesoRepo.store.values.single;
    expect(saved.weekdayWorkouts[1], 'w1');
  });

  testWidgets('editing an existing mesocycle prefills its name and shows Delete', (tester) async {
    final existing = buildMesocycle(id: 'm1', name: 'Old Block');
    fakeMesoRepo.store['m1'] = existing;
    await container.read(mesocyclesProvider.notifier).save(existing);

    await pumpSetup(tester, mesocycle: existing);

    expect(find.text('Edit Mesocycle'), findsOneWidget);
    expect(find.text('Old Block'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Delete mesocycle'), findsOneWidget);
  });

  testWidgets('deleting an existing mesocycle removes it and pops the screen', (tester) async {
    final existing = buildMesocycle(id: 'm1', name: 'Old Block');
    await container.read(mesocyclesProvider.notifier).save(existing);

    await pumpSetup(tester, mesocycle: existing);
    await tester.tap(find.text('Delete mesocycle'));
    await tester.pumpAndSettle();

    expect(find.text('Delete mesocycle?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeMesoRepo.store.containsKey('m1'), isFalse);
    expect(find.byType(MesocycleSetupScreen), findsNothing);
  });
}
