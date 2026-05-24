import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/workout_session.dart';

const _kSessionsBox = 'sessions';

class SessionRepository {
  final Box<WorkoutSession> _box;

  SessionRepository(this._box);

  List<WorkoutSession> getAll() {
    final sessions = _box.values.toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<void> save(WorkoutSession session) => _box.put(session.id, session);

  Future<void> delete(String id) => _box.delete(id);
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(Hive.box<WorkoutSession>(_kSessionsBox));
});
