import 'planned_run.dart';

enum RunOverrideKind { setRun, clearRun }

/// Per-date override for a planned run, parallel to [DayOverride] for workouts.
class RunOverride {
  final String mesocycleId;
  final DateTime date; // normalized to 00:00 local
  final RunOverrideKind kind;
  final PlannedRun? plannedRun; // required when kind == setRun

  const RunOverride({
    required this.mesocycleId,
    required this.date,
    required this.kind,
    this.plannedRun,
  });

  Map<String, dynamic> toJson() => {
        'mesocycleId': mesocycleId,
        'date': date.toIso8601String(),
        'kind': kind.name,
        if (plannedRun != null) 'plannedRun': plannedRun!.toJson(),
      };

  factory RunOverride.fromJson(Map<String, dynamic> json) => RunOverride(
        mesocycleId: json['mesocycleId'] as String,
        date: DateTime.parse(json['date'] as String),
        kind: RunOverrideKind.values.byName(json['kind'] as String),
        plannedRun: json['plannedRun'] != null
            ? PlannedRun.fromJson(json['plannedRun'] as Map<String, dynamic>)
            : null,
      );
}
