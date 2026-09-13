import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/format.dart';
import 'package:fitness_planner/domain/insights/insights_window.dart';
import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/domain/insights/running_trends.dart';
import 'package:fitness_planner/domain/insights/strength_progress.dart';
import 'package:fitness_planner/domain/insights/training_load.dart';
import 'package:fitness_planner/domain/insights/volume_stats.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/domain/schedule/schedule_logic.dart';
import 'package:fitness_planner/presentation/all_sessions_screen.dart';
import 'package:fitness_planner/presentation/lift_detail_screen.dart';
import 'package:fitness_planner/presentation/records_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart';
import 'package:fitness_planner/presentation/widgets/pr_card.dart';
import 'package:fitness_planner/providers/mesocycle_providers.dart';
import 'package:fitness_planner/providers/run_providers.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/theme/app_theme.dart';

// ─── Verdict copy ────────────────────────────────────────────────────────
//
// The hero states the finding as a sentence, not a bare number: how many
// tracked lifts are moving, and which ones aren't. See plan 022's "Design"
// section for why — a number with a small label is exactly what this tab
// replaces.

enum VerdictKind { progressing, allStalled, insufficientData }

class Verdict {
  final VerdictKind kind;
  final String headline;
  final String detail;

  const Verdict({required this.kind, required this.headline, required this.detail});
}

const _kNumberWords = [
  'zero', 'one', 'two', 'three', 'four', 'five',
  'six', 'seven', 'eight', 'nine', 'ten',
];

String _countWord(int n) => n >= 0 && n < _kNumberWords.length ? _kNumberWords[n] : n.toString();

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Joins [names] into a natural-language list: "A", "A and B", or
/// "A, B, and N more" beyond two — a hero sentence should stay a sentence,
/// not enumerate an entire ledger.
String _joinNames(List<String> names) {
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  return '${names[0]}, ${names[1]}, and ${names.length - 2} more';
}

