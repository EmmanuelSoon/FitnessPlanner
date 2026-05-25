import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'domain/models/exercise_adapter.dart';
import 'domain/models/superset_adapter.dart';
import 'domain/models/workout_adapter.dart';
import 'domain/models/workout_session_adapter.dart';
import 'domain/models/logged_set_adapter.dart';
import 'domain/models/workout.dart';
import 'domain/models/workout_session.dart';
import 'presentation/workout_list_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Hive.initFlutter();
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(SupersetAdapter());
  Hive.registerAdapter(WorkoutAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(LoggedSetAdapter());
  await Hive.openBox<Workout>('workouts');
  await Hive.openBox<WorkoutSession>('sessions');

  runApp(const ProviderScope(child: FitnessPlannerApp()));
}

class FitnessPlannerApp extends ConsumerWidget {
  const FitnessPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeProvider);

    return themeAsync.when(
      loading: () => const _SplashApp(),
      error: (_, _) => const _SplashApp(),
      data: (themeState) {
        final appTheme = themeState.appThemeData;
        final materialTheme = buildMaterialTheme(appTheme);

        // Update system UI overlay style to match theme
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              appTheme.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: appTheme.c.bg,
          systemNavigationBarIconBrightness:
              appTheme.isDark ? Brightness.light : Brightness.dark,
        ));

        return AppThemeScope(
          appTheme: appTheme,
          child: MaterialApp(
            title: 'Fitness Planner',
            debugShowCheckedModeBanner: false,
            theme: materialTheme,
            darkTheme: materialTheme,
            themeMode: appTheme.isDark ? ThemeMode.dark : ThemeMode.light,
            home: const WorkoutListScreen(),
          ),
        );
      },
    );
  }
}

/// Minimal splash shown while theme loads from storage.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        color: const Color(0xFFE6EDE7),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1B7A6B),
          ),
        ),
      ),
    );
  }
}
