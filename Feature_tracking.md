# fitness_planner

## To Do

### Progress & Insights
- [ ] Per-exercise strength trend chart — weight/reps (or hold time) over time for a single exercise
- [ ] Overall training volume over time — total volume per week/month (rep volume for calisthenics; weight volume where applicable)
- [ ] Personal records — auto-detect and surface PRs (heaviest weight, most reps, longest hold) as they happen
- [ ] Running performance trends — pace/distance/HR over time, separate from strength progress
- [ ] AI-powered progression recommendations — analyse workout history and recommend adjustments (add/remove a rep, increase sets, raise weight, progress to harder variation) to optimise progression for the user

### Calendar
- [ ] Week view toggle — switch calendar between month and week view; week view should be bigger/easier to read than the current cramped month cells

### Other
- [ ] Duplicate workout — copy an existing workout as a starting point
- [ ] Improve library of exercises - increase the number of available exercises to begin with, if possible link to a demo or something. 

## Done

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

### Design Language
- [x] App icon — Plates · Stacked · Minimal (Mint variant)
- [x] Bundle Google Fonts locally (Manrope, Space Grotesk) — currently fetched at runtime; fails without network. Replace with asset fonts so the app works fully offline.
- [x] Design system — consistent colour tokens, typography scale, spacing

### Features
- [x] Adjust reps/weight on the fly during a workout (vs planned); weight field remains optional for calisthenics
- [x] Completion summary screen after workout (total time, volume lifted where applicable)
- [x] Exercise library — preset list of exercises with categories (chest, legs, back…), including common calisthenics movements (pull-ups, dips, push-up variations, etc.). Includes a keyword search function.
- [x] Reorder exercises via drag-and-drop
- [x] Calendar view of workouts with reminders (notify user of workout for the day)
- [x] Allow instead of reps, it is a timer for hold exercises
- [x] link running to app — manual entry + Health Connect import from Samsung watch; distance, duration, pace, avg HR, calories, cadence, run type, notes; run indicators on calendar
- [x] Schedule run days in a mesocycle — assign run type/distance targets to specific days alongside strength training days

### Mesocycles
- [x] Mesocycles

### UI Consistency
- [x] Adopt a spacing scale — headers, section labels, and list padding across `lib/presentation` now share one 16dp inset instead of 8 different left margins.
- [x] Adopt a type scale — named size constants for headlines and section labels replace hand-typed `fontSize` literals for those roles; the dead `TextTheme` in `app_theme.dart` was deleted.
- [x] Runs headline renders centred while every other headline is left-aligned — fixed the `CrossAxisAlignment` mismatch between the inner and outer `Column` in `run_list_screen.dart`.
- [x] Workout icon doesn't show on the main page — the workout list card, start-preview screen, and workout picker now use `workoutIconFor(workout.icon)` instead of a hardcoded dumbbell glyph.
- [x] Exercise field columns shift meaning between rows — SETS and REST now render once per superset group instead of shifting between rows; every exercise row shows REPS/WEIGHT uniformly.
- [x] No back icon on the calendar — superseded by bottom navigation: Workouts, Calendar, Runs, and History are now `NavigationBar` tabs, so there's no back button to be missing.
- [x] Top-right icon row mixes navigation and settings — superseded by bottom navigation: the header icon row (history/calendar/runs) is gone, and the Workouts header now shows only the appearance picker.