/// The tab's hero finding: how many of [ranked]'s lifts are progressing, and
/// which ones aren't — regressing lifts are named ahead of merely-holding
/// ones, since a decline is more urgent to flag than a plateau.
Verdict computeVerdict(List<LiftProgress> ranked) {
  if (ranked.isEmpty) {
    return const Verdict(
      kind: VerdictKind.insufficientData,
      headline: 'Not enough data yet.',
      detail: "Log four sessions of a lift and it'll show up here.",
    );
  }

  final moving = ranked.where((l) => l.status == LiftStatus.progressing).toList();
  if (moving.isEmpty) {
    return const Verdict(
      kind: VerdictKind.allStalled,
      headline: 'Nothing has moved in six weeks.',
      detail: 'Your last few sessions repeated the same weights.',
    );
  }

  final regressing = ranked.where((l) => l.status == LiftStatus.regressing).toList();
  final holding = ranked.where((l) => l.status == LiftStatus.holding).toList();
  final total = ranked.length;

  final headline = '${_capitalize(_countWord(moving.length))} of ${_countWord(total)} '
      'lift${total == 1 ? '' : 's'} ${moving.length == 1 ? 'is' : 'are'} moving.';

  final String detail;
  if (regressing.isNotEmpty) {
    final names = _joinNames([for (final l in regressing) l.exerciseName]);
    detail = '$names ${regressing.length == 1 ? 'is' : 'are'} trending down.';
  } else if (holding.isNotEmpty) {
    final names = _joinNames([for (final l in holding) l.exerciseName]);
    detail = "$names ${holding.length == 1 ? "hasn't" : "haven't"} moved in six weeks.";
  } else {
    detail = 'Keep it up.';
  }

  return Verdict(kind: VerdictKind.progressing, headline: headline, detail: detail);
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

const _kWindowLabels = {
  InsightsWindow.eightWeeks: '8W',
  InsightsWindow.sixMonths: '6M',
  InsightsWindow.oneYear: '1Y',
  InsightsWindow.all: 'All',
};

InsightsWindow _windowForLabel(String label) =>
    _kWindowLabels.entries.firstWhere((e) => e.value == label).key;

String _windowCaption(InsightsWindow window) {
  switch (window) {
    case InsightsWindow.eightWeeks:
      return 'last 8 weeks';
    case InsightsWindow.sixMonths:
      return 'last 6 months';
    case InsightsWindow.oneYear:
      return 'last year';
    case InsightsWindow.all:
      return 'your full history';
  }
}

/// One current-week bucket plus enough trailing weeks to compare against —
/// "this week's sets" is always literally this week, independent of the
/// ledger's own window selector above it.
const int _kWeeklyLoadWeeks = 5;

/// Every ranked lift within [window], across all three [LiftMetric] kinds —
/// concatenated by metric (weighted, then bodyweight reps, then timed
/// holds) rather than interleaved by raw percent, since cross-normalising
/// percentages across metric kinds is misleading (plan 022: a 6→9 rep jump
/// reads as +50%, dwarfing a realistic e1RM gain). Restricting the ledger to
/// weighted lifts only would silently drop bodyweight/timed-hold exercises
/// from progression tracking entirely.
///
/// The window's cutoff is the earliest Monday in the same
/// [weekBucketStarts] list used to build [excludedWeekStarts] below — not a
/// raw day-count subtraction from [now]. Those two must share one week-start
/// list, or a session dated in the few days between a raw cutoff and the
/// nearest Monday can silently escape deload-week exclusion, since its week
/// would never appear in the exclusion set at all.
List<DateTime> _bucketStartsFor(InsightsWindow window, List<DateTime> sessionDates, DateTime now) {
  final resolvedWeeks = resolveWeeks(window, sessionDates, now);
  return weekBucketStarts(weeks: resolvedWeeks, now: now);
}

/// The earliest Monday-aligned week-start within [window] — the same cutoff
/// [rankedLiftsForWindow] slices lift series to. Exposed separately so a
/// lift detail screen can mark where the tab's currently selected window
/// begins on a lift's full, unwindowed history chart.
DateTime windowStartFor(InsightsWindow window, List<DateTime> sessionDates, DateTime now) =>
    _bucketStartsFor(window, sessionDates, now).first;

List<LiftProgress> rankedLiftsForWindow(
  Map<String, LiftSeries> fullSeries, {
  required InsightsWindow window,
  required List<DateTime> sessionDates,
  required Mesocycle? mesocycle,
  required DateTime now,
}) {
  final bucketStarts = _bucketStartsFor(window, sessionDates, now);
  final cutoff = bucketStarts.first;

  final windowedSeries = {
    for (final entry in fullSeries.entries)
      entry.key: LiftSeries(
        points: [
          for (final p in entry.value.points)
            if (!p.date.isBefore(cutoff)) p,
        ],
        excludedHighRepSessions: entry.value.excludedHighRepSessions,
      ),
  };

  final excludedWeekStarts = mesocycle == null
      ? const <DateTime>{}
      : {
          for (final w in bucketStarts)
            if (isRestWeek(mesocycle, w)) w,
        };

  return [
    for (final metric in LiftMetric.values)
      ...rankedLifts(windowedSeries, only: metric, now: now, excludedWeekStarts: excludedWeekStarts),
  ];
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  // Null until the user explicitly taps a mode: resolved to 'Running' when
  // there's nothing but run data to show (a lifter with zero runs sees
  // 'Strength' the same way), so a user with no logged workout sessions
  // doesn't land on an all-zero Strength view by default.
  String? _mode;
  InsightsWindow _window = InsightsWindow.eightWeeks;

  // Memoized on the sessions and runs lists' identity: `sessionsProvider`
  // and `runsProvider` hand back the same List instance across rebuilds
  // until their data actually changes, so a mode/window toggle (which only
  // changes local state) can reuse the cached derived data instead of
  // re-scanning every session/run on every tap.
  List<WorkoutSession>? _cachedSessions;
  List<RunSession>? _cachedRuns;
  List<WeekRunStats>? _cachedWeeklyRunStats;
  DateTime? _cachedRunWeekStart;
  List<PersonalRecord>? _cachedRecords;
  Map<String, LiftSeries>? _cachedAllLiftSeries;
  List<WeekLoad>? _cachedWeekLoads;
  DateTime? _cachedWeekLoadsWeekStart;
  List<LiftProgress>? _cachedRanked;
  InsightsWindow? _cachedRankedWindow;
  DateTime? _cachedRankedDay;
  Mesocycle? _cachedRankedMeso;

  void _sync(List<WorkoutSession> sessions, List<RunSession> runs) {
    if (!identical(_cachedSessions, sessions)) {
      _cachedSessions = sessions;
      _cachedRecords = null;
      _cachedAllLiftSeries = null;
      _cachedWeekLoads = null;
      _cachedRanked = null;
    }
    if (!identical(_cachedRuns, runs)) {
      _cachedRuns = runs;
      _cachedWeeklyRunStats = null;
      _cachedRecords = null;
    }
  }

  List<PersonalRecord> _recordsFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    return _cachedRecords ??= computePersonalRecords(sessions, runs);
  }

  List<WeekRunStats> _weeklyRunStatsFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    final weekStart = weekStartOf(DateTime.now());
    if (_cachedWeeklyRunStats == null || _cachedRunWeekStart != weekStart) {
      _cachedWeeklyRunStats = weeklyRunStats(runs);
      _cachedRunWeekStart = weekStart;
    }
    return _cachedWeeklyRunStats!;
  }

  /// Every lift's full logged history, one pass — the window selector then
  /// slices these already-computed points rather than re-scanning sessions
  /// per window change.
  Map<String, LiftSeries> _allLiftSeriesFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    return _cachedAllLiftSeries ??= allLiftSeries(sessions);
  }

  /// Keyed on the calendar day (not just sessions/window/mesocycle) so a
  /// kept-alive screen re-resolves an `all`-window's day count once the
  /// real date rolls over, mirroring [_weekLoadsFor]'s week-rollover key.
  List<LiftProgress> _rankedLiftsFor(
    List<WorkoutSession> sessions,
    List<RunSession> runs,
    Mesocycle? mesocycle,
  ) {
    _sync(sessions, runs);
    final now = DateTime.now();
    final dayKey = DateTime(now.year, now.month, now.day);
    if (_cachedRanked == null ||
        _cachedRankedWindow != _window ||
        _cachedRankedDay != dayKey ||
        _cachedRankedMeso != mesocycle) {
      _cachedRanked = rankedLiftsForWindow(
        _allLiftSeriesFor(sessions, runs),
        window: _window,
        sessionDates: [for (final s in sessions) s.startedAt],
        mesocycle: mesocycle,
        now: now,
      );
      _cachedRankedWindow = _window;
      _cachedRankedDay = dayKey;
      _cachedRankedMeso = mesocycle;
    }
    return _cachedRanked!;
  }

  List<WeekLoad> _weekLoadsFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    final weekStart = weekStartOf(DateTime.now());
    if (_cachedWeekLoads == null || _cachedWeekLoadsWeekStart != weekStart) {
      _cachedWeekLoads = weeklyTrainingLoad(sessions, weeks: _kWeeklyLoadWeeks);
      _cachedWeekLoadsWeekStart = weekStart;
    }
    return _cachedWeekLoads!;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final runs = ref.watch(runsProvider).asData?.value ?? const <RunSession>[];
    final meso = ref.watch(activeMesocycleProvider);
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeaderBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insights',
                    style: displayStyle(
                      fontSize: kTextHeadline,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -1.2,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sessionsAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: c.accent)),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: bodyStyle(color: c.danger))),
                data: (sessions) {
                  if (sessions.isEmpty && runs.isEmpty) return const _EmptyState();

                  final runWeeks = _weeklyRunStatsFor(sessions, runs);
                  final records = _recordsFor(sessions, runs);
                  final mode = _mode ?? (sessions.isEmpty && runs.isNotEmpty ? 'Running' : 'Strength');

                  final ranked = _rankedLiftsFor(sessions, runs, meso);

                  final weekLoads = _weekLoadsFor(sessions, runs);
                  final comparisons = compareToTrailing(weekLoads)
                    ..sort((a, b) => b.workingSets.compareTo(a.workingSets));

                  return _Body(
                    sessionCount: sessions.length,
                    records: records,
                    mode: mode,
                    onSelectMode: (mode) => setState(() => _mode = mode),
                    runWeeks: runWeeks,
                    window: _window,
                    onSelectWindow: (w) => setState(() => _window = w),
                    rankedLifts: ranked,
                    weeklyLoad: comparisons,
                    thisWeekSessionCount: weekLoads.last.sessionCount,
                    totalWorkingSets: weekLoads.last.totalWorkingSets,
                    onTapLift: (lift) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiftDetailScreen(
                          exerciseName: lift.exerciseName,
                          progress: lift,
                          series: _allLiftSeriesFor(sessions, runs)[lift.exerciseName]!,
                          windowStart: windowStartFor(
                            _window,
                            [for (final s in sessions) s.startedAt],
                            DateTime.now(),
                          ),
                          setsBySessionId: _setsForExercise(sessions, lift.exerciseName),
                          records: _recordsForExercise(records, lift.exerciseName),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final int sessionCount;
  final List<PersonalRecord> records;
  final String mode;
  final ValueChanged<String> onSelectMode;
  final List<WeekRunStats> runWeeks;
  final InsightsWindow window;
  final ValueChanged<InsightsWindow> onSelectWindow;
  final List<LiftProgress> rankedLifts;
  final List<CategoryLoadComparison> weeklyLoad;
  final int thisWeekSessionCount;
  final int totalWorkingSets;
  final ValueChanged<LiftProgress> onTapLift;

  const _Body({
    required this.sessionCount,
    required this.records,
    required this.mode,
    required this.onSelectMode,
    required this.runWeeks,
    required this.window,
    required this.onSelectWindow,
    required this.rankedLifts,
    required this.weeklyLoad,
    required this.thisWeekSessionCount,
    required this.totalWorkingSets,
    required this.onTapLift,
  });

  @override
  Widget build(BuildContext context) {
    final running = mode == 'Running';
    // weeklyRunStats() always returns at least one bucket (default 8
    // weeks), even for empty input, so this is never empty.
    final thisRunWeek = runWeeks.last;
    final recordsForMode = records
        .where((r) => (r.type == PersonalRecordType.fastestPace) == running)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        SegmentedControl(
          options: const ['Strength', 'Running'],
          value: mode,
          onChanged: onSelectMode,
        ),
        const SizedBox(height: 22),
        if (running) ...[
          const _SectionLabel('This week'),
          const SizedBox(height: 10),
          _RunThisWeekStrip(week: thisRunWeek),
        ] else ...[
          SegmentedControl(
            options: _kWindowLabels.values.toList(),
            value: _kWindowLabels[window]!,
            onChanged: (label) => onSelectWindow(_windowForLabel(label)),
            small: true,
          ),
          const SizedBox(height: 22),
          _VerdictSection(verdict: computeVerdict(rankedLifts), window: window),
          const SizedBox(height: 22),
          const _SectionLabel('Lift ledger'),
          const SizedBox(height: 10),
          _LiftLedger(key: const ValueKey('liftLedger'), lifts: rankedLifts, onTapLift: onTapLift),
          const SizedBox(height: 22),
          _SectionLabel(
            "This week's sets",
            trailingText: '$thisWeekSessionCount session${thisWeekSessionCount == 1 ? '' : 's'} · '
                '${fmtCount(totalWorkingSets)} working set${totalWorkingSets == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 10),
          _WeeklySetsCard(comparisons: weeklyLoad),
        ],
        const SizedBox(height: 22),
        _SectionLabel(
          'Recent records',
          action: recordsForMode.isEmpty
              ? null
              : ('See all', () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecordsScreen()),
                  )),
        ),
        const SizedBox(height: 10),
        if (recordsForMode.isEmpty)
          Text(
            running
                ? 'No records yet — log a run to start setting personal bests.'
                : 'No records yet — log a set to start setting personal bests.',
            style: bodyStyle(fontSize: 13, color: AppThemeData.of(context).c.inkMute),
          )
        else
          Column(
            children: [
              for (final record in recordsForMode.take(2)) ...[
                PRCard(record: record),
                const SizedBox(height: 10),
              ],
            ],
          ),
        if (running) ...[
          const SizedBox(height: 22),
          const _SectionLabel('Distance over time'),
          const SizedBox(height: 10),
          _DistanceCard(weeks: runWeeks),
          const SizedBox(height: 22),
          const _SectionLabel('Pace trend'),
          const SizedBox(height: 10),
          _PaceTrendCard(weeks: runWeeks),
        ],
        const SizedBox(height: 22),
        _RowLink(
          icon: Icons.history_rounded,
          label: 'All sessions',
          sub: '$sessionCount logged session${sessionCount == 1 ? '' : 's'}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllSessionsScreen()),
          ),
        ),
      ],
    );
  }
}

