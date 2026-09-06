import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  late FakeSessionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeSessionRepository();
  });

  Future<void> pumpInsights(WidgetTester tester) => pumpApp(
        tester,
        const InsightsScreen(),
        overrides: [sessionRepositoryProvider.overrideWithValue(fakeRepo)],
      );

  testWidgets('shows the empty state when there are no sessions', (tester) async {
    await pumpInsights(tester);

    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('shows the trend for the most recently logged exercise by default', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
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

    await tester.tap(find.text('Pull-up'));
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

    await tester.tap(find.text('Bench Press'));
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

    await tester.tap(find.text('All sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
  });
}
