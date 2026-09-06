import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_planner/domain/models/workout_icons.dart';

void main() {
  group('kWorkoutIcons', () {
    test('includes the cardio-activity icons alongside the strength ones', () {
      expect(kWorkoutIcons['running'], Icons.directions_run_rounded);
      expect(kWorkoutIcons['cycling'], Icons.directions_bike_rounded);
      expect(kWorkoutIcons['swimming'], Icons.pool_rounded);
      expect(kWorkoutIcons['yoga'], Icons.spa_rounded);
      expect(kWorkoutIcons['boxing'], Icons.sports_mma_rounded);
      expect(kWorkoutIcons['hiit'], Icons.bolt_rounded);
    });
  });

  group('workoutIconFor', () {
    test('resolves a new key to its icon', () {
      expect(workoutIconFor('running'), Icons.directions_run_rounded);
    });

    test('falls back to the dumbbell for an unknown key', () {
      expect(workoutIconFor('not_a_real_key'), Icons.fitness_center_rounded);
    });
  });
}
