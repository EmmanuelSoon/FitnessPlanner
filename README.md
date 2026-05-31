# PlateUp

A Flutter workout tracking app for Android that keeps everything local — no accounts, no cloud sync, no subscriptions.

## What it does

**PlateUp** lets you build your own workout programs and follow them at the gym. You design the workouts once, then the app handles the structure while you lift.

### Core features

**Workout builder** — Create workouts with any combination of exercises. Configure sets, reps, weight, and rest time per exercise. Supports supersets (two exercises back-to-back) and timed exercises (e.g. planks). Optional warm-up sequences can be added to any workout.

**Live session screen** — Guides you through your workout set by set. Tracks rest timers between sets, keeps the screen on during sessions, and plays an audio cue when rest ends. Logs the weight and reps you actually completed.

**Session history** — Every completed session is saved locally. Browse past sessions, see which workouts you did, and review the sets and weights logged.

**Mesocycles** — Organise your training into structured training blocks. A mesocycle assigns specific workouts to days of the week and runs for a configurable number of training weeks followed by a deload/rest week. The app tracks which week of the cycle you're in and repeats the cycle automatically.

**Calendar view** — See your scheduled workouts on a monthly calendar. Tap any day to start that day's assigned workout directly. Supports day-level overrides (swap or skip a specific day without changing the whole plan).

**Workout reminders** — Set a daily reminder time and the app schedules notifications for the next 21 days that have a workout assigned, using your mesocycle schedule.

**Appearance** — Multiple colour themes with light/dark variants. All fonts are bundled — no network requests.

## Tech stack

- **Flutter** (Dart) — Android only
- **Riverpod** — state management
- **Hive** — on-device storage (workouts, sessions, mesocycles, overrides)
- **flutter_local_notifications** — workout reminder notifications

## Building

Requires Flutter SDK `^3.11.0`.

```bash
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

## Data & privacy

All data is stored on-device using Hive. Nothing is sent to any server. Uninstalling the app removes all data.
