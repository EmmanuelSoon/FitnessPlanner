import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_planner/data/mesocycle_repository.dart';
import 'package:fitness_planner/data/override_repository.dart';
import 'package:fitness_planner/data/run_override_repository.dart';
import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/domain/models/day_override.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/planned_run.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/schedule/schedule_logic.dart';
import 'package:fitness_planner/presentation/calendar_screen.dart';
import 'package:fitness_planner/presentation/mesocycle_setup_screen.dart';
import 'package:fitness_planner/presentation/record_run_screen.dart';
import 'package:fitness_planner/presentation/run_detail_screen.dart';
import 'package:fitness_planner/presentation/workout_start_preview_screen.dart';
import 'package:fitness_planner/providers/mesocycle_providers.dart';
import 'package:fitness_planner/providers/reminder_provider.dart';
import 'package:fitness_planner/providers/run_providers.dart';
import 'package:fitness_planner/providers/workout_providers.dart';
import 'package:fitness_planner/services/notification_service.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

class MockNotificationService extends Mock implements NotificationService {}

DayOverride? _fallbackOverrideFn(DateTime d) => null;
PlannedRun? _fallbackPlannedRunFn(DateTime d) => null;

/// Every weekday mapped to [workoutId] (or null for a rest template), so the
/// grid cell under today's date is deterministic regardless of which real
/// weekday the test suite happens to run on.
Mesocycle _meso({
  String id = 'm1',
  String name = 'Push Pull Legs',
  int trainingWeeks = 4,
  int restWeeks = 1,
  String? workoutId,
  PlannedRun? run,
  List<CycleAdjustment> adjustments = const [],
}) => Mesocycle(
      id: id,
      name: name,
      trainingWeeks: trainingWeeks,
      restWeeks: restWeeks,
      originalAnchor: mondayOf(DateTime.now()),
      weekdayWorkouts: {for (var d = 1; d <= 7; d++) d: workoutId},
      weekdayRuns: {if (run != null) for (var d = 1; d <= 7; d++) d: run},
      adjustments: adjustments,
    );

