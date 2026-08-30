import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/presentation/warmup_screen.dart';

import '../support/pump_app.dart';

Workout _workoutWithWarmup(List<Exercise> warmup) => Workout(
      id: 'w1',
      name: 'Push Day',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(name: 'Bench Press', reps: 8, sets: 3, restTime: const Duration(seconds: 90), weight: 60),
          ],
          sets: 3,
          restAfterSet: const Duration(seconds: 90),
        ),
      ],
      warmup: warmup,
    );

void main() {
  testWidgets('a workout with no warmup exercises skips straight to the session screen', (tester) async {
    final workout = _workoutWithWarmup([]);

    await pumpApp(tester, WarmupScreen(workout: workout));

    // WorkoutSessionScreen's own 5s pre-workout countdown also reads "GET
    // READY", so assert we've actually left WarmupScreen rather than
    // matching that shared label.
    expect(find.byType(WarmupScreen), findsNothing);
  });

  testWidgets('shows the pre-start countdown naming the first warmup exercise', (tester) async {
    final workout = _workoutWithWarmup([
      Exercise(name: 'Arm Circles', reps: 10, sets: 1, restTime: Duration.zero),
    ]);

    await pumpApp(tester, WarmupScreen(workout: workout));

    expect(find.text('GET READY'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Arm Circles'), findsOneWidget);
  });

  testWidgets('after the pre-start countdown, a timed exercise shows a running countdown ring', (tester) async {
    final workout = _workoutWithWarmup([
      Exercise(name: 'Plank', reps: 0, sets: 1, restTime: Duration.zero, timedDuration: const Duration(seconds: 5)),
    ]);

    await pumpApp(tester, WarmupScreen(workout: workout));
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('WARM-UP · 1 / 1'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('5s'), findsOneWidget);
  });

  testWidgets('a rep-based warmup exercise shows the rep count and a Done button', (tester) async {
    final workout = _workoutWithWarmup([
      Exercise(name: 'Arm Circles', reps: 15, sets: 1, restTime: Duration.zero),
    ]);

    await pumpApp(tester, WarmupScreen(workout: workout));
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Arm Circles'), findsOneWidget);
    expect(find.text('15 reps'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('skipping the only warmup exercise navigates into the workout session', (tester) async {
    final workout = _workoutWithWarmup([
      Exercise(name: 'Arm Circles', reps: 15, sets: 1, restTime: Duration.zero),
    ]);

    await pumpApp(tester, WarmupScreen(workout: workout));
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(WarmupScreen), findsNothing);
  });

  testWidgets('finishing a timed exercise advances through a Get ready interstitial to the next exercise', (tester) async {
    final workout = _workoutWithWarmup([
      Exercise(name: 'Plank', reps: 0, sets: 1, restTime: Duration.zero, timedDuration: const Duration(seconds: 1)),
      Exercise(name: 'Arm Circles', reps: 10, sets: 1, restTime: Duration.zero),
    ]);

    await pumpApp(tester, WarmupScreen(workout: workout));
    // 3s pre-start countdown, then land mid-way through the 1s Plank hold
    // (its own countdown timer starts fresh at t=3s) before it finishes.
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('Plank'), findsOneWidget);

    // Cross past t=4s (Plank's hold finishes) into the Get-ready interstitial.
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('GET READY'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Arm Circles'), findsOneWidget);
  });
}
