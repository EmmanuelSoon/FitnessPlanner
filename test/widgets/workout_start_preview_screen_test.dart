import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/workout_start_preview_screen.dart';
import 'package:fitness_planner/providers/session_providers.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late FakeSessionRepository fakeSessionRepo;

  setUp(() {
    fakeSessionRepo = FakeSessionRepository();
  });

  // WorkoutStartPreviewScreen reads sessionsProvider synchronously in
  // initState, so the container must be pre-warmed before the first pump —
  // otherwise the provider is still AsyncLoading and prefill silently no-ops.
  Future<void> pumpPreview(
    WidgetTester tester,
    Workout workout, {
    Size? surfaceSize,
  }) async {
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(fakeSessionRepo)],
    );
    addTearDown(container.dispose);
    await container.read(sessionsProvider.future);
    await pumpApp(
      tester,
      WorkoutStartPreviewScreen(workout: workout),
      container: container,
      surfaceSize: surfaceSize ?? const Size(600, 915),
    );
  }

  testWidgets('shows the workout template values even when a prior session logged different actuals', (tester) async {
    final workout = buildWorkout(id: 'w1'); // Bench Press: 8 reps @ 60kg in the template.
    fakeSessionRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 6,
          actualWeight: 65,
          skipped: false,
        ),
      ],
    );

    await pumpPreview(tester, workout);

    // Editable fields default to the template, never the prior actuals.
    expect(find.text('8'), findsWidgets);
    expect(find.text('60 kg'), findsWidgets);
    // The session's divergent actuals must not leak into the editable fields
    // (the LAST TIME readout renders them without a space before "kg", so
    // this can't accidentally match that instead).
    expect(find.text('6'), findsNothing);
    expect(find.text('65 kg'), findsNothing);
  });

  testWidgets('shows a LAST TIME column with the prior session\'s actual reps/weight', (tester) async {
    final workout = buildWorkout(id: 'w1');
    fakeSessionRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 6,
          actualWeight: 65,
          skipped: false,
        ),
      ],
    );

    await pumpPreview(tester, workout);

    expect(find.text('LAST TIME'), findsWidgets);
    expect(find.text('6 × 65kg'), findsOneWidget);
  });

  testWidgets('excludes a skipped set from LAST TIME, falling back to the last real set', (tester) async {
    final workout = buildWorkout(id: 'w1'); // Bench Press: 8 reps @ 60kg in the template.
    fakeSessionRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 6,
          actualWeight: 65,
          skipped: false,
        ),
        // The final set that session was skipped.
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 0,
          actualWeight: 0,
          skipped: true,
        ),
      ],
    );

    await pumpPreview(tester, workout);

    expect(find.text('6 × 65kg'), findsOneWidget);
    expect(find.text('0 × 0kg'), findsNothing);
  });

  testWidgets('shows held seconds in LAST TIME for a timed exercise', (tester) async {
    final workout = Workout(
      id: 'w6',
      name: 'Core Day',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(
              name: 'Plank',
              reps: 0,
              sets: 3,
              restTime: const Duration(seconds: 30),
              timedDuration: const Duration(seconds: 30),
            ),
          ],
          sets: 3,
          restAfterSet: const Duration(seconds: 30),
        ),
      ],
    );
    fakeSessionRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w6',
      workoutName: 'Core Day',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Plank',
          targetReps: 0,
          targetWeight: 0,
          actualReps: 0,
          actualWeight: 0,
          skipped: false,
          heldSeconds: 45,
          targetSeconds: 30,
        ),
      ],
    );

    await pumpPreview(tester, workout);

    expect(find.text('LAST TIME'), findsWidgets);
    expect(find.text('45s'), findsOneWidget);
  });

  testWidgets('hides LAST TIME for a timed exercise when the prior set has no held duration', (tester) async {
    final workout = Workout(
      id: 'w7',
      name: 'Core Day',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(
              name: 'Plank',
              reps: 0,
              sets: 3,
              restTime: const Duration(seconds: 30),
              timedDuration: const Duration(seconds: 30),
            ),
          ],
          sets: 3,
          restAfterSet: const Duration(seconds: 30),
        ),
      ],
    );
    fakeSessionRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w7',
      workoutName: 'Core Day',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Plank',
          targetReps: 0,
          targetWeight: 0,
          actualReps: 0,
          actualWeight: 0,
          skipped: false,
          // heldSeconds intentionally omitted — nothing meaningful to show.
        ),
      ],
    );

    await pumpPreview(tester, workout);

    expect(find.text('LAST TIME'), findsNothing);
  });

  testWidgets('does not overflow at a narrow 360dp phone width with a long LAST TIME value', (tester) async {
    final workout = Workout(
      id: 'w8',
      name: 'Narrow Phone Workout',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(
              name: 'Deadlift',
              reps: 12,
              sets: 3,
              restTime: const Duration(seconds: 90),
              weight: 102.5,
            ),
          ],
          sets: 3,
          restAfterSet: const Duration(seconds: 90),
        ),
      ],
    );
    fakeSessionRepo.store['ws-old'] = WorkoutSession(
      id: 'ws-old',
      workoutId: 'w8',
      workoutName: 'Narrow Phone Workout',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Deadlift',
          targetReps: 12,
          targetWeight: 102.5,
          actualReps: 12,
          actualWeight: 102.5,
          skipped: false,
        ),
      ],
    );

    await pumpPreview(tester, workout, surfaceSize: const Size(360, 800));

    expect(tester.takeException(), isNull);
    // find.text matches by string content, which stays the same whether
    // TextOverflow.ellipsis visually truncates it or not — so also assert
    // the rendered height stays single-line. A value pushed into the
    // squeezed SETS/REPS/WEIGHT/REST row (the pre-fix layout) wraps to a
    // second line there instead of throwing, which the exception check
    // above can't see but this height comparison catches.
    final labelHeight = tester.getSize(find.text('LAST TIME')).height;
    final valueHeight = tester.getSize(find.text('12 × 103kg')).height;
    expect(valueHeight, lessThan(labelHeight * 2));
  });

  testWidgets('falls back to the workout template when there is no prior session', (tester) async {
    final workout = Workout(
      id: 'w2',
      name: 'Fresh Workout',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(name: 'Squat', reps: 5, sets: 5, restTime: const Duration(seconds: 120), weight: 100),
          ],
          sets: 5,
          restAfterSet: const Duration(seconds: 120),
        ),
      ],
    );

    await pumpPreview(tester, workout);

    expect(find.text('5'), findsWidgets);
    expect(find.text('100 kg'), findsOneWidget);
    expect(find.text('LAST TIME'), findsNothing);
  });

  testWidgets('starting the workout navigates into the session countdown', (tester) async {
    final workout = Workout(
      id: 'w3',
      name: 'Quick Workout',
      exercises: [
        Superset(
          id: 's1',
          exercises: [
            Exercise(name: 'Squat', reps: 5, sets: 1, restTime: Duration.zero, weight: 100),
          ],
          sets: 1,
          restAfterSet: Duration.zero,
        ),
      ],
    );

    await pumpPreview(tester, workout);

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();

    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets('shows the workout\'s chosen icon on each exercise row instead of the generic dumbbell', (tester) async {
    final workout = buildWorkout(id: 'w4', icon: 'cardio');

    await pumpPreview(tester, workout);

    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
  });
}