class _VerdictSection extends StatelessWidget {
  final Verdict verdict;
  final InsightsWindow window;

  const _VerdictSection({required this.verdict, required this.window});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${verdict.headline}\n${verdict.detail}',
          style: displayStyle(
            fontSize: 21,
            fontWeight: FontWeight.w500,
            color: c.ink,
            letterSpacing: -0.4,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Estimated 1RM, top three sets averaged, ${_windowCaption(window)}.',
          style: bodyStyle(fontSize: 12, color: c.inkDim, height: 1.4),
        ),
      ],
    );
  }
}

// ─── Lift ledger ─────────────────────────────────────────────────────────
//
// A dumbbell plot: one row per ranked lift, a dot at the shared zero line
// and a dot at its percent change over the window, joined by a bar — a long
// bar reads as moving, a bare dot reads as stuck, without a legend. Per plan
// 022's design section, colour never encodes direction (a bar left of zero
// is a loss, right is a gain) and accent is reserved for the "now" endpoint
// only, so the bar and the start dot stay neutral.

/// The [PersonalRecordType]s that belong to a single exercise (as opposed to
/// `sessionTonnage`'s workout-name label or `fastestPace`'s running-only
/// one) — used to filter the records list down to one lift's own records
/// for its detail screen.
const _kPerExerciseRecordTypes = {
  PersonalRecordType.heaviestWeight,
  PersonalRecordType.mostReps,
  PersonalRecordType.longestHold,
  PersonalRecordType.bestEst1Rm,
};

