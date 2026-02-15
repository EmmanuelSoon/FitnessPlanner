# Fitness Planner App

A comprehensive Android fitness tracking app that allows you to create custom workouts, execute them with a countdown timer for rest periods, and track your workout history with a calendar view.

## Features

- **Create Custom Workouts**: Build personalized workout routines by adding exercises and sets
- **Live Workout Execution**: Execute workouts with:
  - Current exercise display
  - Set and rep counter
  - Countdown timer for rest periods with audio cue
  - Easy navigation between sets and exercises
- **Customizable Rest Durations**: Choose from preset durations (30s, 60s, 90s, 120s) or enter custom rest times
- **Workout History**: Track completed workouts with:
  - Calendar grid view showing workout dates
  - Green highlight for completed workouts
  - Ability to view and delete past workout logs
- **Audio Feedback**: System beep notification when rest periods end
- **Screen Keep-Awake**: Screen stays on during workout execution to prevent accidental lock

## Project Structure

```
fitnessPlanner/
├── app/
│   ├── src/main/
│   │   ├── java/com/example/fitnessplanner/
│   │   │   ├── MainActivity.kt                    # Main entry point with workout list
│   │   │   ├── data/
│   │   │   │   ├── WorkoutDatabase.kt             # Room database configuration
│   │   │   │   ├── models/                        # Data entities
│   │   │   │   │   ├── Workout.kt
│   │   │   │   │   ├── Exercise.kt
│   │   │   │   │   ├── WorkoutSet.kt
│   │   │   │   │   └── WorkoutLog.kt
│   │   │   │   └── dao/                           # Data access objects
│   │   │   │       ├── WorkoutDao.kt
│   │   │   │       ├── ExerciseDao.kt
│   │   │   │       ├── WorkoutSetDao.kt
│   │   │   │       └── WorkoutLogDao.kt
│   │   │   ├── viewmodels/                        # ViewModel classes
│   │   │   │   ├── WorkoutListViewModel.kt
│   │   │   │   ├── WorkoutCreatorViewModel.kt
│   │   │   │   ├── WorkoutExecutorViewModel.kt
│   │   │   │   └── WorkoutHistoryViewModel.kt
│   │   │   └── ui/                                # Activities and Adapters
│   │   │       ├── WorkoutCreatorActivity.kt
│   │   │       ├── WorkoutExecutorActivity.kt
│   │   │       ├── WorkoutHistoryActivity.kt
│   │   │       └── WorkoutListAdapter.kt
│   │   └── res/layout/                            # XML layouts
│   │       ├── activity_main.xml
│   │       ├── activity_workout_creator.xml
│   │       ├── activity_workout_executor.xml
│   │       ├── activity_workout_history.xml
│   │       └── item_workout.xml
│   └── build.gradle.kts                           # App dependencies
├── gradle/libs.versions.toml                      # Library versions catalog
└── AndroidManifest.xml                            # App manifest
```

## Database Schema

### Workout
- `id` (PK): Unique identifier
- `name`: Workout name
- `description`: Workout description
- `createdAt`: Creation timestamp
- `isActive`: Whether workout is active

### Exercise
- `id` (PK): Unique identifier
- `workoutId` (FK): Parent workout
- `name`: Exercise name
- `order`: Display order

### WorkoutSet
- `id` (PK): Unique identifier
- `exerciseId` (FK): Parent exercise
- `reps`: Number of repetitions
- `restDuration`: Rest time in seconds (default: 60s)
- `order`: Display order

### WorkoutLog
- `id` (PK): Unique identifier
- `workoutId` (FK): Completed workout
- `date`: Completion timestamp
- `duration`: Workout duration in milliseconds
- `completed`: Whether workout was completed

## Dependencies

- **androidx.room** (2.6.1): Local database persistence
- **androidx.lifecycle** (2.7.0): ViewModel and LiveData
- **androidx.core** (1.10.1): Android utilities
- **androidx.appcompat** (1.6.1): Compatibility library
- **material** (1.10.0): Material Design components

## How to Use

### Creating a Workout
1. Click "Create Workout" from the main screen
2. Enter a workout name and optional description
3. Add exercises one by one using the "Add Exercise" button
4. For each exercise, select it and add sets with:
   - Number of reps
   - Rest duration (preset or custom)
5. Click "Save Workout" to persist the workout

### Executing a Workout
1. From the main screen, click "Start" next to a workout
2. The workout executor will show:
   - Current exercise name
   - Current set and total sets
   - Number of reps for the exercise
   - Countdown timer for rest periods
3. After completing an exercise, click "Next Set" to proceed
4. A countdown timer will start for the rest period
5. When the timer finishes, you'll hear a beep audio cue
6. After the final set, click "Finish Workout" to save completion

### Viewing Workout History
1. Click "Workout History" from the main screen
2. View a calendar grid showing completed workouts
3. Green-highlighted dates indicate days with completed workouts
4. Click on dates to view details of completed workouts

## Building and Running

1. Clone the repository
2. Open the project in Android Studio
3. Ensure you have JDK 11 or later installed
4. Run on an Android device or emulator (API 34+)

## Permissions

The app requires the following permissions:
- `VIBRATE`: For haptic feedback during rest periods
- `ACCESS_NETWORK_STATE`: For app functionality (implicit)

## Future Enhancements

- Vibration feedback during rest periods
- Workout statistics and progress tracking
- Exercise images and instructions
- Rest day tracking
- Multiple workout routines
- Social sharing of workouts

