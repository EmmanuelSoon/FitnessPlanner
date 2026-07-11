import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/run_override.dart';

const _kRunOverridesBox = 'run_overrides';

class RunOverrideRepository {
  final Box<RunOverride> _box;

  RunOverrideRepository(this._box);

  static String _key(String mesoId, DateTime d) =>
      '$mesoId|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  RunOverride? get(String mesoId, DateTime d) => _box.get(_key(mesoId, d));

  List<RunOverride> forMeso(String mesoId) =>
      _box.values.where((o) => o.mesocycleId == mesoId).toList();

  Future<void> save(RunOverride o) =>
      _box.put(_key(o.mesocycleId, o.date), o);

  Future<void> clear(String mesoId, DateTime d) =>
      _box.delete(_key(mesoId, d));
}

final runOverrideRepositoryProvider = Provider<RunOverrideRepository>((ref) {
  return RunOverrideRepository(Hive.box<RunOverride>(_kRunOverridesBox));
});
