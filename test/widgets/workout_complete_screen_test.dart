import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/workout_complete_screen.dart';

import '../support/fake_repositories.dart';
import '../support/pump_app.dart';

void main() {
  // Every test's `session` must also be seeded into the fake session
  // repository — production saves the session before this screen is ever
  // pushed, and the "New records" section is computed from the provider
  // data, not from the `session` constructor argument directly.
  Future<void> pumpComplete(
    WidgetTester tester,
    WorkoutSession session, {
    List<WorkoutSession> otherSessions = const [],
  }) {
    final fakeRepo = FakeSessionRepository();
    for (final s in [...otherSessions, session]) {
      fakeRepo.store[s.id] = s;
    }
    return pumpApp(
      tester,
      WorkoutCompleteScreen(session: session),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(fakeRepo),
        runRepositoryProvider.overrideWithValue(FakeRunRepository()),
      ],
    );
  }

  testWidgets('summary totals (duration, completed sets) match the logged session', (tester) async {
    // An identical earlier session means neither set here beats a
    // standing best, so no "New records" section appears — this test
    // stays focused on the stat strip; the PR case gets its own test below.
    final earlier = WorkoutSession(
      id: 'ws0',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2025, 12, 29, 9, 0),
      endedAt: DateTime(2025, 12, 29, 9, 30),
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
          exerciseName: 'Incline Fly',
          targetReps: 10,
          targetWeight: 20,
          actualReps: 10,
          actualWeight: 20,
          skipped: false,
        ),
      ],
    );
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9, 0),
      endedAt: DateTime(2026, 1, 5, 9, 32, 15),
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
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 0,
          actualWeight: 0,
          skipped: true,
        ),
        LoggedSet(
          exerciseName: 'Incline Fly',
          targetReps: 10,
          targetWeight: 20,
          actualReps: 10,
          actualWeight: 20,
          skipped: false,
        ),
      ],
    );

    await pumpComplete(tester, session, otherSessions: [earlier]);

    expect(find.text('Workout done!'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    // duration = 32:15
    expect(find.text('32:15'), findsOneWidget);
    // 2 non-skipped sets out of 3 logged.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('NEW RECORDS'), findsNothing);
  });

  testWidgets('back to workouts pops to the first route', (tester) async {
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9, 0),
      endedAt: DateTime(2026, 1, 5, 9, 10),
      completed: true,
      sets: const [],
    );

    await pumpComplete(tester, session);

    await tester.tap(find.text('Back to workouts'));
    await tester.pumpAndSettle();

    // Nothing to pop to beyond the root in this isolated test — screen
    // simply stays mounted without throwing.
    expect(find.text('Workout done!'), findsOneWidget);
  });

  testWidgets(
      'shows a New records section and a See it in Insights button when the session set a PR',
      (tester) async {
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9, 0),
      endedAt: DateTime(2026, 1, 5, 9, 32, 15),
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

    await pumpComplete(tester, session);

    expect(find.text('NEW RECORDS'), findsOneWidget);
    // A first-ever weighted set claims both the heaviest-weight and
    // best-est.-1RM records, so "Bench Press" appears on more than one
    // PRCard plus once more in the "What you did" breakdown below.
    expect(find.text('Bench Press'), findsAtLeastNWidgets(2));
    expect(find.text('See it in Insights'), findsOneWidget);

    // Does not resurrect the bare tonnage stat chip removed in plan 019 —
    // the stat strip stays duration/sets only.
    expect(find.text('tonnage'), findsNothing);

    await tester.tap(find.text('See it in Insights'));
    await tester.pumpAndSettle();

    // No HomeShell mounted in this isolated test, so the tab switch is a
    // no-op — the screen just stays mounted without throwing.
    expect(find.text('Workout done!'), findsOneWidget);
  });

  testWidgets('hides the New records section when the session set no PR', (tester) async {
    final earlier = WorkoutSession(
      id: 'ws0',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 1, 9, 0),
      endedAt: DateTime(2026, 1, 1, 9, 30),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 65,
          actualReps: 8,
          actualWeight: 65,
          skipped: false,
        ),
      ],
    );
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9, 0),
      endedAt: DateTime(2026, 1, 5, 9, 32, 15),
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

    await pumpComplete(tester, session, otherSessions: [earlier]);

    expect(find.text('NEW RECORDS'), findsNothing);
    expect(find.text('See it in Insights'), findsNothing);
    expect(find.text('Back to workouts'), findsOneWidget);
  });
}
