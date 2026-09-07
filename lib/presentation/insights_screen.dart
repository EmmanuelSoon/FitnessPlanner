import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/format.dart';
import 'package:fitness_planner/domain/insights/exercise_trend.dart';
import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/domain/insights/running_trends.dart';
import 'package:fitness_planner/domain/insights/volume_stats.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/all_sessions_screen.dart';
import 'package:fitness_planner/presentation/records_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart';
import 'package:fitness_planner/presentation/widgets/pr_card.dart';
import 'package:fitness_planner/providers/run_providers.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String? _selectedExercise;
  String _volumeMetric = 'Tonnage';
  // Null until the user explicitly taps a mode: resolved to 'Running' when
  // there's nothing but run data to show (a lifter with zero runs sees
  // 'Strength' the same way), so a user with no logged workout sessions
  // doesn't land on an all-zero Strength view by default.
  String? _mode;

  // Memoized on the sessions and runs lists' identity: `sessionsProvider`
  // and `runsProvider` hand back the same List instance across rebuilds
  // until their data actually changes, so a chip tap or mode toggle (which
  // only changes local state) can reuse the cached derived data instead of
  // re-scanning every session/run on every tap.
  List<WorkoutSession>? _cachedSessions;
  List<RunSession>? _cachedRuns;
  List<String> _cachedNames = const [];
  final Map<String, List<ExerciseTrendPoint>> _trendCache = {};
  List<WeekVolume>? _cachedWeeklyVolume;
  DateTime? _cachedWeekStart;
  List<WeekRunStats>? _cachedWeeklyRunStats;
  DateTime? _cachedRunWeekStart;
  List<PersonalRecord>? _cachedRecords;

  void _sync(List<WorkoutSession> sessions, List<RunSession> runs) {
    if (!identical(_cachedSessions, sessions)) {
      _cachedSessions = sessions;
      _cachedNames = exerciseNamesLogged(sessions);
      _trendCache.clear();
      _cachedWeeklyVolume = null;
      _cachedRecords = null;
    }
    if (!identical(_cachedRuns, runs)) {
      _cachedRuns = runs;
      _cachedWeeklyRunStats = null;
      _cachedRecords = null;
    }
  }

  List<String> _namesFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    return _cachedNames;
  }

  List<PersonalRecord> _recordsFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    return _cachedRecords ??= computePersonalRecords(sessions, runs);
  }

  List<ExerciseTrendPoint> _trendFor(
    List<WorkoutSession> sessions,
    List<RunSession> runs,
    String exercise,
  ) {
    _sync(sessions, runs);
    return _trendCache.putIfAbsent(exercise, () => computeExerciseTrend(sessions, exercise));
  }

  List<WeekVolume> _weeklyVolumeFor(List<WorkoutSession> sessions, List<RunSession> runs) {
    _sync(sessions, runs);
    // Keyed on the current week's start too, not just the sessions list —
    // this screen can be kept alive (e.g. in a bottom-nav IndexedStack)
    // across a real week boundary with no session change, and a
    // sessions-only key would otherwise keep serving "This week" figures
    // for the week that just ended.
    final weekStart = weekStartOf(DateTime.now());
    if (_cachedWeeklyVolume == null || _cachedWeekStart != weekStart) {
      _cachedWeeklyVolume = weeklyVolume(sessions);
      _cachedWeekStart = weekStart;
    }
    return _cachedWeeklyVolume!;
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

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final runs = ref.watch(runsProvider).asData?.value ?? const <RunSession>[];
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

                  final names = _namesFor(sessions, runs);
                  // Fall back to the most recently logged exercise if
                  // nothing's selected yet, or if the previously selected
                  // one no longer appears (e.g. its only session was
                  // deleted) — an unreconciled stale selection would
                  // otherwise show no chip selected and an empty trend.
                  final exercise = (_selectedExercise != null &&
                          names.contains(_selectedExercise))
                      ? _selectedExercise!
                      : (names.isEmpty ? null : names.first);
                  final trend = exercise == null
                      ? const <ExerciseTrendPoint>[]
                      : _trendFor(sessions, runs, exercise);
                  final weeks = _weeklyVolumeFor(sessions, runs);
                  final runWeeks = _weeklyRunStatsFor(sessions, runs);
                  final records = _recordsFor(sessions, runs);
                  final mode = _mode ?? (sessions.isEmpty && runs.isNotEmpty ? 'Running' : 'Strength');

                  return _Body(
                    sessionCount: sessions.length,
                    names: names,
                    selected: exercise,
                    trend: trend,
                    onSelectExercise: (name) =>
                        setState(() => _selectedExercise = name),
                    weeks: weeks,
                    volumeMetric: _volumeMetric,
                    onSelectVolumeMetric: (metric) =>
                        setState(() => _volumeMetric = metric),
                    records: records,
                    mode: mode,
                    onSelectMode: (mode) => setState(() => _mode = mode),
                    runWeeks: runWeeks,
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
  final List<String> names;
  final String? selected;
  final List<ExerciseTrendPoint> trend;
  final ValueChanged<String> onSelectExercise;
  final List<WeekVolume> weeks;
  final String volumeMetric;
  final ValueChanged<String> onSelectVolumeMetric;
  final List<PersonalRecord> records;
  final String mode;
  final ValueChanged<String> onSelectMode;
  final List<WeekRunStats> runWeeks;

  const _Body({
    required this.sessionCount,
    required this.names,
    required this.selected,
    required this.trend,
    required this.onSelectExercise,
    required this.weeks,
    required this.volumeMetric,
    required this.onSelectVolumeMetric,
    required this.records,
    required this.mode,
    required this.onSelectMode,
    required this.runWeeks,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final running = mode == 'Running';
    // weeklyVolume()/weeklyRunStats() always return at least one bucket
    // (default 8 weeks), even for empty input, so these are never empty.
    final thisWeek = weeks.last;
    final thisRunWeek = runWeeks.last;
    final recordsForMode = records
        .where((r) => (r.type == PersonalRecordType.fastestPace) == running)
        .toList();

    return ListView(
      key: const ValueKey('insightsScrollView'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        SegmentedControl(
          options: const ['Strength', 'Running'],
          value: mode,
          onChanged: onSelectMode,
        ),
        const SizedBox(height: 22),
        const _SectionLabel('This week'),
        const SizedBox(height: 10),
        running ? _RunThisWeekStrip(week: thisRunWeek) : _ThisWeekStrip(week: thisWeek),
        if (!running) ...[
          const SizedBox(height: 8),
          Text(
            'Tonnage counts weighted sets only. Reps count everything, '
            'weighted and bodyweight — the two are never added together.',
            style: bodyStyle(fontSize: 11, color: c.inkDim, height: 1.5),
          ),
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
            style: bodyStyle(fontSize: 13, color: c.inkMute),
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
        const SizedBox(height: 22),
        _SectionLabel(running ? 'Distance over time' : 'Volume over time'),
        const SizedBox(height: 10),
        running
            ? _DistanceCard(weeks: runWeeks)
            : _VolumeCard(
                weeks: weeks,
                metric: volumeMetric,
                onSelectMetric: onSelectVolumeMetric,
              ),
        const SizedBox(height: 22),
        _SectionLabel(running ? 'Pace trend' : 'Exercise trend'),
        const SizedBox(height: 10),
        running
            ? _PaceTrendCard(weeks: runWeeks)
            : _ExerciseTrendCard(
                names: names,
                selected: selected,
                onSelect: onSelectExercise,
                trend: trend,
              ),
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

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatShortDate(DateTime dt) => '${_kShortMonths[dt.month - 1]} ${dt.day}';

String fmtTonnage(double kg) => (kg / 1000).toStringAsFixed(1);

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

class _ThisWeekStrip extends StatelessWidget {
  final WeekVolume week;

  const _ThisWeekStrip({required this.week});

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
              child: StatChip(value: '${week.sessionCount}', label: 'sessions'),
            ),
            Expanded(
              child: StatChip(
                value: fmtTonnage(week.tonnageKg),
                unit: 't',
                label: 'tonnage',
                leftBorder: true,
              ),
            ),
            Expanded(
              child: StatChip(
                value: fmtCount(week.repVolume),
                label: 'reps',
                leftBorder: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _VolumeCard extends StatelessWidget {
  final List<WeekVolume> weeks;
  final String metric;
  final ValueChanged<String> onSelectMetric;

  const _VolumeCard({
    required this.weeks,
    required this.metric,
    required this.onSelectMetric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final isTonnage = metric == 'Tonnage';

    final series = [
      for (final w in weeks) isTonnage ? w.tonnageKg / 1000 : w.repVolume.toDouble(),
    ];
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
          SegmentedControl(
            options: const ['Tonnage', 'Reps'],
            value: metric,
            onChanged: onSelectMetric,
            small: true,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isTonnage
                    ? series.last.toStringAsFixed(1)
                    : fmtCount(series.last.round()),
                style: displayStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                isTonnage ? 't' : 'reps',
                style: bodyStyle(fontSize: 14, color: c.inkDim),
              ),
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
            edgeLabels: [
              _formatShortDate(weeks.first.weekStart),
              _formatShortDate(weeks.last.weekStart),
            ],
            pointLabels: [for (final w in weeks) _formatShortDate(w.weekStart)],
          ),
        ],
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
            edgeLabels: [
              _formatShortDate(weeks.first.weekStart),
              _formatShortDate(weeks.last.weekStart),
            ],
            pointLabels: [for (final w in weeks) _formatShortDate(w.weekStart)],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final (String, VoidCallback)? action;
  const _SectionLabel(this.label, {this.action});

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
    if (action == null) return labelText;

    final (actionLabel, onTap) = action!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        labelText,
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: bodyStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
          ),
        ),
      ],
    );
  }
}

class _ExerciseTrendCard extends StatelessWidget {
  final List<String> names;
  final String? selected;
  final ValueChanged<String> onSelect;
  final List<ExerciseTrendPoint> trend;

  const _ExerciseTrendCard({
    required this.names,
    required this.selected,
    required this.onSelect,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;

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
          SizedBox(
            height: 34,
            child: ListView.separated(
              key: const ValueKey('exerciseChipRow'),
              scrollDirection: Axis.horizontal,
              itemCount: names.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final name = names[i];
                return _ExerciseChip(
                  label: name,
                  selected: name == selected,
                  onTap: () => onSelect(name),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (trend.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No performed sets logged for this exercise yet.',
                style: bodyStyle(fontSize: 13, color: c.inkMute),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmtTrimmedNumber(trend.last.value),
                  key: const ValueKey('exerciseTrendCurrentValue'),
                  style: displayStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  trend.last.unit,
                  style: bodyStyle(fontSize: 14, color: c.inkDim),
                ),
                const Spacer(),
                Text(
                  '${trend.last.metricLabel} · ${trend.length} session${trend.length == 1 ? '' : 's'}',
                  style: bodyStyle(fontSize: 12, color: c.inkMute),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AreaTrendChart(
              series: [for (final p in trend) p.value],
              edgeLabels: [
                _formatShortDate(trend.first.date),
                _formatShortDate(trend.last.date),
              ],
              pointLabels: [for (final p in trend) _formatShortDate(p.date)],
            ),
          ],
        ],
      ),
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
              edgeLabels: [
                _formatShortDate(withPace.first.weekStart),
                _formatShortDate(withPace.last.weekStart),
              ],
              pointLabels: [for (final w in withPace) _formatShortDate(w.weekStart)],
              invert: true,
            ),
        ],
      ),
    );
  }
}

class _ExerciseChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExerciseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: selected ? null : Border.all(color: c.hairline),
        ),
        child: Text(
          label,
          style: bodyStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? c.accentInk : c.inkDim,
          ),
        ),
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
