import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/presentation/widgets/insights_charts.dart';

import '../support/pump_app.dart';

void main() {
  // Three points spaced evenly across a 300px-wide chart: x=0, 150, 300.
  const series = [10.0, 20.0, 30.0];
  const pointLabels = ['Jan 1', 'Jan 8', 'Jan 15'];

  Future<void> pumpChart(
    WidgetTester tester, {
    List<double> series = series,
    List<String>? pointLabels = pointLabels,
  }) =>
      pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: AreaTrendChart(series: series, pointLabels: pointLabels),
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
}
