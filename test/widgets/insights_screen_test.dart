import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/insights/insights_window.dart';
import 'package:fitness_planner/domain/insights/strength_progress.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/insights_screen.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

LiftProgress _progress({
  String exerciseName = 'Bench Press',
  LiftStatus status = LiftStatus.progressing,
  double startValue = 60,
  double currentValue = 65,
  double? percentDelta = 8.3,
}) => LiftProgress(
  exerciseName: exerciseName,
  metric: LiftMetric.weighted,
  startValue: startValue,
  currentValue: currentValue,
  absoluteDelta: currentValue - startValue,
  percentDelta: percentDelta,
  percentPer30Days: percentDelta,
  sessionCount: 4,
  excludedHighRepSessions: 0,
  firstDate: DateTime(2026, 1, 1),
  lastDate: DateTime(2026, 2, 1),
  spanDays: 31,
  bestDate: DateTime(2026, 2, 1),
  weeksSinceBest: status == LiftStatus.holding ? 6 : 0,
  isExtrapolated: false,
  status: status,
);

LiftSessionPoint _point(DateTime date, {double value = 60}) => LiftSessionPoint(
  date: date,
  sessionId: date.toIso8601String(),
  value: value,
  best: value,
  setsCounted: 1,
  setsPerformed: 1,
  metric: LiftMetric.weighted,
);

void _rankedLiftsForWindowTests() {
  group('rankedLiftsForWindow', () {
    test('the window cutoff is Monday-aligned, not a raw day-count subtraction from now', () {
      // now = Wed Jan 7 2026. For an 8-week window the raw day-count cutoff
      // (now - 56d) is Nov 12 2025, but the Monday-aligned week start used
      // for rest-week exclusion is Nov 17 2025 — a point dated in that 5-day
      // gap must not be included, or it can silently escape deload-week
      // exclusion (whose lookup only ever checks aligned week starts).
      final now = DateTime(2026, 1, 7);
      final points = [
        _point(DateTime(2025, 11, 14)), // in the misalignment gap
        _point(DateTime(2025, 11, 20)),
        _point(DateTime(2025, 11, 27)),
        _point(DateTime(2025, 12, 4)),
        _point(DateTime(2025, 12, 11)),
        _point(DateTime(2025, 12, 18)),
      ];
      final series = {'Bench Press': LiftSeries(points: points, excludedHighRepSessions: 0)};

      final ranked = rankedLiftsForWindow(
        series,
        window: InsightsWindow.eightWeeks,
        sessionDates: [for (final p in points) p.date],
        mesocycle: null,
        now: now,
      );

      expect(ranked.single.sessionCount, 5);
    });
  });
}

void _verdictTests() {
  group('computeVerdict', () {
    test('an empty ranked list reports insufficient data', () {
      final verdict = computeVerdict(const []);

      expect(verdict.kind, VerdictKind.insufficientData);
    });

    test('no lift progressing reports all-stalled', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Squat', status: LiftStatus.holding),
      ]);

      expect(verdict.kind, VerdictKind.allStalled);
    });

    test('at least one progressing lift reports the progressing kind', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Bench Press', status: LiftStatus.progressing),
      ]);

      expect(verdict.kind, VerdictKind.progressing);
    });

    test('the headline counts how many lifts are moving out of the total', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Bench Press', status: LiftStatus.progressing),
        _progress(exerciseName: 'Squat', status: LiftStatus.holding),
      ]);

      expect(verdict.headline, 'One of two lifts is moving.');
    });

    test('a regressing lift is named in the detail line ahead of a holding lift', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Bench Press', status: LiftStatus.progressing),
        _progress(exerciseName: 'Squat', status: LiftStatus.holding),
        _progress(exerciseName: 'Deadlift', status: LiftStatus.regressing, percentDelta: -4.0),
      ]);

      expect(verdict.detail, contains('Deadlift'));
    });

    test('a holding lift not named when nothing is regressing', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Bench Press', status: LiftStatus.progressing),
        _progress(exerciseName: 'Squat', status: LiftStatus.holding),
      ]);

      expect(verdict.detail, contains('Squat'));
    });

    test('every lift progressing names nothing as stuck', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Bench Press', status: LiftStatus.progressing),
      ]);

      expect(verdict.detail, isNot(contains('Bench Press')));
    });

    test('every lift progressing does not contradict itself by calling anything steady', () {
      final verdict = computeVerdict([
        _progress(exerciseName: 'Bench Press', status: LiftStatus.progressing),
        _progress(exerciseName: 'Squat', status: LiftStatus.progressing),
      ]);

      expect(verdict.detail, isNot(contains('holding steady')));
    });
  });
}

