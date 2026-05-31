import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/mesocycle.dart';

const _kMesocyclesBox = 'mesocycles';

class MesocycleRepository {
  final Box<Mesocycle> _box;

  MesocycleRepository(this._box);

  List<Mesocycle> getAll() => _box.values.toList();

  Future<void> save(Mesocycle m) => _box.put(m.id, m);

  Future<void> delete(String id) => _box.delete(id);
}

final mesocycleRepositoryProvider = Provider<MesocycleRepository>((ref) {
  return MesocycleRepository(Hive.box<Mesocycle>(_kMesocyclesBox));
});
