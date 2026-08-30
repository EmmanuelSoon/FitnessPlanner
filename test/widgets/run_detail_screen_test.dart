import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/presentation/run_detail_screen.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late FakeRunRepository fakeRunRepo;

  setUp(() {
    fakeRunRepo = FakeRunRepository();
  });

  Future<void> pumpDetail(WidgetTester tester, RunSession run) => pumpApp(
        tester,
        RunDetailScreen(run: run),
        overrides: [runRepositoryProvider.overrideWithValue(fakeRunRepo)],
      );

  testWidgets('shows distance, pace, duration and manual source badge', (tester) async {
    final run = buildRunSession(id: 'r1');
    fakeRunRepo.store['r1'] = run;

    await pumpDetail(tester, run);

    // Distance/pace stat tiles render as one RichText (value + unit spans).
    expect(find.text('5.00 km', findRichText: true), findsOneWidget);
    expect(find.text('6:00 /km', findRichText: true), findsOneWidget); // 30min / 5km pace
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget); // 30-minute duration
  });

  testWidgets('shows optional fields only when present', (tester) async {
    final start = DateTime(2026, 1, 5, 7);
    final withExtras = RunSession(
      id: 'r1',
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 30)),
      distanceMeters: 5000,
      avgHeartRate: 150,
      calories: 320,
      cadenceSpm: 170,
      notes: 'Felt great',
    );

    await pumpDetail(tester, withExtras);

    expect(find.text('150 bpm'), findsOneWidget);
    expect(find.text('320 kcal'), findsOneWidget);
    expect(find.text('170 spm'), findsOneWidget);
    expect(find.text('Felt great'), findsOneWidget);
  });

  testWidgets('deleting the run removes it and pops back', (tester) async {
    final run = buildRunSession(id: 'r1');
    fakeRunRepo.store['r1'] = run;

    await pumpDetail(tester, run);
    await tester.tap(find.text('Delete run'));
    await tester.pumpAndSettle();

    expect(find.text('Delete run?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(fakeRunRepo.store.containsKey('r1'), isFalse);
    expect(find.byType(RunDetailScreen), findsNothing);
  });
}
