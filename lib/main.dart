import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'domain/models/exercise_adapter.dart';
import 'domain/models/workout_adapter.dart';
import 'domain/models/workout_session_adapter.dart';
import 'domain/models/logged_set_adapter.dart';
import 'domain/models/workout.dart';
import 'domain/models/workout_session.dart';
import 'presentation/workout_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(LoggedSetAdapter());
  await Hive.openBox<Workout>('workouts');
  await Hive.openBox<WorkoutSession>('sessions');

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
      home: const WorkoutListScreen(),
    );
  }
}
