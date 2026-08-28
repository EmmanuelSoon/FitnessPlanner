import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/exercise_library.dart';

void main() {
  group('kExerciseLibrary', () {
    test('is non-empty and every entry has a name and category', () {
      expect(kExerciseLibrary, isNotEmpty);
      for (final e in kExerciseLibrary) {
        expect(e.name, isNotEmpty);
        expect(e.category, isNotEmpty);
      }
    });

    test('exercise names are unique', () {
      final names = kExerciseLibrary.map((e) => e.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });
  });
}
