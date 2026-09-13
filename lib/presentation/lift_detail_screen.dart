import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/domain/insights/strength_progress.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart';
import 'package:fitness_planner/presentation/widgets/pr_card.dart';
import 'package:fitness_planner/theme/app_theme.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatShortDate(DateTime dt) => '${_kShortMonths[dt.month - 1]} ${dt.day}';

String _formatLongDate(DateTime dt) => '${_kShortMonths[dt.month - 1]} ${dt.day}, ${dt.year}';

String? _unitLabel(LiftMetric metric) {
  switch (metric) {
    case LiftMetric.weighted:
      return null;
    case LiftMetric.repsPerSet:
      return 'reps';
    case LiftMetric.holdSeconds:
      return 'sec';
  }
}

/// One session's sets for a lift, formatted as identical consecutive sets
/// grouped ("3×8 @ 60kg") rather than listed one by one — the day's actual
/// work is the point, not a longer string.
String _formatSetsLine(List<LoggedSet> sets, LiftMetric metric) {
  final descriptors = [
    for (final s in sets)
      switch (metric) {
        LiftMetric.weighted => '${s.actualReps} @ ${fmtTrimmedNumber(s.actualWeight)}kg',
        LiftMetric.repsPerSet => '${s.actualReps} reps',
        LiftMetric.holdSeconds => '${s.heldSeconds ?? 0}s',
      },
  ];
  final groups = <String>[];
  var i = 0;
  while (i < descriptors.length) {
    var j = i;
    while (j < descriptors.length && descriptors[j] == descriptors[i]) {
      j++;
    }
    final count = j - i;
    groups.add(count > 1 ? '$count×${descriptors[i]}' : descriptors[i]);
    i = j;
  }
  return groups.join(', ');
}

/// The index of the first point on or after [target], or the last point if
/// every point predates it — used to mark where the tab's currently
/// selected window begins on this lift's full, unwindowed history.
int _nearestIndexOnOrAfter(List<LiftSessionPoint> points, DateTime target) {
  final idx = points.indexWhere((p) => !p.date.isBefore(target));
  return idx == -1 ? points.length - 1 : idx;
}

/// The index of [points]' true all-time best session (by [LiftSessionPoint.best],
/// the heaviest/highest single set, ties keeping the earliest) — computed
/// directly from the full chart series rather than [LiftProgress.bestDate],
/// which only ever considers the tab's currently selected window and can
/// miss an earlier peak the full-history chart still plots.
int _trueBestIndex(List<LiftSessionPoint> points) {
  var bestIdx = 0;
  for (var i = 1; i < points.length; i++) {
    if (points[i].best > points[bestIdx].best) bestIdx = i;
  }
  return bestIdx;
}

/// A single lift's full history: current value and delta, the full-axis
/// trend chart (with a marker for where the Insights tab's selected window
/// begins), the sets behind whichever point is selected, and that lift's
/// records. Reached by tapping a row in the Insights tab's ledger.
class LiftDetailScreen extends StatefulWidget {
  final String exerciseName;
  final LiftProgress progress;
  final LiftSeries series;
  final DateTime windowStart;
  final Map<String, List<LoggedSet>> setsBySessionId;
  final List<PersonalRecord> records;

  LiftDetailScreen({
    super.key,
    required this.exerciseName,
    required this.progress,
    required this.series,
    required this.windowStart,
    required this.setsBySessionId,
    required this.records,
  }) : assert(
         series.points.isNotEmpty,
         'LiftDetailScreen requires at least one session point to select and chart',
       );

  @override
  State<LiftDetailScreen> createState() => _LiftDetailScreenState();
}

class _LiftDetailScreenState extends State<LiftDetailScreen> {
  late int _selectedIndex = widget.series.points.length - 1;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final points = widget.series.points;
    final selectedPoint = points[_selectedIndex];
    final selectedSets = widget.setsBySessionId[selectedPoint.sessionId] ?? const <LoggedSet>[];

    final markerIndex = _nearestIndexOnOrAfter(points, widget.windowStart);
    final bestIndex = _trueBestIndex(points);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                children: [
                  Text(
                    widget.exerciseName,
                    style: displayStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${fmtTrimmedNumber(widget.progress.currentValue)}${liftValueSuffix(widget.progress.metric)}',
                        style: displayStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        liftPercentLabel(widget.progress),
                        style: bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated 1RM, top three sets averaged.',
                    style: bodyStyle(fontSize: 12, color: c.inkDim),
                  ),
                  const SizedBox(height: 16),
                  AreaTrendChart(
                    series: [for (final p in points) p.value],
                    pointLabels: [for (final p in points) _formatShortDate(p.date)],
                    prIndices: bestIndex >= 0 ? {bestIndex} : const {},
                    markerIndex: markerIndex,
                    unitLabel: _unitLabel(widget.progress.metric),
                    onTouchIndex: (i) => setState(() => _selectedIndex = i),
                  ),
                  if (widget.series.excludedHighRepSessions > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.series.excludedHighRepSessions} session'
                      '${widget.series.excludedHighRepSessions == 1 ? '' : 's'} not shown — '
                      'too many reps for a reliable estimate.',
                      style: bodyStyle(fontSize: 11, color: c.inkDim, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _SectionLabel('Session', color: c.inkMute),
                  const SizedBox(height: 8),
                  _SessionSetsCard(
                    point: selectedPoint,
                    sets: selectedSets,
                    metric: widget.progress.metric,
                  ),
                  if (widget.records.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _SectionLabel('Records', color: c.inkMute),
                    const SizedBox(height: 8),
                    for (final record in widget.records) ...[
                      PRCard(record: record),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel(this.label, {required this.color});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: bodyStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.9),
      );
}

class _SessionSetsCard extends StatelessWidget {
  final LiftSessionPoint point;
  final List<LoggedSet> sets;
  final LiftMetric metric;

  const _SessionSetsCard({required this.point, required this.sets, required this.metric});

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
          Text(
            _formatLongDate(point.date),
            style: displayStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink, letterSpacing: -0.2),
          ),
          const SizedBox(height: 6),
          Text(
            sets.isEmpty ? 'No sets logged.' : _formatSetsLine(sets, metric),
            style: bodyStyle(fontSize: 13, color: c.inkDim, height: 1.4),
          ),
        ],
      ),
    );
  }
}
