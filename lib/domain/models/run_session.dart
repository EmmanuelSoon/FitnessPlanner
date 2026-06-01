enum RunType { easy, tempo, interval, long, race, other }

enum RunSource { manual, healthConnect }

class RunSession {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int? avgHeartRate;
  final double? calories;
  final int? cadenceSpm;
  final RunType runType;
  final String? notes;
  final RunSource source;

  /// Health Connect record UUID — used to skip already-imported runs.
  final String? externalId;

  RunSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    this.avgHeartRate,
    this.calories,
    this.cadenceSpm,
    this.runType = RunType.other,
    this.notes,
    this.source = RunSource.manual,
    this.externalId,
  });

  // ─── Derived ────────────────────────────────────────────────────────

  Duration get duration => endedAt.difference(startedAt);

  double get distanceKm => distanceMeters / 1000;

  /// Returns null when distance is zero (prevents divide-by-zero).
  Duration? get pacePerKm {
    if (distanceMeters <= 0) return null;
    final secondsPerKm = duration.inSeconds / (distanceMeters / 1000);
    return Duration(seconds: secondsPerKm.round());
  }

  /// Human-readable pace string, e.g. "5:17".
  String get formattedPace {
    final p = pacePerKm;
    if (p == null) return '--:--';
    final m = p.inMinutes;
    final s = p.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ─── Serialisation ──────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceMeters': distanceMeters,
        if (avgHeartRate != null) 'avgHeartRate': avgHeartRate,
        if (calories != null) 'calories': calories,
        if (cadenceSpm != null) 'cadenceSpm': cadenceSpm,
        'runType': runType.name,
        if (notes != null) 'notes': notes,
        'source': source.name,
        if (externalId != null) 'externalId': externalId,
      };

  factory RunSession.fromJson(Map<String, dynamic> json) => RunSession(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        avgHeartRate: json['avgHeartRate'] as int?,
        calories: (json['calories'] as num?)?.toDouble(),
        cadenceSpm: json['cadenceSpm'] as int?,
        runType: json['runType'] != null
            ? RunType.values.byName(json['runType'] as String)
            : RunType.other,
        notes: json['notes'] as String?,
        source: json['source'] != null
            ? RunSource.values.byName(json['source'] as String)
            : RunSource.manual,
        externalId: json['externalId'] as String?,
      );
}
