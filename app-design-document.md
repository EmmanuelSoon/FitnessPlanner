# Fitness Planner — App Design Brief

## What the app is

A personal, local-first workout planning and execution tool built in Flutter (iOS + Android). There is no account, no cloud sync, and no social features — everything is stored on the device. The core loop is: plan a workout in advance → go to the gym → follow the app through the session.

---

## User persona

- **One user** — built as a personal tool, not a multi-user product
- Experienced with strength training; knows what sets, reps, and rest time mean
- Uses the app at the gym — phone in hand, between sets, needs fast and glanceable UI
- Values speed and clarity over feature richness
- No interest in gamification, streaks, or social sharing

---

## Platform

Flutter — iOS and Android. Mobile only for now.

---

## MVP features (built or in active development)

| # | Feature | Status |
|---|---------|--------|
| 1 | **Create Workout** — name the workout, add exercises with sets / reps / weight / rest time | Done |
| 2 | **Workout Preview** — review the full expanded set sequence and total estimated duration before saving | Done |
| 3 | **Save to device** — workouts persist across app restarts using local storage (Hive) | Done |
| 4 | **View Workouts** — home screen listing all saved workouts as cards (name, exercise count, duration) | In progress |
| 5 | **Edit Workout** — tap edit on a card to reopen the create form pre-filled with existing data | In progress |
| 6 | **Delete Workout** — delete with a confirmation dialog | In progress |

---

## Post-MVP features (design should anticipate and leave room for these)

### Active Workout Mode
The most important future feature. When the user starts a workout, the app steps through every set one at a time:
- Large display of current exercise name, target reps, and weight
- "Done" button to mark a set complete and start the rest timer
- Countdown timer for the rest period between sets
- Progress indicator (set 2 of 3, exercise 1 of 4)
- Hint showing the next exercise coming up

### Workout History & Logs
- Record each completed session with a timestamp
- Log the actual weight lifted per set (vs. the planned weight)
- View past sessions for any given workout template

### Exercise Library
- Searchable catalog of common exercises (user doesn't have to type from scratch)
- Exercises tagged by muscle group (chest, legs, back, etc.)
- Tap an exercise in the library to add it directly to the current workout

### Progress Tracking
- Per-exercise line chart of max weight over time
- Personal record (PR) badge shown when a new best is achieved

---

## Data model

**Workout**
- `name` — e.g. "Chest Day"
- `exercises` — ordered list of Exercise objects
- `id` — unique identifier

**Exercise**
- `name` — e.g. "Bench Press"
- `sets` — number of sets
- `reps` — reps per set
- `restTime` — seconds between sets
- `weight` — kg

**Duration estimate:** 30 seconds per rep + rest time between sets

---

## Screen inventory

### MVP screens

1. **Workout List** (home screen)
   - Lists all saved workouts as cards
   - Each card shows: workout name, exercise count, estimated duration
   - Edit and delete actions per card
   - FAB to create a new workout
   - Empty state when no workouts exist: illustration + "Create your first workout" call to action

2. **Create / Edit Workout** (form screen)
   - Workout name field at the top
   - Scrollable list of exercise cards, each showing: name, sets, reps, weight, rest time fields
   - "Add Exercise" button appended below the list
   - "Preview Workout" primary button at the bottom
   - App bar title changes between "Create Workout" and "Edit Workout"

3. **Workout Preview** (read-only)
   - Shows the fully expanded set sequence (each individual set as a row)
   - Total estimated duration displayed prominently
   - "Save Workout" button
   - Back to edit if changes needed

### Post-MVP screens (design should include these as future views)

4. **Active Workout** (execution mode)
   - Full-screen focus on the current set
   - Exercise name, target reps and weight large and readable at arm's length
   - Rest timer countdown after each set
   - Progress through the workout (e.g. Set 2/3 · Exercise 1/4)
   - Subtle preview of next exercise

5. **Session History** (per workout)
   - List of past sessions for one workout template, sorted by date
   - Tap a session to see logged weights per set

6. **Exercise Library**
   - Search bar
   - Grouped by muscle category
   - Tap to add to current workout

7. **Progress Chart** (per exercise)
   - Line chart of max weight per session over time
   - PR marker on the chart

---

## Visual style

- **Clean and minimalist** — the aesthetic should feel calm, uncluttered, and easy on the eyes
- Prioritise legibility and breathing room over visual density
- Typography-led hierarchy: workout name should feel prominent, supporting metadata (exercise count, duration) should recede naturally
- Whitespace is a first-class design element — resist the urge to fill empty space
- No gradients, no heavy illustration, no decorative chrome
- Color palette, typography, and spacing choices are left to the designer's discretion — the goal is a result that looks polished and feels effortless to use

---

## UX principles

1. **Speed first** — every action reachable in ≤2 taps from the home screen
2. **Gym-legible** — active workout UI must be readable in under 1 second; no small text or dense layouts during a session
3. **No friction at the door** — no sign-in, no onboarding tutorial, no permissions prompts for MVP
4. **Forgiving edits** — workouts are easy to edit; nothing is permanent without a confirmation step (delete)
5. **Offline always** — the app works with no internet connection, always

---

## What this app is NOT

- Not a social fitness app (no sharing, followers, or leaderboards)
- Not a guided workout program with pre-set routines
- Not a calorie or nutrition tracker
- Not a wearable companion app
