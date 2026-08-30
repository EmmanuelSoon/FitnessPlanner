import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/presentation/widgets/number_picker_sheet.dart';

import '../support/pump_app.dart';

void main() {
  group('fmtWeight', () {
    test('renders a whole kilogram value without a trailing .0', () {
      expect(fmtWeight(60.0), '60');
    });

    test('rounds a fractional value to the nearest whole kilogram', () {
      expect(fmtWeight(62.6), '63');
    });
  });

  testWidgets('openSetsPicker shows Done and reports the selected value on tap', (tester) async {
    int? picked;
    await pumpApp(tester, Builder(builder: (context) {
      return TextButton(
        onPressed: () => openSetsPicker(context, 3, (v) => picked = v),
        child: const Text('open'),
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('SETS'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // No scroll performed — Done reports the initial (clamped) value.
    expect(picked, 3);
  });

  testWidgets('openRepsPicker labels the sheet REPS', (tester) async {
    await pumpApp(tester, Builder(builder: (context) {
      return TextButton(
        onPressed: () => openRepsPicker(context, 8, (_) {}),
        child: const Text('open'),
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('REPS'), findsOneWidget);
  });

  testWidgets('openWeightPicker labels the sheet WEIGHT (kg) and reports a double', (tester) async {
    double? picked;
    await pumpApp(tester, Builder(builder: (context) {
      return TextButton(
        onPressed: () => openWeightPicker(context, 60, (v) => picked = v),
        child: const Text('open'),
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT (kg)'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(picked, 60.0);
  });

  testWidgets('openDurationPicker reports the initial minutes/seconds on Done', (tester) async {
    Duration? picked;
    await pumpApp(tester, Builder(builder: (context) {
      return TextButton(
        onPressed: () => openDurationPicker(
          context,
          'REST',
          const Duration(minutes: 1, seconds: 30),
          (d) => picked = d,
        ),
        child: const Text('open'),
      );
    }));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('REST'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(picked, const Duration(minutes: 1, seconds: 30));
  });
}
