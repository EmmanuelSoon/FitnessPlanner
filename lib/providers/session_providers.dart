import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_planner/data/session_repository.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<WorkoutSession>>(SessionsNotifier.new);

class SessionsNotifier extends AsyncNotifier<List<WorkoutSession>> {
  @override
  Future<List<WorkoutSession>> build() async =>
      ref.read(sessionRepositoryProvider).getAll();

  Future<void> saveSession(WorkoutSession session) async {
    await ref.read(sessionRepositoryProvider).save(session);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteSession(String id) async {
    await ref.read(sessionRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}
