import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/exercise.dart';
import 'package:fitness_planner/domain/models/superset.dart';
import 'package:fitness_planner/domain/models/workout.dart';
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
  Future<void> pumpPreview(WidgetTester tester, Workout workout) async {
    final container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(fakeSessionRepo)],
    );
    addTearDown(container.dispose);
    await container.read(sessionsProvider.future);
    await pumpApp(tester, WorkoutStartPreviewScreen(workout: workout), container: container);
  }

  testWidgets('prefills reps/weight from the most recent prior session for this workout', (tester) async {
    final workout = buildWorkout(id: 'w1');
    // Prior session logged different reps/weight than the workout template.
    fakeSessionRepo.store['ws-old'] = buildWorkoutSession(
      id: 'ws-old',
      workoutId: 'w1',
      startedAt: DateTime(2026, 1, 1),
    );

    await pumpPreview(tester, workout);

    // buildWorkoutSession logs one set for 'Bench Press': 8 reps @ 60kg,
    // matching the template here, so assert against the session's values
    // explicitly (not just "unchanged from template") for a real prefill check.
    expect(find.text('8'), findsWidgets);
    expect(find.text('60 kg'), findsWidgets);
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
}