DateTime _mondayOf(DateTime dt) {
  final day = DateTime(dt.year, dt.month, dt.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

// The page is a single vertical ListView, so `scrollUntilVisible`'s default
// (find.byType(Scrollable)) pins to it without ambiguity.
final Finder _outerScrollable = find.byType(Scrollable).first;

WorkoutSession _liftSession({
  required String id,
  required DateTime startedAt,
  String exerciseName = 'Bench Press',
  required double weight,
  int reps = 5,
}) => WorkoutSession(
  id: id,
  workoutId: 'w1',
  workoutName: 'Push Day',
  startedAt: startedAt,
  endedAt: startedAt.add(const Duration(minutes: 45)),
  completed: true,
  sets: [
    LoggedSet(
      exerciseName: exerciseName,
      targetReps: reps,
      targetWeight: weight,
      actualReps: reps,
      actualWeight: weight,
      skipped: false,
    ),
  ],
);

WorkoutSession _categorySession({
  required String id,
  required DateTime startedAt,
  required String category,
  required int setCount,
  String exerciseName = 'Squat',
}) => WorkoutSession(
  id: id,
  workoutId: 'w1',
  workoutName: 'Leg Day',
  startedAt: startedAt,
  endedAt: startedAt.add(const Duration(minutes: 45)),
  completed: true,
  sets: [
    for (var i = 0; i < setCount; i++)
      LoggedSet(
        exerciseName: exerciseName,
        targetReps: 8,
        targetWeight: 60,
        actualReps: 8,
        actualWeight: 60,
        skipped: false,
        category: category,
      ),
  ],
);

void main() {
  _verdictTests();
  _rankedLiftsForWindowTests();

  late FakeSessionRepository fakeRepo;
  late FakeRunRepository fakeRunRepo;

  setUp(() {
    fakeRepo = FakeSessionRepository();
    fakeRunRepo = FakeRunRepository();
  });

  Future<void> pumpInsights(WidgetTester tester) => pumpApp(
        tester,
        const InsightsScreen(),
        overrides: [
          sessionRepositoryProvider.overrideWithValue(fakeRepo),
          runRepositoryProvider.overrideWithValue(fakeRunRepo),
        ],
      );

  testWidgets('shows the empty state when there are no sessions', (tester) async {
    await pumpInsights(tester);

    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('does not show the empty state when there are no workout sessions but a run is logged',
      (tester) async {
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('No sessions yet'), findsNothing);
    expect(find.text('Strength'), findsOneWidget); // the mode toggle is showing
  });

  testWidgets('defaults to Running mode when there are runs but no workout sessions', (tester) async {
    final thisWeek = _mondayOf(DateTime.now());
    fakeRunRepo.store['r1'] = buildRunSession(
      id: 'r1',
      startedAt: thisWeek.add(const Duration(days: 1, hours: 7)),
    );

    await pumpInsights(tester);

    expect(find.text('Distance over time'.toUpperCase()), findsOneWidget);
    expect(find.text('5.0'), findsWidgets); // distance: strip cell + distance card
  });

  testWidgets('shows insufficient-data copy and an empty ledger message when no lift has enough sessions',
      (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.textContaining('Not enough data yet.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('liftLedger')),
        matching: find.textContaining('Log four sessions'),
      ),
      findsOneWidget,
    );
  });

  // Four sessions, reps==1 (so estimatedOneRm is exactly the logged weight),
  // spanning 24 days: start window mean(60,65)=62.5, current window
  // mean(70,75)=72.5 — a +16.0% single progressing lift.
  void seedFourSessionProgressingLift(FakeSessionRepository fakeRepo) {
    final start = DateTime.now().subtract(const Duration(days: 24));
    for (var i = 0; i < 4; i++) {
      fakeRepo.store['ws$i'] = _liftSession(
        id: 'ws$i',
        startedAt: start.add(Duration(days: i * 8)),
        weight: 60 + i * 5,
        reps: 1,
      );
    }
  }

  testWidgets('the lift ledger shows a lift once it has four sessions spanning three weeks', (tester) async {
    seedFourSessionProgressingLift(fakeRepo);

    await pumpInsights(tester);

    final ledger = find.byKey(const ValueKey('liftLedger'));
    expect(find.descendant(of: ledger, matching: find.text('Bench Press')), findsOneWidget);
  });

  testWidgets('the ledger shows the averaged start and current values for a lift', (tester) async {
    seedFourSessionProgressingLift(fakeRepo);

    await pumpInsights(tester);

    final ledger = find.byKey(const ValueKey('liftLedger'));
    expect(find.descendant(of: ledger, matching: find.text('62.5→72.5')), findsOneWidget);
  });

  testWidgets('the ledger shows the percent change for a progressing lift', (tester) async {
    seedFourSessionProgressingLift(fakeRepo);

    await pumpInsights(tester);

    final ledger = find.byKey(const ValueKey('liftLedger'));
    expect(find.descendant(of: ledger, matching: find.text('+16.0%')), findsOneWidget);
  });

  testWidgets('the verdict headline counts a single progressing lift', (tester) async {
    seedFourSessionProgressingLift(fakeRepo);

    await pumpInsights(tester);

    expect(find.textContaining('One of one lift is moving.'), findsOneWidget);
  });

  testWidgets('a bodyweight (reps-only) lift also appears in the ledger, not just weighted lifts', (tester) async {
    final start = DateTime.now().subtract(const Duration(days: 24));
    for (var i = 0; i < 4; i++) {
      fakeRepo.store['ws$i'] = _liftSession(
        id: 'ws$i',
        exerciseName: 'Pull-up',
        startedAt: start.add(Duration(days: i * 8)),
        weight: 0,
        reps: 6 + i,
      );
    }

    await pumpInsights(tester);

    expect(
      find.descendant(of: find.byKey(const ValueKey('liftLedger')), matching: find.text('Pull-up')),
      findsOneWidget,
    );
  });

  testWidgets('a lift with fewer than four sessions is excluded from the ledger', (tester) async {
    final start = DateTime.now().subtract(const Duration(days: 16));
    for (var i = 0; i < 3; i++) {
      fakeRepo.store['ws$i'] = _liftSession(
        id: 'ws$i',
        startedAt: start.add(Duration(days: i * 8)),
        weight: 60,
      );
    }

    await pumpInsights(tester);

    expect(
      find.descendant(of: find.byKey(const ValueKey('liftLedger')), matching: find.text('Bench Press')),
      findsNothing,
    );
  });

  testWidgets('switching the window to 6M reveals a lift whose sessions are older than 8 weeks', (tester) async {
    final start = DateTime.now().subtract(const Duration(days: 100));
    for (var i = 0; i < 4; i++) {
      fakeRepo.store['ws$i'] =
          _liftSession(id: 'ws$i', startedAt: start.add(Duration(days: i * 8)), weight: 60 + i * 5);
    }

    await pumpInsights(tester);
    expect(
      find.descendant(of: find.byKey(const ValueKey('liftLedger')), matching: find.text('Bench Press')),
      findsNothing,
    );

    await tester.tap(find.text('6M'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byKey(const ValueKey('liftLedger')), matching: find.text('Bench Press')),
      findsOneWidget,
    );
  });

  testWidgets("this week's sets card shows a category's working-set count and load band", (tester) async {
    final thisWeekStart = _mondayOf(DateTime.now());
    fakeRepo.store['ws-2'] = _categorySession(
      id: 'ws-2',
      startedAt: thisWeekStart.subtract(const Duration(days: 14, hours: -9)),
      category: 'Legs',
      setCount: 4,
    );
    fakeRepo.store['ws-1'] = _categorySession(
      id: 'ws-1',
      startedAt: thisWeekStart.subtract(const Duration(days: 7, hours: -9)),
      category: 'Legs',
      setCount: 4,
    );
    fakeRepo.store['ws-0'] = _categorySession(
      id: 'ws-0',
      startedAt: thisWeekStart.add(const Duration(days: 1, hours: 9)),
      category: 'Legs',
      setCount: 8,
    );

    await pumpInsights(tester);

    expect(find.textContaining('8 working sets'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('heavy'), findsOneWidget);
  });

  testWidgets("this week's sets header also shows this week's session count", (tester) async {
    final thisWeekStart = _mondayOf(DateTime.now());
    fakeRepo.store['ws-0'] = _categorySession(
      id: 'ws-0',
      startedAt: thisWeekStart.add(const Duration(days: 1, hours: 9)),
      category: 'Legs',
      setCount: 8,
    );

    await pumpInsights(tester);

    expect(find.textContaining('1 session ·'), findsOneWidget);
  });

  testWidgets('the All sessions row navigates to the full session list', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1');

    await pumpInsights(tester);

    // The row sits below the fold once Recent records is on screen, so it
    // isn't built yet — scroll it into the sliver's cache extent first.
    await tester.scrollUntilVisible(find.text('All sessions'), 300, scrollable: _outerScrollable);
    await tester.tap(find.text('All sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
  });

  testWidgets('shows a no-records message under Recent records when every set was skipped', (tester) async {
    fakeRepo.store['ws1'] = WorkoutSession(
      id: 'ws1',
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: DateTime(2026, 1, 5),
      endedAt: DateTime(2026, 1, 5, 1),
      completed: true,
      sets: [
        LoggedSet(
          exerciseName: 'Bench Press',
          targetReps: 8,
          targetWeight: 60,
          actualReps: 8,
          actualWeight: 60,
          skipped: true,
        ),
      ],
    );

    await pumpInsights(tester);

    expect(find.text('Recent records'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('No records yet'), findsOneWidget);
  });

  testWidgets('shows the top personal records under Recent records', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('Recent records'.toUpperCase()), findsOneWidget);
    expect(find.text('HEAVIEST WEIGHT'), findsOneWidget);
    expect(find.text('Bench Press'), findsWidgets);
  });

  testWidgets('See all navigates to the full records screen', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('Records'), findsOneWidget);
  });

  testWidgets(
      'switching to Running mode shows the weekly running stats, distance/pace charts, and a fastest-pace record',
      (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    final thisWeek = _mondayOf(DateTime.now());
    fakeRunRepo.store['r1'] = buildRunSession(
      id: 'r1',
      startedAt: thisWeek.add(const Duration(days: 1, hours: 7)),
    ); // 5km / 30min = 6:00/km, per buildRunSession's defaults

    await pumpInsights(tester);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(find.text('Distance over time'.toUpperCase()), findsOneWidget);
    expect(find.text('Pace trend'.toUpperCase()), findsOneWidget);
    expect(find.text('5.0'), findsWidgets); // distance: strip cell + distance card
    expect(find.text('6:00'), findsWidgets); // avg pace: strip cell + fastest-pace PR card
    expect(find.text('FASTEST PACE'), findsOneWidget);
  });

  testWidgets('Strength mode filters the fastest-pace record out of Recent records', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    expect(find.text('FASTEST PACE'), findsNothing);
  });

  testWidgets('shows a no-records message for Running when no runs are logged', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);

    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No records yet — log a run'), findsOneWidget);
  });

  testWidgets('no run-type selector shows when every logged run shares one type', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    fakeRunRepo.store['r1'] = buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5));

    await pumpInsights(tester);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(find.text('Easy'), findsNothing);
  });

  testWidgets('a run-type selector appears once more than one type is logged', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    fakeRunRepo.store['r1'] =
        buildRunSession(id: 'r1', startedAt: DateTime(2026, 1, 5)); // easy, per the fixture default
    fakeRunRepo.store['r2'] = RunSession(
      id: 'r2',
      startedAt: DateTime(2026, 1, 12, 7),
      endedAt: DateTime(2026, 1, 12, 7, 20),
      distanceMeters: 4000,
      runType: RunType.tempo,
    );

    await pumpInsights(tester);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Tempo'), findsOneWidget);
  });

  testWidgets('selecting a run type filters the pace trend to only that type\'s runs', (tester) async {
    fakeRepo.store['ws1'] = buildWorkoutSession(id: 'ws1', startedAt: DateTime(2026, 1, 5));
    final thisWeek = _mondayOf(DateTime.now());
    fakeRunRepo.store['r1'] = buildRunSession(
      id: 'r1',
      startedAt: thisWeek.add(const Duration(days: 1, hours: 7)),
    ); // easy, inside the 8-week window
    fakeRunRepo.store['r2'] = RunSession(
      id: 'r2',
      // Outside the 8-week window, so filtering to Tempo alone leaves the
      // pace trend with no data in range, unlike the unfiltered "All" view.
      startedAt: thisWeek.subtract(const Duration(days: 100)),
      endedAt: thisWeek.subtract(const Duration(days: 100)).add(const Duration(minutes: 20)),
      distanceMeters: 4000,
      runType: RunType.tempo,
    );

    await pumpInsights(tester);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs logged in the last 8 weeks.'), findsNothing);

    await tester.tap(find.text('Tempo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No runs logged in the last 8 weeks.'), findsOneWidget);
  });
}