List<PersonalRecord> _recordsForExercise(List<PersonalRecord> records, String exerciseName) => [
      for (final r in records)
        if (_kPerExerciseRecordTypes.contains(r.type) && r.label == exerciseName) r,
    ];

/// One pass over [sessions] collecting every non-skipped set logged for
/// [exerciseName], keyed by session id — the lift detail screen's "sets
/// behind this point" panel. Built lazily on tap rather than memoized
/// per-exercise up front, since only one lift's sets are ever needed at a
/// time.
Map<String, List<LoggedSet>> _setsForExercise(List<WorkoutSession> sessions, String exerciseName) {
  final result = <String, List<LoggedSet>>{};
  for (final session in sessions) {
    final sets = [
      for (final s in session.sets)
        if (!s.skipped && s.exerciseName == exerciseName) s,
    ];
    if (sets.isNotEmpty) result[session.id] = sets;
  }
  return result;
}

const double _kLedgerNameWidth = 86;
const double _kLedgerValueWidth = 82;
const double _kLedgerPercentWidth = 52;
const double _kLedgerRowHeight = 22;

String _ledgerPercentLabel(LiftProgress lift) {
  if (lift.status == LiftStatus.holding) return 'held';
  final delta = lift.percentDelta ?? 0;
  final sign = delta >= 0 ? '+' : '';
  return '$sign${delta.toStringAsFixed(1)}%';
}

