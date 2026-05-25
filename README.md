# PlateUp

## MVP
The minimum viable app. All of these must be done before the app is usable.

### Setup
- [x] Wire up main.dart to the fitness planner (remove default counter app)
- [x] Add state management (Riverpod or Provider)
- [x] Add local persistence (Hive or sqflite)

### Create Workout
- [x] Fix ExerciseCard: replace display-only text with editable TextFormFields (name, reps, sets, rest time)
- [x] Add optional weight field to Exercise model and form (weight is not required — many exercises are bodyweight/calisthenics)
- [x] Save created workouts to local storage

### View Workouts
- [x] Workout list screen (home screen)
- [x] Edit/delete existing workouts

### Start Workout
- [x] Workout execution screen — step through generated sequence
- [x] Finish button per exercise → immediately starts rest timer
- [x] Audio cue when rest timer reaches 3 seconds
- [x] Pause/resume workout
- [x] Skip exercise

### History
- [x] Workout log screen — list of past sessions with date and duration
- [x] Log actual weight/reps done per exercise during a session (weight optional for bodyweight/calisthenics exercises)

## Phase 2

### Design Language
- [x] App icon — Plates · Stacked · Minimal (Mint variant)
- [ ] Bundle Google Fonts locally (Manrope, Space Grotesk) — currently fetched at runtime; fails without network. Replace with asset fonts so the app works fully offline.
- [ ] Design system — consistent colour tokens, typography scale, spacing

### Features
- [ ] Adjust reps/weight on the fly during a workout (vs planned); weight field remains optional for calisthenics
- [ ] Completion summary screen after workout (total time, volume lifted where applicable)
- [ ] Duplicate workout — copy an existing workout as a starting point
- [ ] Exercise library — preset list of exercises with categories (chest, legs, back…), including common calisthenics movements (pull-ups, dips, push-up variations, etc.)
- [ ] Reorder exercises via drag-and-drop
- [ ] Calendar view of workouts with reminders (notify user of workout for the day)
- [ ] Allow instead of reps, it is a timer for hold exercises

## Future Features
- Progression charts — weight over time per exercise (or reps/sets progression for bodyweight exercises)
- Volume tracking over time (rep volume for calisthenics; weight volume where applicable)
- AI-powered progression recommendations — analyse workout history and recommend adjustments (add/remove a rep, increase sets, raise weight, progress to harder variation) to optimise progression for the user
