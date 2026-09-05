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
- [ ] No back icon on the calendar — `_buildHeader` (`calendar_screen.dart`) is chevron-left / month label / chevron-right / bell / edit, with no back button; the only way out is the system back gesture, and the left chevron (previous month) reads like a back button. Add an explicit back affordance.

### Design System
Measured on a Pixel 8 emulator (1080×2400 @ 2.625x). These are the likely cause of the app feeling "off" without any single screen looking wrong — the defects live in the relationships between elements, so a screen-by-screen review passes them.

- [ ] Adopt a spacing scale — there are 8 different left margins in use across `lib/presentation` (4, 8, 10, 12, 16, 18, 22, 32), several off any 4/8pt grid. The visible symptom: on Workouts the headline sits at 22.5dp while the cards under it sit at 15.6dp and the card contents at 32dp, so the headline aligns with neither. Same 22-vs-16 mismatch in `create_workout` ("EXERCISES" label) and `run_list_screen`. Pick one inset (16 or 24) and make headers, section labels, and list padding share it. ~16 horizontal call sites use 22/18, but this needs judgement, not find-and-replace — bottom sheets are their own surface and may be fine as-is.
- [ ] Adopt a type scale — the `TextTheme` defined in `app_theme.dart:412-431` is never read: `textTheme` appears exactly once in all of `lib/`, at its own definition. Instead there are 245 hand-typed `fontSize` literals passed to the `displayStyle`/`bodyStyle`/`monoStyle` helpers. Mostly a maintainability problem (one lever instead of 245, and the dead `TextTheme` currently misleads anyone who edits it) — the only visibly broken part is peer screens disagreeing on headline size (Workouts 44 vs Runs 36). Either wire the `TextTheme` up or delete it, and introduce named steps for the helpers.

### UI Fixes
- [ ] Runs headline renders centred while every other headline is left-aligned — measured: the "Runs" headline spans x=438-643px, dead centre of the 1080px screen, whereas "Workouts" starts at 22.5dp. This is a bug, not a style choice: in `run_list_screen.dart:67-84` the inner `Column` sets `CrossAxisAlignment.start`, but it shrink-wraps to the text width and the *outer* `Column` (line 40) uses the default `CrossAxisAlignment.center`, so the whole padded block gets centred and the `.start` is a no-op.
- [ ] Workout icon doesn't show on the main page — the icon picked in New/Edit Workout is only read by the calendar grid; the workout list card, start-preview screen, and workout picker all hardcode the dumbbell glyph. Use `workoutIconFor(workout.icon)` in those three places.
- [ ] Top-right icon row mixes navigation and settings — the main page header (`workout_list_screen.dart`) has four unlabeled 20px icons in a row: appearance (opens a modal sheet), history, calendar, and runs (all push a screen). Nothing distinguishes "jumps to a screen" from "opens a settings sheet", and there are no labels or grouping.
- [ ] Exercise field columns shift meaning between rows — in New/Edit Workout the field row is built conditionally (`showSets` on the first exercise of a group, `showRest` on the last), so a standalone exercise shows SETS/REPS/WEIGHT/REST while a superset's first exercise shows SETS/REPS/WEIGHT and its partner shows REPS/WEIGHT/REST. Scanning down a column doesn't mean the same thing row to row. Keep the columns semantically fixed.

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
