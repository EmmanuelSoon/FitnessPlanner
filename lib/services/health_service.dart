import 'package:health/health.dart';
import '../domain/models/run_session.dart';

/// Wraps the Health Connect (Android) integration via the `health` package.
///
/// Only READ permissions are requested — this app never writes health data.
/// All failures are surfaced as [HealthServiceException] so callers can show
/// appropriate messages and fall back to manual entry.
class HealthServiceException implements Exception {
  final String message;
  const HealthServiceException(this.message);
  @override
  String toString() => message;
}

class HealthService {
  HealthService._();
  static final instance = HealthService._();

  // Data types we need for a running workout.
  static const _types = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.STEPS,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await Health().configure();
    _configured = true;
  }

  /// Requests READ permissions for run-related health data.
  /// Returns true if all permissions were granted.
  Future<bool> requestAuthorization() async {
    await _ensureConfigured();
    try {
      return await Health().requestAuthorization(
        _types,
        permissions: _permissions,
      );
    } catch (e) {
      throw HealthServiceException('Could not request Health Connect permissions: $e');
    }
  }

  /// Checks whether Health Connect READ permissions are already granted
  /// without showing a permission prompt.
  Future<bool> hasPermissions() async {
    await _ensureConfigured();
    try {
      return await Health().hasPermissions(_types, permissions: _permissions) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches RUNNING workouts recorded on Health Connect since [since].
  ///
  /// For each workout the method also reads heart rate, active calories, and
  /// steps within the same time window to populate the [RunSession] fields.
  ///
  /// Throws [HealthServiceException] when Health Connect is unavailable or
  /// the request fails — callers should catch and show a user-facing message.
  Future<List<RunSession>> fetchRuns({required DateTime since}) async {
    await _ensureConfigured();

    // Verify we have permission before querying.
    final granted = await hasPermissions();
    if (!granted) {
      final ok = await requestAuthorization();
      if (!ok) {
        throw const HealthServiceException(
          'Health Connect permission was not granted. '
          'Please allow access in Health Connect settings.',
        );
      }
    }

    final now = DateTime.now();

    // --- Fetch workouts ---
    List<HealthDataPoint> workoutPoints;
    try {
      workoutPoints = await Health().getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: since,
        endTime: now,
      );
    } catch (e) {
      throw HealthServiceException('Failed to read workouts from Health Connect: $e');
    }

    // Filter to RUNNING activity type only.
    final runningPoints = workoutPoints.where((p) {
      if (p.value is! WorkoutHealthValue) return false;
      return (p.value as WorkoutHealthValue).workoutActivityType ==
          HealthWorkoutActivityType.RUNNING;
    }).toList();

    if (runningPoints.isEmpty) return [];

    // Determine the overall time window so we can fetch HR/steps in one call.
    final windowStart = runningPoints
        .map((p) => p.dateFrom)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final windowEnd = runningPoints
        .map((p) => p.dateTo)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // --- Fetch supporting metrics for the full window ---
    List<HealthDataPoint> hrPoints = [];
    List<HealthDataPoint> stepPoints = [];
    List<HealthDataPoint> caloriePoints = [];

    try {
      final results = await Future.wait([
        Health().getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: windowStart,
          endTime: windowEnd,
        ),
        Health().getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: windowStart,
          endTime: windowEnd,
        ),
        Health().getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: windowStart,
          endTime: windowEnd,
        ),
      ]);
      hrPoints = results[0];
      stepPoints = results[1];
      caloriePoints = results[2];
    } catch (_) {
      // Supporting metrics are best-effort; continue without them.
    }

    // --- Map each running workout to a RunSession ---
    final sessions = <RunSession>[];

    for (final point in runningPoints) {
      final workoutValue = point.value as WorkoutHealthValue;
      final start = point.dateFrom;
      final end = point.dateTo;

      // Use the platform UUID for dedup; fall back to start+end timestamp.
      final externalId = point.uuid.isNotEmpty
          ? point.uuid
          : '${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';
      final runId = 'hc_$externalId';

      // Distance — prefer the workout-level value; fall back to zero.
      // WorkoutHealthValue.totalDistance is in metres on Android Health Connect.
      final distanceMeters =
          (workoutValue.totalDistance?.toDouble() ?? 0.0).abs();

      // Calories — prefer workout-level; fall back to summing active-energy points.
      double? cal = workoutValue.totalEnergyBurned?.toDouble();
      if (cal == null) {
        final inWindow = caloriePoints
            .where((p) => !p.dateFrom.isBefore(start) && !p.dateTo.isAfter(end));
        if (inWindow.isNotEmpty) {
          cal = inWindow.fold<double>(
            0.0,
            (sum, p) => sum + ((p.value as NumericHealthValue).numericValue.toDouble()),
          );
        }
      }

      // Avg heart rate — average of samples within the workout window.
      int? avgHr;
      final hrInWindow = hrPoints
          .where((p) => !p.dateFrom.isBefore(start) && !p.dateTo.isAfter(end))
          .toList();
      if (hrInWindow.isNotEmpty) {
        final sum = hrInWindow.fold<double>(
          0.0,
          (s, p) => s + ((p.value as NumericHealthValue).numericValue.toDouble()),
        );
        avgHr = (sum / hrInWindow.length).round();
      }

      // Cadence (steps per minute) — approximate from step count.
      int? cadence;
      final stepsInWindow = stepPoints
          .where((p) => !p.dateFrom.isBefore(start) && !p.dateTo.isAfter(end))
          .toList();
      if (stepsInWindow.isNotEmpty) {
        final totalSteps = stepsInWindow.fold<double>(
          0.0,
          (s, p) => s + ((p.value as NumericHealthValue).numericValue.toDouble()),
        );
        final durationMinutes = end.difference(start).inSeconds / 60.0;
        if (durationMinutes > 0) {
          cadence = (totalSteps / durationMinutes).round();
        }
      }

      sessions.add(RunSession(
        id: runId,
        startedAt: start,
        endedAt: end,
        distanceMeters: distanceMeters,
        avgHeartRate: avgHr,
        calories: cal,
        cadenceSpm: cadence,
        runType: RunType.other,
        source: RunSource.healthConnect,
        externalId: externalId,
      ));
    }

    return sessions;
  }
}
