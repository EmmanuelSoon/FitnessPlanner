enum AdjustmentType { earlyRest, setCurrentWeek }

class CycleAdjustment {
  final DateTime effectiveDate; // normalized to Monday 00:00 of the week it takes effect
  final AdjustmentType type;
  final int? targetCycleWeekIndex; // 0-based week within a full cycle

  const CycleAdjustment({
    required this.effectiveDate,
    required this.type,
    this.targetCycleWeekIndex,
  });

  Map<String, dynamic> toJson() => {
    'effectiveDate': effectiveDate.toIso8601String(),
    'type': type.name,
    if (targetCycleWeekIndex != null) 'targetCycleWeekIndex': targetCycleWeekIndex,
  };

  factory CycleAdjustment.fromJson(Map<String, dynamic> json) => CycleAdjustment(
    effectiveDate: DateTime.parse(json['effectiveDate'] as String),
    type: AdjustmentType.values.byName(json['type'] as String),
    targetCycleWeekIndex: json['targetCycleWeekIndex'] as int?,
  );
}

class Mesocycle {
  final String id;
  final String name;
  final int trainingWeeks;
  final int restWeeks;

  // IMMUTABLE after creation. Normalized to Monday 00:00 local of cycle-1 week-1.
  // Never mutate this — use adjustments instead.
  final DateTime originalAnchor;

  // 1=Mon .. 7=Sun -> workoutId (null = rest day).
  // Same workoutId may appear on multiple days.
  final Map<int, String?> weekdayWorkouts;

  // Append-only event log for early-rest / set-current-week.
  // Sorted by effectiveDate ascending.
  final List<CycleAdjustment> adjustments;

  const Mesocycle({
    required this.id,
    required this.name,
    required this.trainingWeeks,
    required this.restWeeks,
    required this.originalAnchor,
    required this.weekdayWorkouts,
    this.adjustments = const [],
  });

  Mesocycle copyWith({
    String? id,
    String? name,
    int? trainingWeeks,
    int? restWeeks,
    DateTime? originalAnchor,
    Map<int, String?>? weekdayWorkouts,
    List<CycleAdjustment>? adjustments,
  }) =>
      Mesocycle(
        id: id ?? this.id,
        name: name ?? this.name,
        trainingWeeks: trainingWeeks ?? this.trainingWeeks,
        restWeeks: restWeeks ?? this.restWeeks,
        originalAnchor: originalAnchor ?? this.originalAnchor,
        weekdayWorkouts: weekdayWorkouts ?? this.weekdayWorkouts,
        adjustments: adjustments ?? this.adjustments,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trainingWeeks': trainingWeeks,
    'restWeeks': restWeeks,
    'originalAnchor': originalAnchor.toIso8601String(),
    'weekdayWorkouts': {
      for (final e in weekdayWorkouts.entries) e.key.toString(): e.value,
    },
    'adjustments': adjustments.map((a) => a.toJson()).toList(),
  };

  factory Mesocycle.fromJson(Map<String, dynamic> json) => Mesocycle(
    id: json['id'] as String,
    name: json['name'] as String,
    trainingWeeks: json['trainingWeeks'] as int,
    restWeeks: json['restWeeks'] as int,
    originalAnchor: DateTime.parse(json['originalAnchor'] as String),
    weekdayWorkouts: {
      for (final e in (json['weekdayWorkouts'] as Map<String, dynamic>).entries)
        int.parse(e.key): e.value as String?,
    },
    adjustments: (json['adjustments'] as List? ?? [])
        .map((a) => CycleAdjustment.fromJson(a as Map<String, dynamic>))
        .toList(),
  );
}
