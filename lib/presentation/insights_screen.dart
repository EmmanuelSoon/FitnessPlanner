import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/domain/insights/exercise_trend.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';
import 'package:fitness_planner/presentation/all_sessions_screen.dart';
import 'package:fitness_planner/presentation/widgets/app_widgets.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart';
import 'package:fitness_planner/providers/session_providers.dart';
import 'package:fitness_planner/theme/app_theme.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
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
                data: (sessions) =>
                    sessions.isEmpty ? const _EmptyState() : _Body(
                      sessions: sessions,
                      selectedExercise: _selectedExercise,
                      onSelectExercise: (name) =>
                          setState(() => _selectedExercise = name),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final String? selectedExercise;
  final ValueChanged<String> onSelectExercise;

  const _Body({
    required this.sessions,
    required this.selectedExercise,
    required this.onSelectExercise,
  });

  @override
  Widget build(BuildContext context) {
    final names = exerciseNamesLogged(sessions);
    final exercise = selectedExercise ?? (names.isEmpty ? null : names.first);
    final trend =
        exercise == null ? const <ExerciseTrendPoint>[] : computeExerciseTrend(sessions, exercise);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionLabel('Exercise trend'),
        const SizedBox(height: 10),
        _ExerciseTrendCard(
          names: names,
          selected: exercise,
          onSelect: onSelectExercise,
          trend: trend,
        ),
        const SizedBox(height: 22),
        _RowLink(
          icon: Icons.history_rounded,
          label: 'All sessions',
          sub: '${sessions.length} logged session${sessions.length == 1 ? '' : 's'}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllSessionsScreen()),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return Text(
      label.toUpperCase(),
      style: bodyStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.inkMute,
        letterSpacing: 0.9,
      ),
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

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in names)
                _ExerciseChip(
                  label: name,
                  selected: name == selected,
                  onTap: () => onSelect(name),
                ),
            ],
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
                  _fmtValue(trend.last.value),
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
                _formatDate(trend.first.date),
                _formatDate(trend.last.date),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtValue(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
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
