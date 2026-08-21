import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/logged_set.dart';
import 'package:fitness_planner/presentation/widgets/number_picker_sheet.dart';
import 'package:fitness_planner/theme/app_theme.dart';

// ─── Per-exercise workout summary ─────────────────────────────────────────
//
// Groups a session's logged sets by exercise and renders one line per
// exercise showing what was actually done — shared by the workout-complete
// screen and the calendar's day-tap summary.

class _ExerciseBreakdown {
  final String name;
  final List<LoggedSet> sets;
  const _ExerciseBreakdown(this.name, this.sets);
}

List<_ExerciseBreakdown> _groupByExercise(List<LoggedSet> sets) {
  final order = <String>[];
  final map = <String, List<LoggedSet>>{};
  for (final s in sets) {
    map.putIfAbsent(s.exerciseName, () {
      order.add(s.exerciseName);
      return [];
    }).add(s);
  }
  return [for (final n in order) _ExerciseBreakdown(n, map[n]!)];
}

String _setLine(LoggedSet s) => s.heldSeconds != null
    ? '${s.heldSeconds}s'
    : '${s.actualReps}×${fmtWeight(s.actualWeight)}kg';

class SessionBreakdown extends StatelessWidget {
  final List<LoggedSet> sets;
  const SessionBreakdown({super.key, required this.sets});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final groups = _groupByExercise(sets);

    if (groups.isEmpty) {
      return Text(
        'No sets logged.',
        style: bodyStyle(fontSize: 14, color: c.inkMute),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _ExerciseSummaryTile(group: group, c: c),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ExerciseSummaryTile extends StatelessWidget {
  final _ExerciseBreakdown group;
  final AppColors c;
  const _ExerciseSummaryTile({required this.group, required this.c});

  @override
  Widget build(BuildContext context) {
    final performed = group.sets.where((s) => !s.skipped).toList();
    final skippedCount = group.sets.length - performed.length;

    final line = performed.isEmpty
        ? 'Skipped'
        : '${performed.length} ${performed.length == 1 ? 'set' : 'sets'} · '
            '${performed.map(_setLine).join(', ')}'
            '${skippedCount > 0 ? '  ($skippedCount skipped)' : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: c.hairlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: bodyStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line,
            style: bodyStyle(fontSize: 12, color: c.inkDim),
          ),
        ],
      ),
    );
  }
}
