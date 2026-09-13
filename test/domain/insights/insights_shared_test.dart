import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/insights_shared.dart';
import 'package:fitness_planner/domain/models/workout_session.dart';

WorkoutSession _session({required String id, required DateTime startedAt}) => WorkoutSession(
      id: id,
      workoutId: 'w1',
      workoutName: 'Push Day',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(hours: 1)),
      completed: true,
      sets: const [],
    );

void main() {
  group('estimatedOneRm', () {
    test('a genuine single is reported as itself, not inflated by the Epley formula', () {
      expect(estimatedOneRm(100, 1), 100);
    });

    test('applies the Epley formula for reps between 2 and 12', () {
      expect(estimatedOneRm(100, 6), 100 * (1 + 6 / 30));
    });

    test('returns null above the 12-rep validity cap rather than fabricating a value', () {
      expect(estimatedOneRm(60, 13), isNull);
    });

    test('returns null for a zero-weight (bodyweight) set', () {
      expect(estimatedOneRm(0, 12), isNull);
    });

    test('returns null for a zero-rep set', () {
      expect(estimatedOneRm(60, 0), isNull);
    });
  });

  group('chronological', () {
    test('sorts sessions oldest first', () {
      final later = _session(id: 's2', startedAt: DateTime(2026, 3, 8));
      final earlier = _session(id: 's1', startedAt: DateTime(2026, 3, 1));

      final sorted = chronological([later, earlier]);

      expect(sorted.map((s) => s.id), ['s1', 's2']);
    });

    test('does not mutate the input list', () {
      final later = _session(id: 's2', startedAt: DateTime(2026, 3, 8));
      final earlier = _session(id: 's1', startedAt: DateTime(2026, 3, 1));
      final input = [later, earlier];

      chronological(input);

      expect(input.map((s) => s.id), ['s2', 's1']);
    });
  });
}
