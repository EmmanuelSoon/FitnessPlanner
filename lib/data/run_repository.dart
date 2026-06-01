import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/run_session.dart';

const _kRunsBox = 'runs';

class RunRepository {
  final Box<RunSession> _box;

  RunRepository(this._box);

  List<RunSession> getAll() {
    final runs = _box.values.toList();
    runs.sort((a, b) => b.startedAt.compareTo(a.startedAt)); // newest first
    return runs;
  }

  /// Returns all runs whose [startedAt] falls on the given local calendar day.
  List<RunSession> forDate(DateTime date) {
    final dayKey = '${date.year}-${date.month}-${date.day}';
    return _box.values.where((r) {
      final d = r.startedAt;
      return '${d.year}-${d.month}-${d.day}' == dayKey;
    }).toList();
  }

  /// Returns true when a run with [id] is already stored (used for dedup on import).
  bool exists(String id) => _box.containsKey(id);

  Future<void> save(RunSession run) => _box.put(run.id, run);

  Future<void> delete(String id) => _box.delete(id);
}

final runRepositoryProvider = Provider<RunRepository>((ref) {
  return RunRepository(Hive.box<RunSession>(_kRunsBox));
});
