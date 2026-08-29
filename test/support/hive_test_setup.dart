import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:fitness_planner/domain/models/day_override_adapter.dart';
import 'package:fitness_planner/domain/models/exercise_adapter.dart';
import 'package:fitness_planner/domain/models/logged_set_adapter.dart';
import 'package:fitness_planner/domain/models/mesocycle_adapter.dart';
import 'package:fitness_planner/domain/models/run_override_adapter.dart';
import 'package:fitness_planner/domain/models/run_session_adapter.dart';
import 'package:fitness_planner/domain/models/workout_adapter.dart';
import 'package:fitness_planner/domain/models/workout_session_adapter.dart';

/// Initializes Hive against a fresh temp directory and registers every
/// adapter used by the app, mirroring the registration in `main.dart`.
///
/// Call from `setUp`; pair with [tearDownTestHive] in `tearDown`.
Directory initTestHive() {
  final dir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(dir.path);

  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkoutAdapter());
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(WorkoutSessionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(LoggedSetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(MesocycleAdapter());
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(DayOverrideAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(RunSessionAdapter());
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(RunOverrideAdapter());
  }

  return dir;
}

/// Closes every open box and deletes the temp directory created by
/// [initTestHive].
Future<void> tearDownTestHive(Directory dir) async {
  await Hive.close();
  if (dir.existsSync()) dir.deleteSync(recursive: true);
}
