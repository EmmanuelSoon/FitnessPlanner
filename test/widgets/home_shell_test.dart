import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitness_planner/data/mesocycle_repository.dart';
import 'package:fitness_planner/data/override_repository.dart';
import 'package:fitness_planner/data/run_override_repository.dart';
import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/presentation/home_shell.dart';
import 'package:fitness_planner/services/health_service.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

class MockHealthService extends Mock implements HealthService {}

void main() {
  late FakeWorkoutRepository fakeWorkoutRepo;
  late FakeMesocycleRepository fakeMesoRepo;
  late FakeOverrideRepository fakeOverrideRepo;
  late FakeRunOverrideRepository fakeRunOverrideRepo;
  late FakeRunRepository fakeRunRepo;
  late FakeSessionRepository fakeSessionRepo;
  late MockHealthService mockHealthService;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    fakeWorkoutRepo = FakeWorkoutRepository();
    fakeMesoRepo = FakeMesocycleRepository();
    fakeOverrideRepo = FakeOverrideRepository();
    fakeRunOverrideRepo = FakeRunOverrideRepository();
    fakeRunRepo = FakeRunRepository();
    fakeSessionRepo = FakeSessionRepository();
    mockHealthService = MockHealthService();
    when(() => mockHealthService.fetchRuns(since: any(named: 'since')))
        .thenAnswer((_) async => []);
  });

  Future<void> pumpShell(WidgetTester tester) => pumpApp(
        tester,
        const HomeShell(),
        overrides: [
          workoutRepositoryProvider.overrideWithValue(fakeWorkoutRepo),
          mesocycleRepositoryProvider.overrideWithValue(fakeMesoRepo),
          overrideRepositoryProvider.overrideWithValue(fakeOverrideRepo),
          runOverrideRepositoryProvider.overrideWithValue(fakeRunOverrideRepo),
          runRepositoryProvider.overrideWithValue(fakeRunRepo),
          sessionRepositoryProvider.overrideWithValue(fakeSessionRepo),
          healthServiceProvider.overrideWithValue(mockHealthService),
        ],
      );

  testWidgets('opens on the Workouts tab', (tester) async {
    await pumpShell(tester);

    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('tapping each destination shows its matching screen', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('No mesocycle set up.'), findsOneWidget);

    await tester.tap(find.text('Runs'));
    await tester.pumpAndSettle();
    expect(find.text('No runs yet'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions yet'), findsOneWidget);

    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('switching away and back preserves the tab\'s scroll position', (tester) async {
    for (var i = 0; i < 20; i++) {
      fakeWorkoutRepo.store['w$i'] =
          buildWorkout(id: 'w$i', name: 'Workout $i');
    }
    await pumpShell(tester);

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -800));
    await tester.pumpAndSettle();
    final offsetBefore =
        tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offsetBefore, greaterThan(0));

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();

    final offsetAfter =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    expect(offsetAfter, offsetBefore);
  });

  testWidgets('a detail screen pushes over the shell rather than replacing it', (tester) async {
    fakeWorkoutRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpShell(tester);

    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
  });
}
