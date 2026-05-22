import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'domain/models/exercise_adapter.dart';
import 'domain/models/workout_adapter.dart';
import 'domain/models/workout.dart';
import 'presentation/create_workout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutAdapter());
  await Hive.deleteBoxFromDisk('workouts'); // remove after first run — clears old data without weight field
  await Hive.openBox<Workout>('workouts');

  runApp(const ProviderScope(child: FitnessPlannerApp()));
}

class FitnessPlannerApp extends StatelessWidget {
  const FitnessPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const CreateWorkoutScreen(),
    );
  }
}
