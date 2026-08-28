import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/default_warmup.dart';

void main() {
  group('createDefaultWarmup', () {
    test('returns 6 timed exercises with unique names and no rest between them', () {
      final warmup = createDefaultWarmup();

      expect(warmup, hasLength(6));
      expect(warmup.map((e) => e.name).toSet(), hasLength(6));
      for (final e in warmup) {
        expect(e.timedDuration, const Duration(seconds: 30));
        expect(e.restTime, Duration.zero);
        expect(e.sets, 1);
      }
    });

    test('returns a fresh mutable list each call', () {
      final a = createDefaultWarmup();
      final b = createDefaultWarmup();

      a.first.name = 'Mutated';

      expect(b.first.name, isNot('Mutated'));
    });
  });
}
