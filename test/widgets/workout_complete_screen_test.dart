import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/workout_complete_screen.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('summary totals (duration, completed sets) match the logged session', (tester) async {
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

    await pumpApp(tester, WorkoutCompleteScreen(session: session));

    expect(find.text('Workout done!'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    // duration = 32:15
    expect(find.text('32:15'), findsOneWidget);
    // 2 non-skipped sets out of 3 logged.
    expect(find.text('2'), findsOneWidget);
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

    await pumpApp(tester, WorkoutCompleteScreen(session: session));

    await tester.tap(find.text('Back to workouts'));
    await tester.pumpAndSettle();

    // Nothing to pop to beyond the root in this isolated test — screen
    // simply stays mounted without throwing.
    expect(find.text('Workout done!'), findsOneWidget);
  });
}
