import 'package:flutter/material.dart';

/// Fixed catalog of icons a user can pick from when creating/editing a
/// workout — shown as a small dot/icon on the calendar for that workout.
const Map<String, IconData> kWorkoutIcons = {
  'dumbbell': Icons.fitness_center_rounded,
  'pull_up': Icons.sports_gymnastics_rounded,
  'push_up': Icons.accessibility_new_rounded,
  'cardio': Icons.favorite_rounded,
  'stretch': Icons.self_improvement_rounded,
  'core': Icons.horizontal_rule_rounded,
};

IconData workoutIconFor(String? key) =>
    kWorkoutIcons[key] ?? Icons.fitness_center_rounded;
