# 017 — README rewrite with screenshot demo

## Context

User wants the README rewritten, with a small screenshot demo of the app's main feature, and wants the "Core features" list trimmed of anything "lame."

Confirmed with user:
- Screenshot subject: **live session screen** (set-by-set workout tracking).
- Screenshot source: capture from the running emulator via `adb` (`adb devices` confirms `emulator-5554` is attached).
- Base version: build on top of the README's current **uncommitted** working-tree edits (already softened the "no accounts/cloud sync" line and added an iOS caveat) rather than the last commit — those are the user's own in-progress draft, not something to discard.

## What "lame" means here (my read — flag if wrong)

Comparing the current README's "Core features" against `Feature_tracking.md`'s "Done" list:

- **Cut down / demote "Appearance"** (colour themes) — cosmetic, not a differentiator, reads as filler next to workout builder/mesocycles/live session.
- **Fold "Workout reminders" into the Calendar view bullet** — it's a minor consequence of the calendar/mesocycle schedule, not a standalone feature worth its own paragraph.
- **Add "Running tracking"** — currently *missing* from the README entirely despite being a real, shipped feature (manual entry + Health Connect import from Samsung watch, run indicators on calendar, per `Feature_tracking.md`). This isn't a cut, but leaving it out while keeping "Appearance" in is part of why the list reads unbalanced.
- Keep: Workout builder, Live session screen, Mesocycles, Calendar view, Session history — these are the actual core loop.

## Proposed README structure

```markdown
# PlateUp

A Flutter workout tracking app for Android that keeps everything local.

## What it does

**PlateUp** lets you build your own workout programs and follow them at the gym. You design the workouts once, then the app handles the structure while you lift.

### Demo

![Live session screen](docs/screenshot-live-session.png)

The live session screen guides you through a workout set by set — rest timers, an audio cue when rest ends, and logging of the weight/reps you actually did.

### Core features

**Workout builder** — Create workouts with any combination of exercises. Configure sets, reps, weight, and rest time per exercise. Supports supersets (two exercises back-to-back) and timed exercises (e.g. planks). Optional warm-up sequences can be added to any workout.

**Live session screen** — Guides you through your workout set by set. Tracks rest timers between sets, keeps the screen on during sessions, and plays an audio cue when rest ends. Logs the weight and reps you actually completed.

**Mesocycles** — Organise your training into structured training blocks. A mesocycle assigns specific workouts to days of the week and runs for a configurable number of training weeks followed by a deload/rest week. The app tracks which week of the cycle you're in and repeats the cycle automatically.

**Calendar view** — See your scheduled workouts on a monthly calendar, with reminder notifications for upcoming workout days. Tap any day to start that day's assigned workout directly. Supports day-level overrides (swap or skip a specific day without changing the whole plan).

**Running** — Log runs manually or import them from Health Connect (e.g. a Samsung watch) — distance, duration, pace, HR, cadence. Runs can be scheduled alongside strength days in a mesocycle and show up on the calendar.

**Session history** — Every completed session is saved locally. Browse past sessions, see which workouts you did, and review the sets and weights logged.

## Tech stack

- **Flutter** (Dart) — Note: the owner only verified on Android as he uses an android phone. iOS users, use at your own risk.
- **Riverpod** — state management
- **Hive** — on-device storage (workouts, sessions, mesocycles, overrides)
- **flutter_local_notifications** — workout reminder notifications

## Building

Requires Flutter SDK `^3.11.0`.

\`\`\`bash
flutter pub get
flutter run
\`\`\`

To build a release APK:

\`\`\`bash
flutter build apk --release
\`\`\`

## Data & privacy

All data is stored on-device using Hive. Nothing is sent to any server. Uninstalling the app removes all data.
```

Notes:
- "Appearance" is dropped as a bullet (themes are a nice-to-have, not core); not re-mentioned elsewhere since the tech stack section is about libraries, not UI features.
- The `Tech stack` and `Building`/`Data & privacy` sections are otherwise left as-is (already edited by the user, not part of this task's scope).

## Screenshot capture steps

1. On the running emulator (`emulator-5554`), navigate to the live session screen for an in-progress workout (may need to start a workout in the app first).
2. `adb exec-out screencap -p > docs/screenshot-live-session.png` (create `docs/` if it doesn't exist).
3. Reference it in the README as `docs/screenshot-live-session.png`.
4. Sanity-check image opens and isn't a blank/lock screen.

## Open question

Emulator needs to actually be sitting on the live session screen (mid-workout, with some rest timer/reps visible) for the screenshot to read as a good demo — I'll need to drive the app into that state first (start a workout, log a set or two) unless one is already in progress. Flagging in case there's a specific workout/state you'd rather I use.

## Verification

- Visual check of rendered README (e.g. via `git diff` review, or GitHub preview) — headings render, image link resolves, no broken markdown.
- Confirm screenshot file is a reasonable size/committed under `docs/`.
