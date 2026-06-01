import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/data/run_repository.dart';
import 'package:fitness_planner/domain/models/run_session.dart';

final runsProvider =
    AsyncNotifierProvider<RunsNotifier, List<RunSession>>(RunsNotifier.new);

class RunsNotifier extends AsyncNotifier<List<RunSession>> {
  @override
  Future<List<RunSession>> build() async =>
      ref.read(runRepositoryProvider).getAll();

  Future<void> saveRun(RunSession run) async {
    await ref.read(runRepositoryProvider).save(run);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteRun(String id) async {
    await ref.read(runRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}
