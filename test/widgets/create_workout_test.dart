import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/presentation/create_workout.dart';

import '../support/fake_repositories.dart';
import '../support/pump_app.dart';

Future<void> _addExerciseByTyping(WidgetTester tester, String name) async {
  await tester.tap(find.text('Add exercise'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), name);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Use "$name"'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeWorkoutRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeWorkoutRepository();
  });

  Future<void> pumpCreateWorkout(WidgetTester tester) => pumpApp(
        tester,
        const CreateWorkoutScreen(),
        overrides: [workoutRepositoryProvider.overrideWithValue(fakeRepo)],
      );

  testWidgets('shows a validation error when saving without a workout name', (tester) async {
    await pumpCreateWorkout(tester);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();

    expect(find.text('Please enter a workout name'), findsOneWidget);
  });

  testWidgets('shows a validation error when an exercise has no name', (tester) async {
    await pumpCreateWorkout(tester);
    await tester.enterText(find.byType(TextField).first, 'Push Day');

    // Add a blank-named exercise via "Type my own" with nothing typed.
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type my own'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();

    expect(find.text('All exercises must have a name'), findsOneWidget);
  });

  testWidgets('saves a workout with a superset and returns to the list', (tester) async {
    await pumpCreateWorkout(tester);
    await tester.enterText(find.byType(TextField).first, 'Push Day');

    await _addExerciseByTyping(tester, 'Exercise A');
    await _addExerciseByTyping(tester, 'Exercise B');

    // Group the two single-exercise supersets together.
    await tester.tap(find.text('Group with next'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    // On the preview screen: superset badge shown, save persists.
    expect(find.text('SUPERSET'), findsWidgets);
    await tester.tap(find.text('Save workout'));
    await tester.pumpAndSettle();

    expect(fakeRepo.store, hasLength(1));
    final saved = fakeRepo.store.values.single;
    expect(saved.name, 'Push Day');
    expect(saved.exercises, hasLength(1));
    expect(saved.exercises.single.exercises.map((e) => e.name), ['Exercise A', 'Exercise B']);
    // Default weight (bodyweight) is optional — never set, defaults to 0.
    expect(saved.exercises.single.exercises.every((e) => e.weight == 0), isTrue);

    // Back on CreateWorkoutScreen (the root route in this test).
    expect(find.text('New workout'), findsOneWidget);
  });
}
