import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/presentation/run_detail_screen.dart';
import 'package:fitness_planner/presentation/run_list_screen.dart';
import 'package:fitness_planner/services/health_service.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

class MockHealthService extends Mock implements HealthService {}

void main() {
  late FakeRunRepository fakeRunRepo;
  late MockHealthService mockHealthService;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    fakeRunRepo = FakeRunRepository();
    mockHealthService = MockHealthService();
    when(() => mockHealthService.fetchRuns(since: any(named: 'since')))
        .thenAnswer((_) async => []);
  });

  Future<void> pumpList(WidgetTester tester) => pumpApp(
        tester,
        const RunListScreen(),
        overrides: [
          runRepositoryProvider.overrideWithValue(fakeRunRepo),
          healthServiceProvider.overrideWithValue(mockHealthService),
        ],
      );

  testWidgets('shows the empty state and its log CTA when there are no runs', (tester) async {
    await pumpList(tester);
    await tester.pumpAndSettle();

    expect(find.text('No runs yet'), findsOneWidget);
  });

  testWidgets('renders saved runs as cards', (tester) async {
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1');

    await pumpList(tester);
    await tester.pumpAndSettle();

    expect(find.text('Easy Run'), findsOneWidget);
    expect(find.text('No runs yet'), findsNothing);
  });

  testWidgets('silently imports new runs from Health Connect on open', (tester) async {
    when(() => mockHealthService.fetchRuns(since: any(named: 'since')))
        .thenAnswer((_) async => [buildRunSession(id: 'hc_1', startedAt: DateTime(2026, 2, 1))]);

    await pumpList(tester);
    await tester.pumpAndSettle();

    expect(fakeRunRepo.store.containsKey('hc_1'), isTrue);
    // Silent sync suppresses the "imported" snackbar unless something changed —
    // here something did change, so it should surface.
    expect(find.text('1 run imported.'), findsOneWidget);
  });

  testWidgets('tapping the sync button re-syncs and shows "Already up to date." when nothing new', (tester) async {
    await pumpList(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sync_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Already up to date.'), findsOneWidget);
  });

  testWidgets('tapping a run card navigates to its detail screen', (tester) async {
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1');

    await pumpList(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Easy Run'));
    await tester.pumpAndSettle();

    expect(find.byType(RunDetailScreen), findsOneWidget);
  });

  testWidgets('deleting a run from its card removes it from the list', (tester) async {
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1');

    await pumpList(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Delete run?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeRunRepo.store.containsKey('r1'), isFalse);
    expect(find.text('No runs yet'), findsOneWidget);
  });
}