/// A unit suffix for the ledger's value column — weighted lifts stay bare
/// (matching the plan's mockup), but a bodyweight/timed-hold lift now shares
/// the same ledger, so its numbers need a unit to disambiguate from a kg
/// figure.
String _ledgerValueSuffix(LiftMetric metric) {
  switch (metric) {
    case LiftMetric.weighted:
      return '';
    case LiftMetric.repsPerSet:
      return ' reps';
    case LiftMetric.holdSeconds:
      return 's';
  }
}

/// Pixel x of a percent value on the ledger's shared axis: inset from the
/// left edge just far enough to fit [maxLossAbs] on a single px-per-percent
/// scale shared with the gain side (sized to [scaleMax]) — "inset to leave
/// room for losses", per plan. `percent: 0` gives the shared zero line.
double _ledgerXFor(double percent, double plotWidth, double scaleMax, double maxLossAbs) =>
    fractionOfRange(percent, -maxLossAbs, scaleMax) * plotWidth;

class _LiftLedger extends StatelessWidget {
  final List<LiftProgress> lifts;
  final ValueChanged<LiftProgress> onTapLift;

  const _LiftLedger({super.key, required this.lifts, required this.onTapLift});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    if (lifts.isEmpty) {
      return Text(
        "Log four sessions of a lift and it'll show up here.",
        style: bodyStyle(fontSize: 13, color: c.inkMute),
      );
    }

