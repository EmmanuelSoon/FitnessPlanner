import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/domain/insights/strength_progress.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/presentation/lift_detail_screen.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart';

import '../support/pump_app.dart';

LiftSessionPoint _point(DateTime date, String sessionId, double value) => LiftSessionPoint(
      date: date,
      sessionId: sessionId,
      value: value,
      best: value,
      setsCounted: 1,
      setsPerformed: 1,
      metric: LiftMetric.weighted,
    );

LoggedSet _set({required double weight, required int reps}) => LoggedSet(
      exerciseName: 'Bench Press',
      targetReps: reps,
      targetWeight: weight,
      actualReps: reps,
      actualWeight: weight,
      skipped: false,
    );

LiftProgress _progress({int excludedHighRepSessions = 0}) => LiftProgress(
      exerciseName: 'Bench Press',
      metric: LiftMetric.weighted,
      startValue: 60,
      currentValue: 70,
      absoluteDelta: 10,
      percentDelta: 16.7,
      percentPer30Days: 16.7,
      sessionCount: 2,
      excludedHighRepSessions: excludedHighRepSessions,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2026, 1, 15),
      spanDays: 14,
      bestDate: DateTime(2026, 1, 15),
      weeksSinceBest: 0,
      isExtrapolated: true,
      status: LiftStatus.progressing,
    );

void main() {
  final points = [
    _point(DateTime(2026, 1, 1), 's1', 60),
    _point(DateTime(2026, 1, 15), 's2', 70),
  ];
  final series = LiftSeries(points: points, excludedHighRepSessions: 0);
  final setsBySessionId = {
    's1': [_set(weight: 60, reps: 5)],
    's2': [_set(weight: 70, reps: 5)],
  };

  Future<void> pumpDetail(
    WidgetTester tester, {
    LiftSeries? series,
    LiftProgress? progress,
    List<PersonalRecord> records = const [],
  }) =>
      pumpApp(
        tester,
        LiftDetailScreen(
          exerciseName: 'Bench Press',
          progress: progress ?? _progress(),
          series: series ?? LiftSeries(points: points, excludedHighRepSessions: 0),
          windowStart: DateTime(2025, 12, 1),
          setsBySessionId: setsBySessionId,
          records: records,
        ),
      );

  testWidgets('shows the exercise name as the screen title', (tester) async {
    await pumpDetail(tester, series: series);

    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('shows the current value with its percent delta', (tester) async {
    await pumpDetail(tester, series: series);

    expect(find.textContaining('70'), findsWidgets);
    expect(find.textContaining('+16.7%'), findsOneWidget);
  });

  testWidgets('initially shows the most recent session\'s sets', (tester) async {
    await pumpDetail(tester, series: series);

    expect(find.textContaining('5 @ 70kg'), findsOneWidget);
  });

  testWidgets('tapping an earlier point on the chart reveals that session\'s sets', (tester) async {
    await pumpDetail(tester, series: series);
    expect(find.textContaining('5 @ 70kg'), findsOneWidget);

    final topLeft = tester.getTopLeft(find.byType(AreaTrendChart));
    // Two points on a chart inset by the y-axis gutter: the first point
    // sits right at the gutter's edge, well left of the second.
    await tester.tapAt(topLeft + const Offset(36, 50));
    await tester.pump();

    expect(find.textContaining('5 @ 60kg'), findsOneWidget);
    expect(find.textContaining('5 @ 70kg'), findsNothing);
  });

  testWidgets('explains excluded high-rep sessions rather than silently omitting them', (tester) async {
    await pumpDetail(
      tester,
      series: LiftSeries(points: points, excludedHighRepSessions: 2),
    );

    expect(find.textContaining('2 sessions'), findsOneWidget);
    expect(find.textContaining('too many reps'), findsOneWidget);
  });

  testWidgets('does not mention excluded sessions when none were excluded', (tester) async {
    await pumpDetail(tester, series: series);

    expect(find.textContaining('too many reps'), findsNothing);
  });

  testWidgets('the PR ring marks the true all-time best point, not just the windowed one', (tester) async {
    // The lift's true peak (100) sits before the tab's currently selected
    // window even starts, so the windowed LiftProgress passed in has no
    // idea it exists and reports its own (lower) windowed bestDate instead.
    // The full-history chart still plots it, and the ring must follow the
    // chart's own data, not the windowed progress summary.
    final pointsWithOlderTrueBest = [
      _point(DateTime(2025, 10, 1), 's0', 100),
      _point(DateTime(2026, 1, 1), 's1', 60),
      _point(DateTime(2026, 1, 15), 's2', 70),
    ];
    final windowedProgress = _progress(); // bestDate: Jan 15 2026 (s2, value 70)

    await pumpDetail(
      tester,
      series: LiftSeries(points: pointsWithOlderTrueBest, excludedHighRepSessions: 0),
      progress: windowedProgress,
    );

    final chart = tester.widget<AreaTrendChart>(find.byType(AreaTrendChart));
    expect(chart.prIndices, {0});
  });

  test('the constructor asserts against an empty points list, rather than crashing later on _selectedIndex', () {
    expect(
      () => LiftDetailScreen(
        exerciseName: 'Bench Press',
        progress: _progress(),
        series: const LiftSeries(points: [], excludedHighRepSessions: 0),
        windowStart: DateTime(2026, 1, 1),
        setsBySessionId: const {},
        records: const [],
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
