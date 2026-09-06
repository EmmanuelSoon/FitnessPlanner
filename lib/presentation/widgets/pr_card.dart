import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/insights/personal_records.dart';
import 'package:fitness_planner/presentation/widgets/insights_charts.dart' show fmtTrimmedNumber;
import 'package:fitness_planner/theme/app_theme.dart';

/// One personal-best row: icon, kind + exercise (or workout, for session
/// tonnage), "when · delta on previous best", and the record's value. Used
/// on both the Insights tab's "Recent records" section and the full
/// records list screen.
class PRCard extends StatelessWidget {
  final PersonalRecord record;
  final DateTime? now;

  const PRCard({super.key, required this.record, this.now});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final c = theme.c;
    final (value, unit) = _formatValue(record);
    final delta = _formatDelta(record);
    final subtitle = delta == null
        ? _formatRelativeTime(record.achievedAt, now: now)
        : '${_formatRelativeTime(record.achievedAt, now: now)} · $delta on previous best';

    return Container(
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
              color: c.accent,
              borderRadius:
                  BorderRadius.circular((kRadius - 8).clamp(8.0, double.infinity)),
            ),
            child: Icon(Icons.emoji_events_rounded, size: 20, color: c.accentInk),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kindLabel(record.type).toUpperCase(),
                  style: bodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: c.inkMute,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: bodyStyle(fontSize: 12, color: c.inkDim)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: displayStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(unit, style: bodyStyle(fontSize: 10, color: c.inkMute)),
            ],
          ),
        ],
      ),
    );
  }
}

String _kindLabel(PersonalRecordType type) => switch (type) {
      PersonalRecordType.heaviestWeight => 'Heaviest weight',
      PersonalRecordType.mostReps => 'Most reps',
      PersonalRecordType.longestHold => 'Longest hold',
      PersonalRecordType.bestEst1Rm => 'Best est. 1RM',
      PersonalRecordType.sessionTonnage => 'Session volume',
    };

(String, String) _formatValue(PersonalRecord r) => switch (r.type) {
      PersonalRecordType.heaviestWeight => (
          fmtTrimmedNumber(r.value),
          'kg × ${r.reps}',
        ),
      PersonalRecordType.mostReps => (r.value.round().toString(), 'reps @ BW'),
      PersonalRecordType.longestHold => (_fmtClock(r.value.round()), 'hold'),
      PersonalRecordType.bestEst1Rm => (r.value.round().toString(), 'kg e1RM'),
      PersonalRecordType.sessionTonnage => (
          (r.value / 1000).toStringAsFixed(1),
          't lifted',
        ),
    };

String? _formatDelta(PersonalRecord r) {
  final previous = r.previousValue;
  if (previous == null) return null;
  final diff = r.value - previous;
  return switch (r.type) {
    PersonalRecordType.heaviestWeight => '+${fmtTrimmedNumber(diff)} kg',
    PersonalRecordType.mostReps =>
      '+${diff.round()} rep${diff.round() == 1 ? '' : 's'}',
    PersonalRecordType.longestHold => '+${diff.round()} s',
    PersonalRecordType.bestEst1Rm => '+${diff.round()} kg',
    PersonalRecordType.sessionTonnage => '+${(diff / 1000).toStringAsFixed(1)} t',
  };
}

String _fmtClock(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Coarse relative-time label ("Today", "3d ago", "2w ago", "4mo ago",
/// "1y ago"), rounded down to whole calendar days against [now] (defaults
/// to [DateTime.now]).
String _formatRelativeTime(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
  if (days <= 0) return 'Today';
  if (days < 7) return '${days}d ago';
  final weeks = days ~/ 7;
  if (weeks < 5) return '${weeks}w ago';
  final months = days ~/ 30;
  if (months < 12) return '${months}mo ago';
  final years = days ~/ 365;
  return '${years}y ago';
}
