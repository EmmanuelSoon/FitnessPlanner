# fitness_planner

## MVP
The minimum viable app. All of these must be done before the app is usable.

### Setup
- [x] Wire up main.dart to the fitness planner (remove default counter app)
- [x] Add state management (Riverpod or Provider)
- [x] Add local persistence (Hive or sqflite)

### Create Workout
- [ ] Fix ExerciseCard: replace display-only text with editable TextFormFields (name, reps, sets, rest time)
- [ ] Add weight field to Exercise model and form
- [ ] Save created workouts to local storage

### View Workouts
- [ ] Workout list screen (home screen)
- [ ] Edit/delete existing workouts

### Start Workout
- [ ] Workout execution screen — step through generated sequence
- [ ] Finish button per exercise → immediately starts rest timer
- [ ] Audio cue when rest timer reaches 3 seconds
- [ ] Pause/resume workout
- [ ] Skip exercise

### History
- [ ] Workout log screen — list of past sessions with date and duration
- [ ] Log actual weight/reps done per exercise during a session

## Phase 2
- Adjust reps/weight on the fly during a workout (vs planned)
- Completion summary screen after workout (total time, volume lifted)
- Duplicate workout — copy an existing workout as a starting point
- Exercise library — preset list of exercises with categories (chest, legs, back…)
- Reorder exercises via drag-and-drop
- Personal records (PRs) — auto-detect when you beat your best weight or reps for an exercise

## Future Features
- Streak tracking (consecutive workout days)
- Calendar view of workouts with reminders
- Progression charts — weight over time per exercise
- Volume tracking over time
- Body measurements log
- AI-powered progression recommendations — use an LLM to analyse workout history and suggest adjustments (add/remove a rep, increase sets, raise weight, deload) to optimise progression for the user
