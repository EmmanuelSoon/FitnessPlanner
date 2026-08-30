import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/presentation/widgets/session_breakdown.dart';

import '../support/pump_app.dart';

LoggedSet _set({
  String exerciseName = 'Bench Press',
  int actualReps = 8,
  double actualWeight = 60,
  bool skipped = false,
  int? heldSeconds,
}) => LoggedSet(
      exerciseName: exerciseName,
      targetReps: 8,
      targetWeight: 60,
      actualReps: actualReps,
      actualWeight: actualWeight,
      skipped: skipped,
      heldSeconds: heldSeconds,
    );

void main() {
  testWidgets('shows a placeholder when there are no sets', (tester) async {
    await pumpApp(tester, const SessionBreakdown(sets: []));

    expect(find.text('No sets logged.'), findsOneWidget);
  });

  testWidgets('groups sets by exercise and shows count + reps×weight per line', (tester) async {
    await pumpApp(tester, SessionBreakdown(sets: [
      _set(exerciseName: 'Bench Press', actualReps: 8, actualWeight: 60),
      _set(exerciseName: 'Bench Press', actualReps: 7, actualWeight: 60),
      _set(exerciseName: 'Incline Fly', actualReps: 10, actualWeight: 15),
    ]));

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Incline Fly'), findsOneWidget);
    expect(find.text('2 sets · 8×60kg, 7×60kg'), findsOneWidget);
    expect(find.text('1 set · 10×15kg'), findsOneWidget);
  });

  testWidgets('renders a timed set by its held seconds instead of reps×weight', (tester) async {
    await pumpApp(tester, SessionBreakdown(sets: [
      _set(exerciseName: 'Plank', heldSeconds: 45),
    ]));

    expect(find.text('1 set · 45s'), findsOneWidget);
  });

  testWidgets('shows "Skipped" when every set for an exercise was skipped', (tester) async {
    await pumpApp(tester, SessionBreakdown(sets: [
      _set(exerciseName: 'Bench Press', skipped: true),
    ]));

    expect(find.text('Skipped'), findsOneWidget);
  });

  testWidgets('appends a skipped count alongside performed sets', (tester) async {
    await pumpApp(tester, SessionBreakdown(sets: [
      _set(exerciseName: 'Bench Press', actualReps: 8, actualWeight: 60),
      _set(exerciseName: 'Bench Press', skipped: true),
    ]));

    expect(find.text('1 set · 8×60kg  (1 skipped)'), findsOneWidget);
  });
}
