import '../models/mesocycle.dart';
import '../models/day_override.dart';

// ─── Date helpers ─────────────────────────────────────────────────────

DateTime mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1)); // Mon=1
}

DateTime normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

// ─── Phase derivation ─────────────────────────────────────────────────

// Computes the virtual "cycle-week-0 Monday" that is in effect for [date].
// Uses the latest CycleAdjustment whose effectiveDate <= date (or originalAnchor
// as the implicit phase-0 anchor if no adjustments apply).
//
// An adjustment's effectiveDate is the Monday it starts on.
// The virtual anchor = effectiveDate - (targetCycleWeekIndex * 7 days),
// i.e. the Monday that would be week-0 if we projected the cycle backwards.
DateTime _phaseAnchor(Mesocycle m, DateTime date) {
  final dateMonday = mondayOf(date);
  DateTime bestEff = m.originalAnchor;
  int bestIdx = 0;
  for (final a in m.adjustments) {
    if (!a.effectiveDate.isAfter(dateMonday) &&
        !a.effectiveDate.isBefore(bestEff)) {
      bestEff = a.effectiveDate;
      bestIdx = a.targetCycleWeekIndex ?? 0;
    }
  }
  return bestEff.subtract(Duration(days: bestIdx * 7));
}

// ─── Core schedule functions ──────────────────────────────────────────

// 0-based week index within one full cycle (length = trainingWeeks + restWeeks).
// Safe for dates before the anchor (floor-mod handles negatives).
int cycleWeekIndexForDate(Mesocycle m, DateTime date) {
  final len = m.trainingWeeks + m.restWeeks;
  final anchor = _phaseAnchor(m, date);
  final weeks = mondayOf(date).difference(anchor).inDays ~/ 7;
  return ((weeks % len) + len) % len;
}

bool isRestWeek(Mesocycle m, DateTime date) =>
    cycleWeekIndexForDate(m, date) >= m.trainingWeeks;

// ─── Status label ─────────────────────────────────────────────────────

class ScheduleStatus {
  final bool isTraining;
  final int weekOfBlock; // 1-based
  final int totalWeeks;

  const ScheduleStatus({
    required this.isTraining,
    required this.weekOfBlock,
    required this.totalWeeks,
  });

  String get label {
    if (isTraining) return 'WEEK $weekOfBlock OF $totalWeeks · TRAINING';
    if (totalWeeks == 1) return 'REST WEEK';
    return 'REST WEEK $weekOfBlock OF $totalWeeks';
  }
}

ScheduleStatus statusForDate(Mesocycle m, DateTime date) {
  final idx = cycleWeekIndexForDate(m, date);
  if (idx < m.trainingWeeks) {
    return ScheduleStatus(
      isTraining: true,
      weekOfBlock: idx + 1,
      totalWeeks: m.trainingWeeks,
    );
  } else {
    return ScheduleStatus(
      isTraining: false,
      weekOfBlock: idx - m.trainingWeeks + 1,
      totalWeeks: m.restWeeks,
    );
  }
}

// ─── Master derivation ────────────────────────────────────────────────

// Returns the workoutId for [date] or null (rest / no workout).
// Overrides win over the template; rest weeks suppress all weekday assignments.
String? workoutIdForDate(Mesocycle m, DayOverride? ov, DateTime date) {
  if (ov != null) {
    return ov.kind == OverrideKind.rest ? null : ov.workoutId;
  }
  if (isRestWeek(m, date)) return null;
  return m.weekdayWorkouts[date.weekday];
}

// ─── Adjustment helpers ───────────────────────────────────────────────

// Returns a CycleAdjustment that begins an early rest week starting this
// Monday (or the Monday of [today]'s week). Appending this to the meso
// causes the rest week to start immediately; after restWeeks pass, the
// floor-mod naturally rolls into training week-1 of the next cycle.
CycleAdjustment earlyRestAdjustment(Mesocycle m, DateTime today) {
  return CycleAdjustment(
    effectiveDate: mondayOf(today),
    type: AdjustmentType.earlyRest,
    targetCycleWeekIndex: m.trainingWeeks, // first rest week index
  );
}

// Returns a CycleAdjustment that sets the current week to [cycleWeekIndex]
// (0-based) starting from the Monday of [today]'s week.
CycleAdjustment setCurrentWeekAdjustment(DateTime today, int cycleWeekIndex) {
  return CycleAdjustment(
    effectiveDate: mondayOf(today),
    type: AdjustmentType.setCurrentWeek,
    targetCycleWeekIndex: cycleWeekIndex,
  );
}
