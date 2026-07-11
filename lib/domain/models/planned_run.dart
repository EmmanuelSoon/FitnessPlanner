import 'run_session.dart';

/// A planned run target attached to a mesocycle weekday (or a per-date
/// override). Nested inside Mesocycle / RunOverride JSON — it has no Hive
/// adapter of its own. Distance and duration are both optional.
class PlannedRun {
  final RunType type;
  final double? targetDistanceMeters;
  final Duration? targetDuration;

  const PlannedRun({
    required this.type,
    this.targetDistanceMeters,
    this.targetDuration,
  });

  double? get targetDistanceKm =>
      targetDistanceMeters == null ? null : targetDistanceMeters! / 1000;

  /// e.g. "Easy · 5.0 km · 30 min" — omits any part that isn't set.
  String get summaryLabel {
    final parts = <String>[_typeLabel];
    final km = targetDistanceKm;
    if (km != null) parts.add('${km.toStringAsFixed(km % 1 == 0 ? 0 : 1)} km');
    final d = targetDuration;
    if (d != null) parts.add('${d.inMinutes} min');
    return parts.join(' · ');
  }

  String get _typeLabel {
    switch (type) {
      case RunType.easy:
        return 'Easy';
      case RunType.tempo:
        return 'Tempo';
      case RunType.interval:
        return 'Interval';
      case RunType.long:
        return 'Long';
      case RunType.race:
        return 'Race';
      case RunType.other:
        return 'Run';
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (targetDistanceMeters != null)
          'targetDistanceMeters': targetDistanceMeters,
        if (targetDuration != null)
          'targetDurationMicroseconds': targetDuration!.inMicroseconds,
      };

  factory PlannedRun.fromJson(Map<String, dynamic> json) => PlannedRun(
        type: RunType.values.byName(json['type'] as String),
        targetDistanceMeters: (json['targetDistanceMeters'] as num?)?.toDouble(),
        targetDuration: json['targetDurationMicroseconds'] != null
            ? Duration(microseconds: json['targetDurationMicroseconds'] as int)
            : null,
      );
}