    final maxGain = lifts.fold<double>(0, (m, l) => math.max(m, l.percentDelta ?? 0.0));
    final maxLossAbs = lifts.fold<double>(0, (m, l) => math.max(m, -math.min(0.0, l.percentDelta ?? 0.0)));
    final scale = computeNiceScale(0, maxGain <= 0 ? 1.0 : maxGain, targetTicks: 3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
        boxShadow: cardShadow(theme.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: _kLedgerNameWidth + _kLedgerValueWidth),
              Expanded(
                child: SizedBox(
                  height: 14,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final plotWidth = constraints.maxWidth;
                      return Stack(
                        children: [
                          for (final tick in scale.ticks)
                            Positioned(
                              left: (_ledgerXFor(tick, plotWidth, scale.max, maxLossAbs) - 14)
                                  .clamp(0.0, math.max(0.0, plotWidth - 28)),
                              child: Text(
                                tick == 0 ? '0%' : '+${tick.round()}%',
                                style: bodyStyle(fontSize: 10, color: c.inkMute),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: _kLedgerPercentWidth),
            ],
          ),
          for (final lift in lifts)
            GestureDetector(
              onTap: () => onTapLift(lift),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: _kLedgerNameWidth,
                      child: Text(
                        lift.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
                      ),
                    ),
                    SizedBox(
                      width: _kLedgerValueWidth,
                      child: Text(
                        '${fmtTrimmedNumber(lift.startValue)}→${fmtTrimmedNumber(lift.currentValue)}'
                        '${_ledgerValueSuffix(lift.metric)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle(fontSize: 11, color: c.inkDim),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: _kLedgerRowHeight,
                        child: CustomPaint(
                          painter: _DumbbellRowPainter(
                            percentDelta: lift.percentDelta ?? 0,
                            scaleMax: scale.max,
                            maxLossAbs: maxLossAbs,
                            barColor: c.inkDim,
                            nowColor: c.accent,
                            startColor: c.inkMute,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _kLedgerPercentWidth,
                      child: Text(
                        _ledgerPercentLabel(lift),
                        textAlign: TextAlign.end,
                        style: bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkDim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DumbbellRowPainter extends CustomPainter {
  final double percentDelta;
  final double scaleMax;
  final double maxLossAbs;
  final Color barColor;
  final Color nowColor;
  final Color startColor;

  const _DumbbellRowPainter({
    required this.percentDelta,
    required this.scaleMax,
    required this.maxLossAbs,
    required this.barColor,
    required this.nowColor,
    required this.startColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final span = scaleMax + maxLossAbs;
    final pxPerPercent = span == 0 ? 0.0 : size.width / span;
    final zeroX = maxLossAbs * pxPerPercent;
    final nowX = zeroX + percentDelta * pxPerPercent;
    final midY = size.height / 2;

    canvas.drawLine(
      Offset(zeroX, midY),
      Offset(nowX, midY),
      Paint()
        ..color = barColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(zeroX, midY), 3, Paint()..color = startColor);
    canvas.drawCircle(Offset(nowX, midY), 4.5, Paint()..color = nowColor);
  }

  @override
  bool shouldRepaint(covariant _DumbbellRowPainter oldDelegate) =>
      oldDelegate.percentDelta != percentDelta ||
      oldDelegate.scaleMax != scaleMax ||
      oldDelegate.maxLossAbs != maxLossAbs ||
      oldDelegate.barColor != barColor ||
      oldDelegate.nowColor != nowColor ||
      oldDelegate.startColor != startColor;
}

// ─── Weekly sets by muscle group ─────────────────────────────────────────
//
// Replaces raw tonnage/reps: a working set counts the same whether it's 20
// heavy squats or 20 bicep curls, which is the actual complaint plan 022
// fixes ("100 bicep curls... is not more difficult... than 20 bicep curls
// and 20 heavy squats"). The tick mark is the trailing 4-week average, so
// "light or heavy this week" is answerable without doing the arithmetic.

String _bandLabel(LoadBand band) {
  switch (band) {
    case LoadBand.light:
      return 'light';
    case LoadBand.typical:
      return 'typical';
    case LoadBand.heavy:
      return 'heavy';
    case LoadBand.unknown:
      return '';
  }
}

class _WeeklySetsCard extends StatelessWidget {
  final List<CategoryLoadComparison> comparisons;

  const _WeeklySetsCard({required this.comparisons});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    if (comparisons.isEmpty) {
      return Text('No sets logged this week.', style: bodyStyle(fontSize: 13, color: c.inkMute));
    }

    final axisMax = comparisons.fold<double>(
      1,
      (m, x) => math.max(m, math.max(x.workingSets.toDouble(), x.trailingMean ?? 0.0) * 1.15),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
        boxShadow: cardShadow(theme.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final comp in comparisons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      comp.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final barWidth = (comp.workingSets / axisMax * w).clamp(0.0, w);
                        final tickX = comp.trailingMean == null
                            ? null
                            : (comp.trailingMean! / axisMax * w).clamp(0.0, w);
                        return SizedBox(
                          height: 14,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 3,
                                bottom: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 3,
                                bottom: 3,
                                width: barWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              if (tickX != null)
                                Positioned(
                                  left: (tickX - 0.5).clamp(0.0, math.max(0.0, w - 1)),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(width: 1, color: c.ink),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${comp.workingSets}',
                      textAlign: TextAlign.end,
                      style: bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      _bandLabel(comp.band),
                      textAlign: TextAlign.end,
                      style: bodyStyle(fontSize: 11, color: c.inkMute),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            "One working set is one set you performed. Warm-ups and timed holds aren't counted.",
            style: bodyStyle(fontSize: 11, color: c.inkDim, height: 1.5),
          ),
        ],
      ),
    );
  }
}

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatShortDate(DateTime dt) => '${_kShortMonths[dt.month - 1]} ${dt.day}';

String fmtCount(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Clock-style pace, e.g. "4:52"; "--:--" when there's no distance behind
/// the pace to show one for (an empty week, or a zero-distance run).
String fmtPace(double? secPerKm) => secPerKm == null ? '--:--' : formatClock(secPerKm.round());

class _RunThisWeekStrip extends StatelessWidget {
  final WeekRunStats week;

  const _RunThisWeekStrip({required this.week});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
        boxShadow: cardShadow(theme.isDark),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: StatChip(
                value: week.distanceKm.toStringAsFixed(1),
                unit: 'km',
                label: 'distance',
              ),
            ),
            Expanded(
              child: StatChip(value: '${week.runCount}', label: 'runs', leftBorder: true),
            ),
            Expanded(
              child: StatChip(
                value: fmtPace(week.avgPaceSecPerKm),
                label: 'avg pace',
                leftBorder: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final List<WeekRunStats> weeks;

  const _DistanceCard({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    final series = [for (final w in weeks) w.distanceKm];
    final change = percentChange(series.last, series.first);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
        boxShadow: cardShadow(theme.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                series.last.toStringAsFixed(1),
                style: displayStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 3),
              Text('km', style: bodyStyle(fontSize: 14, color: c.inkDim)),
              if (change != null) ...[
                const SizedBox(width: 8),
                Icon(
                  change >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 13,
                  color: c.accent,
                ),
                Text(
                  '${change.abs().round()}%',
                  style: bodyStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.accent,
                  ),
                ),
              ],
              const Spacer(),
              Text('vs 8w ago', style: bodyStyle(fontSize: 12, color: c.inkMute)),
            ],
          ),
          const SizedBox(height: 8),
          AreaTrendChart(
            series: series,
            pointLabels: [for (final w in weeks) _formatShortDate(w.weekStart)],
            unitLabel: 'km',
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final (String, VoidCallback)? action;
  final String? trailingText;
  const _SectionLabel(this.label, {this.action, this.trailingText});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final labelText = Text(
      label.toUpperCase(),
      style: bodyStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.inkMute,
        letterSpacing: 0.9,
      ),
    );
    if (action == null && trailingText == null) return labelText;

    final Widget trailing;
    if (trailingText != null) {
      trailing = Text(trailingText!, style: bodyStyle(fontSize: 12, color: c.inkMute));
    } else {
      final (actionLabel, onTap) = action!;
      trailing = GestureDetector(
        onTap: onTap,
        child: Text(
          actionLabel,
          style: bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [labelText, trailing],
    );
  }
}

class _PaceTrendCard extends StatelessWidget {
  final List<WeekRunStats> weeks;

  const _PaceTrendCard({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    // Weeks with no runs carry no pace — plotting them as 0 would read as
    // an impossibly fast week on an inverted (lower-is-better) axis, so
    // they're dropped rather than zero-filled like the distance chart.
    final withPace = [for (final w in weeks) if (w.avgPaceSecPerKm != null) w];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
        boxShadow: cardShadow(theme.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average pace',
            style: displayStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text('Lower is faster · min/km', style: bodyStyle(fontSize: 12, color: c.inkDim)),
          const SizedBox(height: 12),
          if (withPace.isEmpty)
            Text(
              'No runs logged in the last 8 weeks.',
              style: bodyStyle(fontSize: 13, color: c.inkMute),
            )
          else
            AreaTrendChart(
              series: [for (final w in withPace) w.avgPaceSecPerKm!],
              pointLabels: [for (final w in withPace) _formatShortDate(w.weekStart)],
              invert: true,
              valueFormatter: (v) => formatClock(v.round()),
              unitLabel: 'min/km',
            ),
        ],
      ),
    );
  }
}

class _RowLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _RowLink({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(kRadius),
          border: theme.isDark ? Border.all(color: c.hairlineSoft) : null,
          boxShadow: cardShadow(theme.isDark),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(
                    (kRadius - 8).clamp(8.0, double.infinity)),
              ),
              child: Icon(icon, size: 20, color: c.inkDim),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: displayStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: bodyStyle(fontSize: 12, color: c.inkDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: c.inkMute),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1.5),
            ),
            child: Icon(Icons.insights_rounded, size: 28, color: c.inkMute),
          ),
          const SizedBox(height: 18),
          Text(
            'No sessions yet',
            style: displayStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: c.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a workout to see your progress here.',
            style: bodyStyle(fontSize: 14, color: c.inkDim, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
