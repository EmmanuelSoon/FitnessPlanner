import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/session_detail_screen.dart';

import '../support/pump_app.dart';

void main() {
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

    await pumpApp(tester, SessionDetailScreen(session: session));

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

    await pumpApp(tester, SessionDetailScreen(session: session));

    expect(find.text('No sets logged.'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
  });
}
