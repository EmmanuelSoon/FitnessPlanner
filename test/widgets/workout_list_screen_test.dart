import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/presentation/workout_list_screen.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late FakeWorkoutRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeWorkoutRepository();
  });

  Future<void> pumpList(WidgetTester tester) => pumpApp(
        tester,
        const WorkoutListScreen(),
        overrides: [workoutRepositoryProvider.overrideWithValue(fakeRepo)],
      );

  testWidgets('shows the empty state and its create CTA when there are no workouts', (tester) async {
    await pumpList(tester);

    expect(find.text('Nothing here yet.'), findsOneWidget);

    await tester.tap(find.text('Create your first workout'));
    await tester.pumpAndSettle();

    expect(find.text('New workout'), findsOneWidget);
  });

  testWidgets('renders saved workouts as cards', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');

    await pumpList(tester);

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsNothing);
  });

  testWidgets('edit action opens CreateWorkoutScreen pre-filled for that workout', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit workout'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
  });

  testWidgets('delete action confirms then removes the workout', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Push Day"?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeRepo.store.containsKey('w1'), isFalse);
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });
}
