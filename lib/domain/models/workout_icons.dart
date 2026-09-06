import 'package:flutter/material.dart';

/// Fixed catalog of icons a user can pick from when creating/editing a
/// workout — shown wherever that workout is represented: the calendar grid,
/// its list card, the start-preview screen, and the workout picker.
const Map<String, IconData> kWorkoutIcons = {
  'dumbbell': Icons.fitness_center_rounded,
  'pull_up': Icons.sports_gymnastics_rounded,
  'push_up': Icons.accessibility_new_rounded,
  'cardio': Icons.favorite_rounded,
  'stretch': Icons.self_improvement_rounded,
  'core': Icons.horizontal_rule_rounded,
  'running': Icons.directions_run_rounded,
  'cycling': Icons.directions_bike_rounded,
  'swimming': Icons.pool_rounded,
  'yoga': Icons.spa_rounded,
  'boxing': Icons.sports_mma_rounded,
  'hiit': Icons.bolt_rounded,
};

IconData workoutIconFor(String? key) =>
    kWorkoutIcons[key] ?? Icons.fitness_center_rounded;