void main() {
  late FakeMesocycleRepository fakeMesoRepo;
  late FakeOverrideRepository fakeOverrideRepo;
  late FakeRunOverrideRepository fakeRunOverrideRepo;
  late FakeWorkoutRepository fakeWorkoutRepo;
  late FakeRunRepository fakeRunRepo;
  late FakeSessionRepository fakeSessionRepo;
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
    fakeOverrideRepo = FakeOverrideRepository();
    fakeRunOverrideRepo = FakeRunOverrideRepository();
    fakeWorkoutRepo = FakeWorkoutRepository();
    fakeRunRepo = FakeRunRepository();
    fakeSessionRepo = FakeSessionRepository();
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
      runRepositoryProvider.overrideWithValue(fakeRunRepo),
      sessionRepositoryProvider.overrideWithValue(fakeSessionRepo),
      notificationServiceProvider.overrideWithValue(mockNotificationService),
    ]);
    addTearDown(container.dispose);

    await container.read(reminderProvider.future);
    await container.read(workoutsProvider.future);
  });

  Future<void> activateMeso(Mesocycle meso) async {
    fakeWorkoutRepo.store.putIfAbsent('w1', () => buildWorkout(id: 'w1', name: 'Push Day'));
    // workoutsProvider was already warmed (empty) in setUp before the store
    // above was seeded — invalidate so it re-reads the fixture.
    container.invalidate(workoutsProvider);
    await container.read(workoutsProvider.future);
    await container.read(mesocyclesProvider.notifier).save(meso);
    await container.read(activeMesoIdProvider.notifier).setActive(meso.id);
  }

  Future<void> pumpCalendar(WidgetTester tester) =>
      pumpApp(tester, const CalendarScreen(), container: container);

  // The month grid sits inside the screen's SingleChildScrollView — today's
  // cell can be scrolled out of the fixed test surface, in which case a tap
  // at its (off-screen) center silently misses. Scroll it into view first.
  Future<void> tapTodayCell(WidgetTester tester) async {
    final finder = find.text('${DateTime.now().day}').first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('with no mesocycle and no runs, shows the empty state and its setup CTA', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('No mesocycle set up.'), findsOneWidget);
    await tester.tap(find.text('Set up mesocycle'));
    await tester.pumpAndSettle();

    expect(find.byType(MesocycleSetupScreen), findsOneWidget);
  });

  testWidgets('shows the training-week banner and navigates months with the chevrons', (tester) async {
    await activateMeso(_meso(workoutId: 'w1'));
    await pumpCalendar(tester);

    expect(find.text('WEEK 1 OF 4 · TRAINING'), findsOneWidget);
    expect(find.text('Push Pull Legs'), findsOneWidget);

    final now = DateTime.now();
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    final currentLabel = '${months[now.month - 1]} ${now.year}';
    expect(find.text(currentLabel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text(currentLabel), findsNothing);

    // Tapping the month label (whatever month it currently shows) snaps
    // back to the current month.
    final monthLabelFinder = find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontSize == 13 && w.style?.letterSpacing == 1.0,
    );
    await tester.tap(monthLabelFinder);
    await tester.pumpAndSettle();
    expect(find.text(currentLabel), findsOneWidget);
  });

  testWidgets('tapping a day with a scheduled workout opens the day sheet with Start workout', (tester) async {
    await activateMeso(_meso(workoutId: 'w1'));
    await pumpCalendar(tester);

    await tapTodayCell(tester);

    expect(find.text('Push Day'), findsWidgets);
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.text('Move to another date'), findsOneWidget);
    expect(find.text('Clear — make it a rest day'), findsOneWidget);

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutStartPreviewScreen), findsOneWidget);
  });

  testWidgets('"Clear — make it a rest day" saves a rest override for that date', (tester) async {
    final meso = _meso(workoutId: 'w1');
    await activateMeso(meso);
    await pumpCalendar(tester);

    await tapTodayCell(tester);
    await tester.tap(find.text('Clear — make it a rest day'));
    await tester.pumpAndSettle();

    final today = normalizeDate(DateTime.now());
    expect(fakeOverrideRepo.get(meso.id, today)?.kind, OverrideKind.rest);
  });

  testWidgets('on a rest day, "Add a workout" opens the workout picker and saves a setWorkout override', (tester) async {
    final meso = _meso(); // every weekday null -> rest day template
    await activateMeso(meso);
    await pumpCalendar(tester);

    await tapTodayCell(tester);
    expect(find.text('Rest day'), findsWidgets);

    await tester.tap(find.text('Add a workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();

    final today = normalizeDate(DateTime.now());
    final saved = fakeOverrideRepo.get(meso.id, today);
    expect(saved?.kind, OverrideKind.setWorkout);
    expect(saved?.workoutId, 'w1');
  });

  testWidgets('"Rest early" confirms and appends an earlyRest adjustment', (tester) async {
    final meso = _meso(workoutId: 'w1');
    await activateMeso(meso);
    await pumpCalendar(tester);

    await tester.tap(find.text('Rest early'));
    await tester.pumpAndSettle();
    expect(find.text('Start rest week early?'), findsOneWidget);

    await tester.tap(find.text('Start rest week'));
    await tester.pumpAndSettle();

    final saved = fakeMesoRepo.store[meso.id]!;
    expect(saved.adjustments, hasLength(1));
    expect(saved.adjustments.single.type, AdjustmentType.earlyRest);
    expect(saved.adjustments.single.effectiveDate, mondayOf(DateTime.now()));
  });

  testWidgets('"Adjust" opens the set-current-week sheet and appends a setCurrentWeek adjustment', (tester) async {
    final meso = _meso(workoutId: 'w1');
    await activateMeso(meso);
    await pumpCalendar(tester);

    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    expect(find.text("I'm currently on…"), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsOneWidget);

    await tester.tap(find.text('Set week'));
    await tester.pumpAndSettle();

    final saved = fakeMesoRepo.store[meso.id]!;
    expect(saved.adjustments, hasLength(1));
    expect(saved.adjustments.single.type, AdjustmentType.setCurrentWeek);
  });

  testWidgets('a day with a planned run shows it in the sheet and Log this run opens RecordRunScreen', (tester) async {
    const run = PlannedRun(type: RunType.easy, targetDistanceMeters: 5000);
    await activateMeso(_meso(run: run));
    await pumpCalendar(tester);

    await tapTodayCell(tester);

    expect(find.text('PLANNED RUN'), findsOneWidget);
    expect(find.text('Log this run'), findsOneWidget);

    await tester.tap(find.text('Log this run'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordRunScreen), findsOneWidget);
  });

  testWidgets('a day with a logged run lists it and navigates to RunDetailScreen on tap', (tester) async {
    await activateMeso(_meso());
    final today = DateTime.now();
    final run = buildRunSession(
      id: 'r1',
      startedAt: DateTime(today.year, today.month, today.day, 7),
    );
    fakeRunRepo.store['r1'] = run;
    await container.read(runsProvider.notifier).saveRun(run);

    await pumpCalendar(tester);
    await tapTodayCell(tester);

    expect(find.text('RUNS'), findsOneWidget);
    expect(find.textContaining('5.00 km'), findsOneWidget);

    await tester.tap(find.textContaining('5.00 km'));
    await tester.pumpAndSettle();

    expect(find.byType(RunDetailScreen), findsOneWidget);
  });
}
