import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/session_detail_screen.dart';

import '../support/fake_repositories.dart';
import '../support/pump_app.dart';

void main() {
  late FakeSessionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeSessionRepository();
  });

  Future<void> pumpDetail(WidgetTester tester, WorkoutSession session) {
    fakeRepo.store[session.id] = session;
    return pumpApp(
      tester,
      SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  }

  testWidgets('shows logged sets per exercise, including a skipped badge', (tester) async {
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9),
      endedAt: DateTime(2026, 1, 5, 9, 40),
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
          actualReps: 0,
          actualWeight: 0,
          skipped: true,
        ),
      ],
    );

    await pumpDetail(tester, session);

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Incline Fly'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.textContaining('8 × 60kg'), findsOneWidget);
  });

  testWidgets('shows the empty message when no sets were logged', (tester) async {
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9),
      endedAt: DateTime(2026, 1, 5, 9, 5),
      completed: false,
      sets: const [],
    );

    await pumpDetail(tester, session);

    expect(find.text('No sets logged.'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
  });

  testWidgets('delete action confirms then removes the session and pops', (tester) async {
    final session = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5, 9),
      endedAt: DateTime(2026, 1, 5, 9, 40),
      completed: true,
      sets: const [],
    );

    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SessionDetailScreen(session: session)),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(fakeRepo..store['ws1'] = session),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Delete session?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeRepo.store.containsKey('ws1'), isFalse);
    expect(find.text('open'), findsOneWidget);
  });
}
