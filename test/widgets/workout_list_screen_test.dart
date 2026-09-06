import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/presentation/workout_list_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/theme/app_theme.dart';

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

  testWidgets('renders the workout\'s chosen icon on its card instead of the generic dumbbell', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Cardio Day', icon: 'cardio');

    await pumpList(tester);

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
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

  testWidgets('the "Workouts" headline aligns to the same left edge as the cards', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpList(tester);

    final headline = tester.getTopLeft(find.text('Workouts')).dx;
    final card = tester.getTopLeft(find.byType(WorkoutListCard).first).dx;

    expect(headline, card);
  });

  testWidgets('the "Workouts" headline uses the shared headline text scale', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpList(tester);

    final headline = tester.widget<Text>(find.text('Workouts'));

    expect(headline.style?.fontSize, kTextHeadline);
  });

  testWidgets('the date eyebrow label uses the shared label text scale', (tester) async {
    fakeRepo.store['w1'] = buildWorkout(id: 'w1', name: 'Push Day');
    await pumpList(tester);

    final dateLabel = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains(RegExp(r'^[A-Z]+ · ')) ?? false),
      ),
    );

    expect(dateLabel.style?.fontSize, kTextLabel);
  });
}
