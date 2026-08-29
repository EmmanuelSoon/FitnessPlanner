import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/presentation/workout_session_screen.dart';

import '../support/fake_repositories.dart';
import '../support/pump_app.dart';

/// A single exercise, 2 sets, 45s rest between them — big enough to exercise
/// rest/pause/skip without a giant test.
Workout _twoSetWorkout({Duration restTime = const Duration(seconds: 45)}) => Workout(
      id: 'w1',
      name: 'Test Workout',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(name: 'Squat', reps: 10, sets: 2, restTime: restTime, weight: 50),
          ],
          sets: 2,
          restAfterSet: restTime,
        ),
      ],
    );

void main() {
  late FakeSessionRepository fakeSessionRepo;

  setUp(() {
    fakeSessionRepo = FakeSessionRepository();
  });

  Future<void> pumpSession(WidgetTester tester, Workout workout) => pumpApp(
        tester,
        WorkoutSessionScreen(workout: workout),
        overrides: [sessionRepositoryProvider.overrideWithValue(fakeSessionRepo)],
      );

  Future<void> skipCountdown(WidgetTester tester) => tester.pump(const Duration(seconds: 6));

  testWidgets('finishing a set with rest time starts the rest timer', (tester) async {
    await pumpSession(tester, _twoSetWorkout());
    await skipCountdown(tester);

    expect(find.text('Set complete'), findsOneWidget);
    await tester.tap(find.text('Set complete'));
    await tester.pump();

    expect(find.text('Skip rest'), findsOneWidget);
    expect(find.textContaining('of 45s rest'), findsOneWidget);
  });

  testWidgets('skip set logs a skipped set and advances without waiting', (tester) async {
    await pumpSession(tester, _twoSetWorkout());
    await skipCountdown(tester);

    await tester.tap(find.text('Skip set'));
    await tester.pump();

    // Still moves into the rest view (skip set doesn't skip the rest period).
    expect(find.text('Skip rest'), findsOneWidget);
  });

  testWidgets('pause/resume toggles the rest label and halts the countdown', (tester) async {
    await pumpSession(tester, _twoSetWorkout());
    await skipCountdown(tester);
    await tester.tap(find.text('Set complete'));
    await tester.pump();

    expect(find.text('RESTING'), findsOneWidget);
    await tester.tap(find.text('RESTING'));
    await tester.pump();
    expect(find.text('RESUME'), findsOneWidget);

    // Paused: waiting 3s should not move the remaining-time text. Matched by
    // font size (72) to disambiguate from the elapsed-time text (28), which
    // also matches the m:ss pattern and keeps ticking regardless of pause.
    final countdownFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.style?.fontSize == 72 &&
          RegExp(r'^\d+:\d{2}$').hasMatch(w.data ?? ''),
    );
    String remainingLabel() => (countdownFinder.evaluate().single.widget as Text).data!;
    final before = remainingLabel();
    await tester.pump(const Duration(seconds: 3));
    final after = remainingLabel();
    expect(after, equals(before));

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('RESTING'), findsOneWidget);
  });

  testWidgets('skip rest advances immediately to the next set', (tester) async {
    await pumpSession(tester, _twoSetWorkout());
    await skipCountdown(tester);
    await tester.tap(find.text('Set complete'));
    await tester.pump();

    await tester.tap(find.text('Skip rest'));
    await tester.pump();

    // Second (final) set of the same exercise — back to the exercise view.
    expect(find.text('Set complete'), findsOneWidget);
    expect(find.text('EXERCISE 1 / 1'), findsOneWidget);
    expect(find.text('Set 2 / 2'), findsOneWidget);
  });

  testWidgets('adjusting reps via the wheel picker updates the hero number', (tester) async {
    await pumpSession(tester, _twoSetWorkout());
    await skipCountdown(tester);

    expect(find.text('10'), findsOneWidget); // prefilled reps

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    // Wheel picker starts centred on the current value (10); drag up by one
    // itemExtent (44px) to select 11, then confirm.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -44));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('completing the last set saves a completed session', (tester) async {
    final workout = Workout(
      id: 'w1',
      name: 'Test Workout',
      exercises: [
        Superset(
          id: 's1',
          exercises: [Exercise(name: 'Squat', reps: 10, sets: 1, restTime: Duration.zero, weight: 50)],
          sets: 1,
          restAfterSet: Duration.zero,
        ),
      ],
    );
    await pumpSession(tester, workout);
    await skipCountdown(tester);

    await tester.tap(find.text('Set complete'));
    await tester.pumpAndSettle();

    expect(fakeSessionRepo.store, hasLength(1));
    final saved = fakeSessionRepo.store.values.single;
    expect(saved.completed, isTrue);
    expect(saved.sets, hasLength(1));
    expect(saved.sets.single.exerciseName, 'Squat');
    expect(saved.sets.single.skipped, isFalse);
  });
}
