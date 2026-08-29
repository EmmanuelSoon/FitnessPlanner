import 'package:fitness_planner/data/mesocycle_repository.dart';
import 'package:fitness_planner/data/override_repository.dart';
import 'package:fitness_planner/data/run_override_repository.dart';
import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/data/workout_repository.dart';
import 'package:fitness_planner/domain/models/day_override.dart';
import 'package:fitness_planner/domain/models/mesocycle.dart';
import 'package:fitness_planner/domain/models/run_override.dart';
import 'package:fitness_planner/domain/models/run_session.dart';
import 'package:fitness_planner/domain/models/workout.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

/// Hand-written in-memory fakes for the repository layer, used by provider
/// tests so notifier logic is exercised without touching real Hive
/// (persistence itself is covered by the repository tests in test/data).
///
/// Each fake `implements` its repository rather than extending it, so it
/// never needs a real Hive Box to construct — Dart's `implements` only
/// requires satisfying the public interface, not the private `_box` field.

String _dayKey(String mesoId, DateTime d) =>
    '$mesoId|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FakeWorkoutRepository implements WorkoutRepository {
  final Map<String, Workout> store = {};

  @override
  List<Workout> getAll() => store.values.toList();

  @override
  Future<void> save(Workout workout) async => store[workout.id] = workout;

  @override
  Future<void> delete(String id) async => store.remove(id);
}

class FakeSessionRepository implements SessionRepository {
  final Map<String, WorkoutSession> store = {};

  @override
  List<WorkoutSession> getAll() {
    final sessions = store.values.toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  @override
  Future<void> save(WorkoutSession session) async => store[session.id] = session;

  @override
  Future<void> delete(String id) async => store.remove(id);
}

class FakeMesocycleRepository implements MesocycleRepository {
  final Map<String, Mesocycle> store = {};

  @override
  List<Mesocycle> getAll() => store.values.toList();

  @override
  Future<void> save(Mesocycle m) async => store[m.id] = m;

  @override
  Future<void> delete(String id) async => store.remove(id);
}

class FakeOverrideRepository implements OverrideRepository {
  final Map<String, DayOverride> store = {};

  @override
  DayOverride? get(String mesoId, DateTime d) => store[_dayKey(mesoId, d)];

  @override
  List<DayOverride> forMeso(String mesoId) =>
      store.values.where((o) => o.mesocycleId == mesoId).toList();

  @override
  Future<void> save(DayOverride o) async =>
      store[_dayKey(o.mesocycleId, o.date)] = o;

  @override
  Future<void> clear(String mesoId, DateTime d) async =>
      store.remove(_dayKey(mesoId, d));
}

class FakeRunOverrideRepository implements RunOverrideRepository {
  final Map<String, RunOverride> store = {};

  @override
  RunOverride? get(String mesoId, DateTime d) => store[_dayKey(mesoId, d)];

  @override
  List<RunOverride> forMeso(String mesoId) =>
      store.values.where((o) => o.mesocycleId == mesoId).toList();

  @override
  Future<void> save(RunOverride o) async =>
      store[_dayKey(o.mesocycleId, o.date)] = o;

  @override
  Future<void> clear(String mesoId, DateTime d) async =>
      store.remove(_dayKey(mesoId, d));
}

class FakeRunRepository implements RunRepository {
  final Map<String, RunSession> store = {};

  @override
  List<RunSession> getAll() {
    final runs = store.values.toList();
    runs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return runs;
  }

  @override
  List<RunSession> forDate(DateTime date) {
    final dayKey = '${date.year}-${date.month}-${date.day}';
    return store.values.where((r) {
      final d = r.startedAt;
      return '${d.year}-${d.month}-${d.day}' == dayKey;
    }).toList();
  }

  @override
  bool exists(String id) => store.containsKey(id);

  @override
  Future<void> save(RunSession run) async => store[run.id] = run;

  @override
  Future<void> delete(String id) async => store.remove(id);
}
