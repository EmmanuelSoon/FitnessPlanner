import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/insights_screen.dart';
import 'package:fitness_planner/providers/session_providers.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

DateTime _mondayOf(DateTime dt) {
  final day = DateTime(dt.year, dt.month, dt.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

// The exercise-trend card's chip row is the only `Wrap` on the screen, so
// scoping to it disambiguates an exercise name from any Recent records
// card that happens to show the same exercise.
Finder _exerciseChip(String label) =>
    find.descendant(of: find.byType(Wrap), matching: find.text(label));

void main() {
  late FakeSessionRepository fakeRepo;
  late FakeRunRepository fakeRunRepo;

  setUp(() {
    fakeRepo = FakeSessionRepository();
    fakeRunRepo = FakeRunRepository();
  });

  Future<void> pumpInsights(WidgetTester tester) => pumpApp(
        tester,
        const InsightsScreen(),
        overrides: [
          sessionRepositoryProvider.overrideWithValue(fakeRepo),
          runRepositoryProvider.overrideWithValue(fakeRunRepo),
        ],
      );

  testWidgets('shows the empty state when there are no sessions', (tester) async {
    await pumpInsights(tester);

    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('does not show the empty state when there are no workout sessions but a run is logged',
      (tester) async {
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('No sessions yet'), findsNothing);
    expect(find.text('Strength'), findsOneWidget); // the mode toggle is showing
  });

  testWidgets('defaults to Running mode when there are runs but no workout sessions', (tester) async {
    final thisWeek = _mondayOf(DateTime.now());
    fakeRunRepo.store['r1'] = buildRunSession(
      id: 'r1',
      startedAt: thisWeek.add(const Duration(days: 1, hours: 7)),
    );

    await pumpInsights(tester);

    expect(find.text('Distance over time'.toUpperCase()), findsOneWidget);
    expect(find.text('5.0'), findsWidgets); // distance: strip cell + distance card
  });

  testWidgets('shows the trend for the most recently logged exercise by default', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(_exerciseChip('Bench Press'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('exerciseTrendCurrentValue'))).data,
      '60',
    );
    expect(find.textContaining('Top set'), findsOneWidget);
  });

  testWidgets('tapping another exercise chip switches the trend shown', (tester) async {
    fakeRepo.store['ws1'] = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5),
      endedAt: DateTime(2026, 1, 5, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 8,
          actualWeight: 60,
          skipped: false,
        ),
        LoggedSet(
          exerciseName: 'Pull-up',
          targetReps: 10,
          targetWeight: 0,
          actualReps: 10,
          actualWeight: 0,
          skipped: false,
        ),
      ],
    );

    await pumpInsights(tester);

    expect(find.textContaining('Top set'), findsOneWidget);

    // The exercise-trend card sits below the fold once the mode toggle and
    // Recent records are on screen, so its chips aren't built yet — scroll
    // them into the sliver's cache extent first.
    await tester.scrollUntilVisible(_exerciseChip('Pull-up'), 300);
    await tester.pumpAndSettle();
    await tester.tap(_exerciseChip('Pull-up'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Best set'), findsOneWidget);
  });

  testWidgets('falls back to another exercise when the selected one disappears from the list', (tester) async {
    fakeRepo.store['ws1'] = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5),
      endedAt: DateTime(2026, 1, 5, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 8,
          actualWeight: 60,
          skipped: false,
        ),
      ],
    );
    fakeRepo.store['ws2'] = WorkoutSession(
      id: 'ws2',
      workoutId: 'w1',
      workoutName: 'Pull Day',
      startedAt: DateTime(2026, 1, 12),
      endedAt: DateTime(2026, 1, 12, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Pull-up',
          targetReps: 10,
          targetWeight: 0,
          actualReps: 10,
          actualWeight: 0,
          skipped: false,
        ),
      ],
    );

    await pumpInsights(tester);
    // Pull-up is the most recently logged exercise, so it's selected by default.
    expect(find.textContaining('Best set'), findsOneWidget);

    await tester.scrollUntilVisible(_exerciseChip('Bench Press'), 300);
    await tester.pumpAndSettle();
    await tester.tap(_exerciseChip('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Top set'), findsOneWidget);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(InsightsScreen)));
    await container.read(sessionsProvider.notifier).deleteSession('ws1');
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsNothing);
    expect(find.textContaining('Best set'), findsOneWidget);
  });

  testWidgets('shows this week\'s session count, tonnage, and rep volume', (tester) async {
    final thisWeek = _mondayOf(DateTime.now()).add(const Duration(days: 1, hours: 9));
    fakeRepo.store['ws1'] = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: thisWeek,
      endedAt: thisWeek.add(const Duration(hours: 1)),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 10,
          targetWeight: 60,
          actualReps: 10,
          actualWeight: 60,
          skipped: false,
        ),
        LoggedSet(
          exerciseName: 'Push-up',
          targetReps: 5,
          targetWeight: 0,
          actualReps: 5,
          actualWeight: 0,
          skipped: false,
        ),
      ],
    );

    await pumpInsights(tester);

    expect(find.text('This week'.toUpperCase()), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // sessions
    expect(find.text('0.6'), findsWidgets); // tonnage: strip cell + volume card
    expect(find.text('15'), findsOneWidget); // rep volume: 10 + 5
    expect(find.textContaining('Tonnage counts weighted sets only'), findsOneWidget);
  });

  testWidgets('shows the volume-over-time card defaulting to tonnage, with the vs-8w-ago change', (tester) async {
    final currentWeekStart = _mondayOf(DateTime.now());
    final eightWeeksAgoStart = currentWeekStart.subtract(const Duration(days: 49));
    fakeRepo.store['ws-now'] = WorkoutSession(
      id: 'ws-now',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: currentWeekStart.add(const Duration(days: 1, hours: 9)),
      endedAt: currentWeekStart.add(const Duration(days: 1, hours: 10)),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 10,
          targetWeight: 60,
          actualReps: 10,
          actualWeight: 60,
          skipped: false,
        ),
      ],
    );
    fakeRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: eightWeeksAgoStart.add(const Duration(days: 1, hours: 9)),
      endedAt: eightWeeksAgoStart.add(const Duration(days: 1, hours: 10)),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 10,
          targetWeight: 50,
          actualReps: 10,
          actualWeight: 50,
          skipped: false,
        ),
      ],
    );

    await pumpInsights(tester);

    expect(find.text('Volume over time'.toUpperCase()), findsOneWidget);
    expect(find.text('0.6'), findsWidgets); // this week strip + volume card both show it
    expect(find.textContaining('20%'), findsOneWidget); // (600-500)/500
    expect(find.text('vs 8w ago'), findsOneWidget);

    await tester.tap(find.text('Reps'));
    await tester.pumpAndSettle();

    expect(find.text('10'), findsWidgets);
  });

  testWidgets('the All sessions row navigates to the full session list', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1');

    await pumpInsights(tester);

    // The row sits below the fold once Recent records is on screen, so it
    // isn't built yet — scroll it into the sliver's cache extent first.
    await tester.scrollUntilVisible(find.text('All sessions'), 300);
    await tester.tap(find.text('All sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
  });

  testWidgets('shows a no-records message under Recent records when every set was skipped', (tester) async {
    fakeRepo.store['ws1'] = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5),
      endedAt: DateTime(2026, 1, 5, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 8,
          actualWeight: 60,
          skipped: true,
        ),
      ],
    );

    await pumpInsights(tester);

    expect(find.text('Recent records'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('No records yet'), findsOneWidget);
  });

  testWidgets('shows the top personal records under Recent records', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('Recent records'.toUpperCase()), findsOneWidget);
    expect(find.text('HEAVIEST WEIGHT'), findsOneWidget);
    expect(find.text('Bench Press'), findsWidgets);
  });

  testWidgets('See all navigates to the full records screen', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('Records'), findsOneWidget);
  });

  testWidgets(
      'switching to Running mode shows the weekly running stats, distance/pace charts, and a fastest-pace record',
      (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    final thisWeek = _mondayOf(DateTime.now());
    fakeRunRepo.store['r1'] = buildRunSession(
      id: 'r1',
      startedAt: thisWeek.add(const Duration(days: 1, hours: 7)),
    ); // 5km / 30min = 6:00/km, per buildRunSession's defaults

    await pumpInsights(tester);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(find.text('Distance over time'.toUpperCase()), findsOneWidget);
    expect(find.text('Pace trend'.toUpperCase()), findsOneWidget);
    expect(find.text('5.0'), findsWidgets); // distance: strip cell + distance card
    expect(find.text('6:00'), findsWidgets); // avg pace: strip cell + fastest-pace PR card
    expect(find.text('FASTEST PACE'), findsOneWidget);
  });

  testWidgets('Strength mode filters the fastest-pace record out of Recent records', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('FASTEST PACE'), findsNothing);
  });

  testWidgets('shows a no-records message for Running when no runs are logged', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No records yet — log a run'), findsOneWidget);
  });
}
