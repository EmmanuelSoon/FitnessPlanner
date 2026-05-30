import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/day_override.dart';

const _kOverridesBox = 'overrides';

class OverrideRepository {
  final Box<DayOverride> _box;

  OverrideRepository(this._box);

  static String _key(String mesoId, DateTime d) =>
      '$mesoId|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DayOverride? get(String mesoId, DateTime d) => _box.get(_key(mesoId, d));

  List<DayOverride> forMeso(String mesoId) =>
      _box.values.where((o) => o.mesocycleId == mesoId).toList();

  Future<void> save(DayOverride o) =>
      _box.put(_key(o.mesocycleId, o.date), o);

  Future<void> clear(String mesoId, DateTime d) =>
      _box.delete(_key(mesoId, d));
}

final overrideRepositoryProvider = Provider<OverrideRepository>((ref) {
  return OverrideRepository(Hive.box<DayOverride>(_kOverridesBox));
});
