import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/models/exercise_library.dart';
import 'package:fitness_planner/presentation/widgets/exercise_library_picker.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> pumpOpener(
    WidgetTester tester, {
    void Function(LibraryExercise)? onSelected,
    void Function(String)? onBlank,
    String initialQuery = '',
  }) =>
      pumpApp(
        tester,
        Builder(builder: (context) {
          return TextButton(
            onPressed: () => showExerciseLibraryPicker(
              context: context,
              onSelected: onSelected ?? (_) {},
              onBlank: onBlank ?? (_) {},
              initialQuery: initialQuery,
            ),
            child: const Text('open'),
          );
        }),
      );

  testWidgets('with an empty query, groups the library by category', (tester) async {
    await pumpOpener(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('CHEST'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Type my own'), findsOneWidget);
  });

  testWidgets('typing a query filters to matching exercises across categories', (tester) async {
    await pumpOpener(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'squat');
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Bulgarian Split Squat'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    // Category headers are only shown for the ungrouped (empty-query) view.
    expect(find.text('CHEST'), findsNothing);
  });

  testWidgets('typing a query with no matches shows the empty message', (tester) async {
    await pumpOpener(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzznotreal');
    await tester.pumpAndSettle();

    expect(find.text('No exercises found'), findsOneWidget);
  });

  testWidgets('tapping a library exercise pops with onSelected', (tester) async {
    LibraryExercise? picked;
    await pumpOpener(tester, onSelected: (e) => picked = e);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bench Press');
    await tester.pumpAndSettle();
    // The typed text also appears in the search field itself, so target the
    // last "Bench Press" match — the result tile.
    await tester.tap(find.text('Bench Press').last);
    await tester.pumpAndSettle();

    expect(picked?.name, 'Bench Press');
    expect(find.text('No exercises found'), findsNothing);
  });

  testWidgets('"Use ..." with typed text pops with onBlank and the typed name', (tester) async {
    String? typed;
    await pumpOpener(tester, onBlank: (v) => typed = v);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'My Custom Move');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use "My Custom Move"'));
    await tester.pumpAndSettle();

    expect(typed, 'My Custom Move');
  });
}
