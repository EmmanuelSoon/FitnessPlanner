import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/strength_progress.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart';

import '../support/pump_app.dart';

LiftProgress _liftProgress({
  LiftStatus status = LiftStatus.progressing,
  double? percentDelta = 8.3,
}) => LiftProgress(
  exerciseName: 'Bench Press',
  metric: LiftMetric.weighted,
  startValue: 60,
  currentValue: 65,
  absoluteDelta: 5,
  percentDelta: percentDelta,
  percentPer30Days: percentDelta,
  sessionCount: 4,
  excludedHighRepSessions: 0,
  firstDate: DateTime(2026, 1, 1),
  lastDate: DateTime(2026, 2, 1),
  spanDays: 31,
  bestDate: DateTime(2026, 2, 1),
  weeksSinceBest: 0,
  isExtrapolated: false,
  status: status,
);

/// Every rendered numeric gridline label in the chart under test, parsed
/// back to doubles via [parse] — lets tests assert on the *set* of nice
/// values chosen without hardcoding the axis algorithm's exact output.
List<double> _renderedValues(WidgetTester tester, double? Function(String) parse) {
  final values = <double>[];
  for (final element in tester.widgetList<Text>(find.byType(Text))) {
    final v = parse(element.data ?? '');
    if (v != null) values.add(v);
  }
  return values;
}

