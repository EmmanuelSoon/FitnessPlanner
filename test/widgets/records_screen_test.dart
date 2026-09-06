import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/presentation/records_screen.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late FakeSessionRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeSessionRepository();
  });

  Future<void> pumpRecords(WidgetTester tester) => pumpApp(
        tester,
        const RecordsScreen(),
        overrides: [sessionRepositoryProvider.overrideWithValue(fakeRepo)],
      );

  testWidgets('shows the empty state when there are no records yet', (tester) async {
    await pumpRecords(tester);

    expect(find.text('No records yet'), findsOneWidget);
  });

  testWidgets('lists a personal record with its kind, exercise, and value', (tester) async {
    // A single weighted set surfaces two record types (heaviest weight and
    // best est. 1RM), so "Bench Press" and its heaviest-weight kind label
    // are each checked for exactly one occurrence, but "60" (the weight)
    // and "76" (the rounded Epley estimate) each belong to their own card.
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpRecords(tester);

    expect(find.text('HEAVIEST WEIGHT'), findsOneWidget);
    expect(find.text('BEST EST. 1RM'), findsOneWidget);
    expect(find.text('Bench Press'), findsNWidgets(2));
    expect(find.text('60'), findsOneWidget);
    expect(find.text('76'), findsOneWidget);
  });

  testWidgets('lists records for multiple exercises, newest first', (tester) async {
    fakeRepo.store['ws1'] = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5),
      endedAt: DateTime(2026, 1, 5, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Push-up',
          targetReps: 15,
          targetWeight: 0,
          actualReps: 15,
          actualWeight: 0,
          skipped: false,
        ),
      ],
    );
    fakeRepo.store['ws2'] = WorkoutSession(
      id: 'ws2',
      workoutId: 'w1',
      workoutName: 'Pull Day',
      startedAt: DateTime(2026, 1, 12),
      endedAt: DateTime(2026, 1, 12, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Pull-up',
          targetReps: 10,
          targetWeight: 0,
          actualReps: 10,
          actualWeight: 0,
          skipped: false,
        ),
      ],
    );

    await pumpRecords(tester);

    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Pull-up'), findsOneWidget);
  });
}
