import 'package:flutter/material.dart';
import '../../domain/models/mesocycle.dart';
import '../../domain/models/day_override.dart';
import '../../domain/models/planned_run.dart';
import '../../domain/models/run_session.dart';
import '../../domain/schedule/schedule_logic.dart';
import '../../theme/app_theme.dart';

class MonthGrid extends StatelessWidget {
  final DateTime month; // year + month; day is ignored
  final DateTime today;
  final Mesocycle? meso;
  final DayOverride? Function(DateTime) overrideForDate;
  final Map<String, String> workoutNames; // workoutId -> display name
  /// Resolves the planned run for a date (template + override, rest-week aware).
  final PlannedRun? Function(DateTime) plannedRunForDate;
  /// Runs keyed by 'yyyy-M-d' (same format as CalendarScreen._dateKey).
  final Map<String, List<RunSession>> runsByDay;
  final void Function(DateTime date, String? workoutId, String? workoutName) onDayTap;

  const MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.meso,
    required this.overrideForDate,
    required this.workoutNames,
    required this.plannedRunForDate,
    this.runsByDay = const {},
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final isDark = AppThemeData.of(context).isDark;

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first: Mon=1 so leading blanks = weekday - 1
    final leadingBlanks = firstDay.weekday - 1;
    // Always 42 cells (6 rows × 7 cols) for a consistent, non-jumping height
    final paddedCells = List<DateTime?>.generate(42, (i) {
      final dayIdx = i - leadingBlanks + 1;
      if (dayIdx < 1 || dayIdx > daysInMonth) return null;
      return DateTime(month.year, month.month, dayIdx);
    });

    return Column(
      children: [
        // Weekday header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: bodyStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9AA49B), // inkMute-ish
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        // Day grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.82,
              mainAxisSpacing: 4,
              crossAxisSpacing: 2,
            ),
            itemCount: 42,
            itemBuilder: (context, i) {
              final date = paddedCells[i];
              if (date == null) return const SizedBox.shrink();
              final dayKey =
                  '${date.year}-${date.month}-${date.day}';
              return _DayCell(
                date: date,
                today: today,
                meso: meso,
                overrideForDate: overrideForDate,
                workoutNames: workoutNames,
                plannedRun: plannedRunForDate(date),
                runsForDay: runsByDay[dayKey] ?? const [],
                isDark: isDark,
                c: c,
                onTap: onDayTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final Mesocycle? meso;
  final DayOverride? Function(DateTime) overrideForDate;
  final Map<String, String> workoutNames;
  final PlannedRun? plannedRun;
  final List<RunSession> runsForDay;
  final bool isDark;
  final AppColors c;
  final void Function(DateTime, String?, String?) onTap;

  const _DayCell({
    required this.date,
    required this.today,
    required this.meso,
    required this.overrideForDate,
    required this.workoutNames,
    required this.plannedRun,
    required this.runsForDay,
    required this.isDark,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    String? workoutId;
    String? workoutName;
    bool isRest = false;

    if (meso != null) {
      final ov = overrideForDate(date);
      workoutId = workoutIdForDate(meso!, ov, date);
      workoutName = workoutId != null ? (workoutNames[workoutId] ?? workoutId) : null;
      isRest = isRestWeek(meso!, date);
    }

    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
    final hasWorkout = workoutId != null;

    Color cellBg;
    Color dayNumColor;

    if (isToday) {
      cellBg = c.accent;
      dayNumColor = c.accentInk;
    } else if (isRest && meso != null) {
      cellBg = Colors.transparent;
      dayNumColor = c.inkMute;
    } else {
      cellBg = hasWorkout ? c.surface : Colors.transparent;
      dayNumColor = isPast ? c.inkMute : c.ink;
    }

    return GestureDetector(
      onTap: () => onTap(date, workoutId, workoutName),
      child: Container(
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(10),
          border: (!isToday && hasWorkout)
              ? Border.all(
                  color: isDark ? c.hairlineSoft : c.hairline,
                  width: 0.5,
                )
              : null,
          boxShadow: (!isToday && hasWorkout && !isDark)
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: monoStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                color: dayNumColor,
              ),
            ),
            if (hasWorkout) ...[
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? c.accentInk.withValues(alpha: 0.7) : c.accent,
                ),
              ),
              const SizedBox(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  workoutName ?? '',
                  style: bodyStyle(
                    fontSize: 8,
                    color: isToday ? c.accentInk.withValues(alpha: 0.85) : c.inkDim,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            // Run indicators — a logged run shows a solid shoe; a planned run
            // that hasn't been logged yet shows a dimmer shoe (target).
            if (runsForDay.isNotEmpty) ...[
              const SizedBox(height: 2),
              Icon(
                Icons.directions_run_rounded,
                size: 8,
                color: isToday
                    ? c.accentInk.withValues(alpha: 0.7)
                    : c.inkDim,
              ),
            ] else if (plannedRun != null) ...[
              const SizedBox(height: 2),
              Icon(
                Icons.directions_run_rounded,
                size: 8,
                color: isToday
                    ? c.accentInk.withValues(alpha: 0.5)
                    : c.inkMute,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