void main() {
  group('computeNiceScale', () {
    test('pads a range out to round numbers on both ends', () {
      final scale = computeNiceScale(3, 47);

      expect(scale.min, lessThanOrEqualTo(3));
      expect(scale.max, greaterThanOrEqualTo(47));
    });

    test('an already-round range keeps its exact bounds', () {
      final scale = computeNiceScale(0, 40, targetTicks: 5);

      expect(scale.min, 0);
      expect(scale.max, 40);
      expect(scale.step, 10);
    });

    test('a flat non-zero series pads to a small range around the value, not a zero-width one', () {
      final scale = computeNiceScale(15, 15);

      expect(scale.max - scale.min, greaterThan(0));
      expect(scale.min, lessThan(15));
      expect(scale.max, greaterThan(15));
    });

    test('a flat series at zero pads to a small range around zero, not a zero-width one', () {
      final scale = computeNiceScale(0, 0);

      expect(scale.max - scale.min, greaterThan(0));
    });

    test('handles a range spanning negative to positive values', () {
      final scale = computeNiceScale(-12, 8);

      expect(scale.min, lessThanOrEqualTo(-12));
      expect(scale.max, greaterThanOrEqualTo(8));
    });

    test('gridline count stays within a readable bound across a variety of ranges', () {
      for (final range in [(0.0, 1.0), (0.0, 47.0), (65.0, 426.0), (100.0, 100.5), (-5.0, 500.0)]) {
        final scale = computeNiceScale(range.$1, range.$2);
        expect(scale.ticks.length, inInclusiveRange(3, 6), reason: 'for range $range');
      }
    });

    test('targetTicks of 1 does not crash on Infinity.floor()', () {
      expect(() => computeNiceScale(0, 10, targetTicks: 1), returnsNormally);

      final scale = computeNiceScale(0, 10, targetTicks: 1);
      expect(scale.min.isFinite, isTrue);
      expect(scale.max.isFinite, isTrue);
      expect(scale.step.isFinite, isTrue);
    });

    test('a step finer than one decimal place is still distinctly representable', () {
      final scale = computeNiceScale(0.01, 0.03);
      final formatted = [for (final tick in scale.ticks) tick.toStringAsFixed(scale.decimalPlaces)];

      expect(formatted.toSet().length, formatted.length, reason: 'formatted: $formatted');
    });
  });

  group('liftValueSuffix', () {
    test('a weighted lift has no suffix', () {
      expect(liftValueSuffix(LiftMetric.weighted), '');
    });

    test('a bodyweight lift is suffixed with reps', () {
      expect(liftValueSuffix(LiftMetric.repsPerSet), ' reps');
    });

    test('a timed-hold lift is suffixed with seconds', () {
      expect(liftValueSuffix(LiftMetric.holdSeconds), 's');
    });
  });

  group('liftPercentLabel', () {
    test('a holding lift reads "held" regardless of its percent delta', () {
      expect(liftPercentLabel(_liftProgress(status: LiftStatus.holding, percentDelta: 0.1)), 'held');
    });

    test('a positive delta gets an explicit plus sign', () {
      expect(liftPercentLabel(_liftProgress(percentDelta: 16.0)), '+16.0%');
    });

    test('a negative delta keeps its own minus sign, not a double one', () {
      expect(liftPercentLabel(_liftProgress(status: LiftStatus.regressing, percentDelta: -4.0)), '-4.0%');
    });

    test('a null percent delta is left blank rather than fabricated as no change', () {
      expect(
        liftPercentLabel(_liftProgress(status: LiftStatus.insufficientData, percentDelta: null)),
        '',
      );
    });
  });

  group('chartTickIndices', () {
    test('an empty series has no ticks', () {
      expect(chartTickIndices(0), isEmpty);
    });

    test('a series no longer than the tick budget shows every index', () {
      expect(chartTickIndices(3, maxTicks: 4), [0, 1, 2]);
    });

    test('a longer series is thinned to evenly spaced indices including both ends', () {
      final indices = chartTickIndices(20, maxTicks: 4);

      expect(indices.length, lessThanOrEqualTo(4));
      expect(indices.first, 0);
      expect(indices.last, 19);
    });

    test('a maxTicks of 1 does not divide by zero', () {
      expect(() => chartTickIndices(5, maxTicks: 1), returnsNormally);
      expect(chartTickIndices(5, maxTicks: 1), isNotEmpty);
    });
  });

  group('chartX / chartY / chartIndexForX', () {
    test('chartX and chartIndexForX are inverses of each other', () {
      const width = 300.0;
      const n = 5;

      for (var i = 0; i < n; i++) {
        expect(chartIndexForX(chartX(i, n, width), n, width), i);
      }
    });

    test('chartY places a value at scale.max nearest the top, and scale.min nearest the bottom', () {
      const scale = NiceScale(min: 0, max: 10, step: 5);
      const height = 108.0;

      expect(chartY(10, scale, false, height), lessThan(chartY(0, scale, false, height)));
    });

    test('an inverted chartY places scale.min nearest the top', () {
      const scale = NiceScale(min: 0, max: 10, step: 5);
      const height = 108.0;

      expect(chartY(0, scale, true, height), lessThan(chartY(10, scale, true, height)));
    });
  });

  // Three points spaced evenly across a 300px-wide chart: x=0, 150, 300.
  const series = [10.0, 20.0, 30.0];
  const pointLabels = ['Jan 1', 'Jan 8', 'Jan 15'];

  Future<void> pumpChart(
    WidgetTester tester, {
    List<double> series = series,
    List<String>? pointLabels = pointLabels,
    String? unitLabel,
    String Function(double)? valueFormatter,
    double? height,
  }) =>
      pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: AreaTrendChart(
              series: series,
              pointLabels: pointLabels,
              unitLabel: unitLabel,
              valueFormatter: valueFormatter,
              height: height ?? 108,
            ),
          ),
        ),
        surfaceSize: const Size(400, 400),
      );

  testWidgets('tapping a point pins the tooltip to the nearest index', (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    await tester.tapAt(topLeft + const Offset(150, 50));
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, 1);
  });

  testWidgets('dragging scrubs the tooltip to whichever point is nearest', (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    final gesture = await tester.startGesture(topLeft + const Offset(0, 50));
    await gesture.moveTo(topLeft + const Offset(300, 50));
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, 2);

    await gesture.up();
  });

  testWidgets('dragging past the right edge clamps to the last point', (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    // The chart itself is only 300px wide but the surface is 400px, so the
    // drag can continue on-screen well past the chart's right edge.
    final gesture = await tester.startGesture(topLeft + const Offset(150, 50));
    await gesture.moveTo(topLeft + const Offset(390, 50));
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, 2);

    await gesture.up();
  });

  testWidgets('dragging past the left edge clamps to the first point', (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    final gesture = await tester.startGesture(topLeft + const Offset(150, 50));
    await gesture.moveTo(topLeft + const Offset(-50, 50));
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, 0);

    await gesture.up();
  });

  testWidgets('the tooltip stays pinned on the last-touched point after lifting the finger',
      (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    final gesture = await tester.startGesture(topLeft + const Offset(150, 50));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, 1);
  });

  testWidgets('with pointLabels null, touching the chart shows no tooltip', (tester) async {
    await pumpChart(tester, pointLabels: null);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    await tester.tapAt(topLeft + const Offset(150, 50));
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, isNull);
  });

  testWidgets('with a pointLabels/series length mismatch, touching the chart shows no tooltip',
      (tester) async {
    await pumpChart(tester, pointLabels: const ['Jan 1', 'Jan 8']);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    await tester.tapAt(topLeft + const Offset(150, 50));
    await tester.pump();

    final state = tester.state<AreaTrendChartState>(find.byType(AreaTrendChart));
    expect(state.touchedIndex, isNull);
  });

  testWidgets('labels the max value near the top and the min value near the bottom', (tester) async {
    await pumpChart(tester);

    expect(find.text('30'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('30')).dy,
      lessThan(tester.getTopLeft(find.text('10')).dy),
    );
  });

  testWidgets('an inverted chart labels the min value near the top and the max value near the bottom',
      (tester) async {
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: AreaTrendChart(series: series, pointLabels: pointLabels, invert: true),
        ),
      ),
      surfaceSize: const Size(400, 400),
    );

    expect(
      tester.getTopLeft(find.text('10')).dy,
      lessThan(tester.getTopLeft(find.text('30')).dy),
    );
  });

  testWidgets('a flat series draws multiple gridlines around the value instead of a degenerate axis',
      (tester) async {
    final scale = computeNiceScale(15, 15);
    await pumpChart(tester, series: const [15.0, 15.0, 15.0]);

    final rendered = _renderedValues(tester, (s) => double.tryParse(s));

    expect(rendered.where((v) => v == scale.min), isNotEmpty);
    expect(rendered.where((v) => v == scale.max), isNotEmpty);
    expect(rendered.toSet().length, greaterThanOrEqualTo(3));
  });

  testWidgets('a custom valueFormatter formats every gridline label instead of the raw number',
      (tester) async {
    String format(double v) => '${v ~/ 60}:${(v % 60).round().toString().padLeft(2, '0')}';
    final scale = computeNiceScale(65, 426);

    await pumpChart(
      tester,
      series: const [65.0, 426.0],
      valueFormatter: format,
    );

    for (final tick in scale.ticks) {
      expect(find.text(format(tick)), findsOneWidget, reason: 'gridline for $tick');
    }
    expect(find.text('426'), findsNothing);
    expect(find.text('65'), findsNothing);
  });

  testWidgets('a series longer than the tick budget shows evenly spaced date labels, not just the edges',
      (tester) async {
    final longSeries = [for (var i = 0; i < 10; i++) i.toDouble()];
    final longLabels = [for (var i = 0; i < 10; i++) 'Day $i'];

    await pumpChart(tester, series: longSeries, pointLabels: longLabels);

    expect(find.text('Day 0'), findsOneWidget);
    expect(find.text('Day 9'), findsOneWidget);
    // At least one interior tick beyond the two edges.
    final interiorFound = [for (var i = 1; i < 9; i++) 'Day $i']
        .where((label) => find.text(label).evaluate().isNotEmpty);
    expect(interiorFound, isNotEmpty);
  });

  testWidgets('a series within the tick budget shows every date label', (tester) async {
    await pumpChart(tester);

    expect(find.text('Jan 1'), findsOneWidget);
    expect(find.text('Jan 8'), findsOneWidget);
    expect(find.text('Jan 15'), findsOneWidget);
  });

  testWidgets('shows the unit label when provided', (tester) async {
    await pumpChart(tester, unitLabel: 'kg');

    expect(find.text('kg'), findsOneWidget);
  });

  testWidgets('shows no unit label when not provided', (tester) async {
    await pumpChart(tester);

    expect(find.text('kg'), findsNothing);
  });

  testWidgets('a height shorter than the gridline label reserve does not crash', (tester) async {
    await pumpChart(tester, height: 5);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty series still draws a baseline hairline', (tester) async {
    await pumpChart(tester, series: const [], pointLabels: null);

    expect(find.byType(AreaTrendChart), paints..line());
  });

  testWidgets('calls onTouchIndex with the touched index', (tester) async {
    int? touched;
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: AreaTrendChart(
            series: series,
            pointLabels: pointLabels,
            onTouchIndex: (i) => touched = i,
          ),
        ),
      ),
      surfaceSize: const Size(400, 400),
    );

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    await tester.tapAt(topLeft + const Offset(150, 50));
    await tester.pump();

    expect(touched, 1);
  });

  testWidgets('the window-start marker paints above the area fill, not underneath it', (tester) async {
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: AreaTrendChart(series: series, pointLabels: pointLabels, markerIndex: 1),
        ),
      ),
      surfaceSize: const Size(400, 400),
    );

    // A rising curve's semi-transparent gradient fill (a path draw) would
    // hide a marker painted before it — the marker's dashed segments (line
    // draws) must occur after the fill, not before.
    expect(find.byType(AreaTrendChart), paints..path()..line());
  });

  testWidgets('a markerIndex renders without crashing, in range or out of it', (tester) async {
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: AreaTrendChart(series: series, pointLabels: pointLabels, markerIndex: 1),
        ),
      ),
      surfaceSize: const Size(400, 400),
    );
    expect(tester.takeException(), isNull);

    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          child: AreaTrendChart(series: series, pointLabels: pointLabels, markerIndex: 99),
        ),
      ),
      surfaceSize: const Size(400, 400),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to a different dataset at the same chart clears a pinned tooltip',
      (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    await tester.tapAt(topLeft + const Offset(150, 50));
    await tester.pump();
    expect(tester.state<AreaTrendChartState>(find.byType(AreaTrendChart)).touchedIndex, 1);

    // Same chart position/type but a new series — e.g. the exercise-trend
    // card swapping in a different exercise's data. The previous index
    // shouldn't carry over onto a dataset it was never touched on.
    await pumpChart(tester, series: const [1.0, 2.0], pointLabels: const ['Feb 1', 'Feb 8']);

    expect(tester.state<AreaTrendChartState>(find.byType(AreaTrendChart)).touchedIndex, isNull);
  });
}
