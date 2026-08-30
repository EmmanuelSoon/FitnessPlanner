import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/presentation/widgets/workout_picker.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('lists a rest-day option plus every workout, selecting one closes the sheet and reports its id', (tester) async {
    final workouts = [buildWorkout(id: 'w1', name: 'Push Day'), buildWorkout(id: 'w2', name: 'Pull Day')];
    String? selected = 'unset';

    await pumpApp(tester, Builder(builder: (context) {
      return TextButton(
        onPressed: () => showWorkoutPicker(
          context: context,
          workouts: workouts,
          selectedWorkoutId: 'w1',
          onSelected: (id) => selected = id,
        ),
        child: const Text('open'),
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsOneWidget);

    await tester.tap(find.text('Pull Day'));
    await tester.pumpAndSettle();

    expect(selected, 'w2');
    expect(find.text('Choose workout'), findsNothing);
  });

  testWidgets('picking rest day reports a null workout id', (tester) async {
    final workouts = [buildWorkout(id: 'w1', name: 'Push Day')];
    String? selected = 'unset';

    await pumpApp(tester, Builder(builder: (context) {
      return TextButton(
        onPressed: () => showWorkoutPicker(
          context: context,
          workouts: workouts,
          selectedWorkoutId: 'w1',
          onSelected: (id) => selected = id,
        ),
        child: const Text('open'),
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest day'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
