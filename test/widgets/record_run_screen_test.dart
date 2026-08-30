import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/presentation/record_run_screen.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  late FakeRunRepository fakeRunRepo;

  setUp(() {
    fakeRunRepo = FakeRunRepository();
  });

  Future<void> pumpRecord(WidgetTester tester, {RunSession? existingRun, DateTime? initialDate}) => pumpApp(
        tester,
        RecordRunScreen(existingRun: existingRun, initialDate: initialDate),
        overrides: [runRepositoryProvider.overrideWithValue(fakeRunRepo)],
      );

  testWidgets('shows "Log Run" for a new entry and "Edit Run" when editing', (tester) async {
    await pumpRecord(tester);
    expect(find.text('Log Run'), findsOneWidget);

    final existing = buildRunSession(id: 'r1');
    await pumpRecord(tester, existingRun: existing);
    expect(find.text('Edit Run'), findsOneWidget);
  });

  testWidgets('rejects saving with a zero/blank distance', (tester) async {
    await pumpRecord(tester);

    await tester.tap(find.text('Save run'));
    await tester.pump();

    expect(find.text('Enter a valid distance.'), findsOneWidget);
    expect(fakeRunRepo.store, isEmpty);
  });

  testWidgets('rejects saving with a valid distance but zero duration', (tester) async {
    await pumpRecord(tester);

    await tester.enterText(find.widgetWithText(TextField, '0.00'), '5.0');
    await tester.tap(find.text('Save run'));
    await tester.pump();

    expect(find.text('Enter a duration greater than zero.'), findsOneWidget);
    expect(fakeRunRepo.store, isEmpty);
  });

  testWidgets('saving a valid manual run persists it and closes the screen', (tester) async {
    await pumpRecord(tester);

    await tester.enterText(find.widgetWithText(TextField, '0.00'), '5.0');
    // Bump the minutes wheel (index 1: HH, MM, SS) to a non-zero value.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded).at(1));
      await tester.pump();
    }
    await tester.tap(find.text('Save run'));
    await tester.pumpAndSettle();

    expect(fakeRunRepo.store, hasLength(1));
    final saved = fakeRunRepo.store.values.single;
    expect(saved.distanceMeters, 5000);
    expect(saved.duration, const Duration(minutes: 3));
    expect(saved.source, RunSource.manual);
  });

  testWidgets('picking a run type chip selects it', (tester) async {
    await pumpRecord(tester);

    await tester.tap(find.text('Tempo'));
    await tester.pump();

    // No assertion API for chip color here; verify the save round-trips the
    // chosen type by saving a valid run and checking the persisted model.
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '5.0');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded).at(1));
      await tester.pump();
    }
    await tester.tap(find.text('Save run'));
    await tester.pumpAndSettle();

    expect(fakeRunRepo.store.values.single.runType, RunType.tempo);
  });

  testWidgets('editing an existing run prefills its fields and saves changes to the same id', (tester) async {
    final existing = buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5, 7));
    fakeRunRepo.store['r1'] = existing;

    await pumpRecord(tester, existingRun: existing);

    expect(find.text('5.00'), findsOneWidget); // distanceKm prefill
    expect(find.text('Save changes'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRunRepo.store, hasLength(1));
    expect(fakeRunRepo.store.containsKey('r1'), isTrue);
  });
}
