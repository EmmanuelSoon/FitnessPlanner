# Start Workout & History

## Context
The previous PR shipped the workout list with edit/delete. Workouts exist on disk but cannot yet be *performed*. This PR closes the last two MVP sections in `README.md`:

- **Start Workout** — a session runner that steps through `Workout.generateWorkoutSequence()`, runs a rest timer between sets, plays an audio + haptic cue at the final 3 seconds, and supports pause/skip.
- **History** — a list of past sessions (date, duration, completion status), with a detail view showing target-vs-actual reps/weight per set.

The two features share one persisted concept — `WorkoutSession` — so they ship together in a single PR. Sessions are saved when the user finishes the workout *or* when they back out mid-session (partial sessions appear in history with a "partial" badge).

Audio cue uses `SystemSound.play(SystemSoundType.alert)` + `HapticFeedback.mediumImpact()` from `flutter/services.dart` — **no new packages added**.

---

## New Models (Hive, hand-written adapters)

Follow the existing convention in `lib/domain/models/`: a POJO with `toJson` / `fromJson`, and a sibling `_adapter.dart` that stores via `json.encode`/`json.decode` over a single string. See `workout_adapter.dart:6` for the pattern to mirror.

### `lib/domain/models/logged_set.dart` (typeId 3)
One performed (or skipped) set within a session.

```dart
class LoggedSet {
  final String exerciseName;
  final int targetReps;
  final double targetWeight;
  final int actualReps;     // defaults to target if user didn't change
  final double actualWeight;
  final bool skipped;
}
```

### `lib/domain/models/workout_session.dart` (typeId 2)
A single performance of a workout.

```dart
class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;   // denormalised so history survives workout deletion
  final DateTime startedAt;
  final DateTime endedAt;
  final bool completed;       // false = user backed out partway
  final List<LoggedSet> sets;

  Duration get duration => endedAt.difference(startedAt);
}
```

`workoutName` is denormalised on purpose: if the user later deletes the workout, history must still render.

### Adapters
- `WorkoutSessionAdapter` — typeId **2**
- `LoggedSetAdapter` — typeId **3**

Both follow `ExerciseAdapter` exactly (`exercise_adapter.dart:6`): `read` decodes a single JSON string, `write` encodes one. Add the `// typeId N reserved` comment.

---

## New Repository + Provider

### `lib/data/session_repository.dart`
Mirror `workout_repository.dart:7` line-for-line. Box name `'sessions'`. Methods: `getAll()`, `save(session)`, `delete(id)`. Sort `getAll()` by `startedAt` descending so newest sessions render first.

### `lib/providers/session_providers.dart`
Mirror `workout_providers.dart:8`: `sessionRepositoryProvider` + `sessionsProvider` (`AsyncNotifierProvider<SessionsNotifier, List<WorkoutSession>>`) with `saveSession` / `deleteSession`, each calling `ref.invalidateSelf(); await future;` to refresh consumers.

---

## New Screens

All under `lib/presentation/`. Navigation continues to use `Navigator.push(MaterialPageRoute(...))` — no `go_router`.

### `lib/presentation/workout_session_screen.dart`
`ConsumerStatefulWidget` that takes a `Workout`. Local state owns the timer; the screen is the only consumer so a `Notifier` isn't worth the indirection yet.

**State:**
- `late final List<Exercise> _sequence` — from `workout.generateWorkoutSequence()`
- `int _index = 0` — current step
- `final List<LoggedSet> _logged = []`
- `late final DateTime _startedAt`
- `Timer? _restTimer`
- `int _restSecondsRemaining = 0`
- `bool _isResting = false`
- `bool _isPaused = false`
- `final _actualRepsCtrl` / `_actualWeightCtrl` — `TextEditingController`s pre-filled with target each step

**Layout (two visual modes):**
1. *Exercising* — large name, "Set X of N", target reps/weight, two `TextFormField`s for actual reps/weight (pre-populated with target), `Finish Set` (primary) + `Skip` (text button) + `Pause` icon button in app bar.
2. *Resting* — countdown display (`_restSecondsRemaining`s remaining), "Up next: <name>", `Pause/Resume` + `Skip Rest`.

**Behaviour:**
- `Finish Set`: append `LoggedSet(skipped: false, actualReps: ctrl, actualWeight: ctrl)` to `_logged`, then either start the rest timer (if more sets remain) or call `_finishWorkout(completed: true)`.
- `Skip`: append `LoggedSet(skipped: true, actualReps: 0, actualWeight: 0)`, then advance the same way.
- Rest timer: `Timer.periodic(Duration(seconds: 1), ...)`. On each tick decrement `_restSecondsRemaining`. When the new value is `3`, `2`, or `1`: `SystemSound.play(SystemSoundType.alert)` + `HapticFeedback.mediumImpact()`. When it hits `0`: cancel timer, advance `_index`, reset controllers to next target.
- `Pause`: cancel `_restTimer` but keep `_restSecondsRemaining`; `Resume` re-creates the periodic timer.
- `WillPopScope`/`PopScope`: if `_logged` is non-empty *and* `_index < _sequence.length`, show "Save partial progress?" dialog — `Save` calls `_finishWorkout(completed: false)` then pops; `Discard` just pops; `Cancel` stays.
- `_finishWorkout({required bool completed})`: build a `WorkoutSession`, call `ref.read(sessionsProvider.notifier).saveSession(session)`, pop with a SnackBar.

Always `_restTimer?.cancel()` and dispose controllers in `dispose()`.

### `lib/presentation/history_screen.dart`
`ConsumerWidget` consuming `sessionsProvider`. Mirror `WorkoutListScreen` (`workout_list_screen.dart:7`):
- `AppBar`: "History"
- `loading` / `error` / empty-state ("No sessions yet")
- `ListView.builder` of cards: workout name (headline), formatted date (`DateFormat`-free — use `'${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}'`, no new dependency), duration in minutes, and a small `Chip(label: Text('Partial'))` when `!completed`.
- Tap a card → push `SessionDetailScreen(session)`. Long-press or trailing icon → delete with `AlertDialog` confirmation (reuse the pattern at `workout_list_screen.dart:100`).

### `lib/presentation/session_detail_screen.dart`
Read-only screen. `AppBar` title = workout name + date. Body = `ListView` of `LoggedSet` rows showing target → actual (e.g. `"10 reps × 20kg  →  8 reps × 20kg"`), with skipped sets dimmed and labelled "Skipped".

---

## Files to Modify

### `lib/main.dart`
- Register the two new adapters after the existing two:
  ```dart
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(LoggedSetAdapter());
  ```
- Open the new box: `await Hive.openBox<WorkoutSession>('sessions');`

### `lib/presentation/workout_list_screen.dart`
- Add `IconButton(icon: Icon(Icons.play_arrow))` to `_WorkoutCard`'s trailing `Row` (place it *before* edit/delete) → `Navigator.push(WorkoutSessionScreen(workout: workout))`.
- Add an `AppBar` action: `IconButton(icon: Icon(Icons.history))` → `Navigator.push(HistoryScreen())`.

### `README.md`
Tick the boxes under **Start Workout** and **History** once shipped.

---

## Implementation Order

1. Models + adapters (`logged_set`, `workout_session`, both adapters) — no dependencies
2. `session_repository.dart` + `session_providers.dart` — depends on models
3. `main.dart` adapter registration + box open
4. `session_detail_screen.dart` — pure read view, easiest to verify in isolation by hand-crafting a session
5. `history_screen.dart` — depends on provider + detail screen
6. `workout_session_screen.dart` — largest piece; build the exercising view first, add rest/timer, then audio cue, then pause, then back-out handling
7. `workout_list_screen.dart` — wire play + history entry points last
8. Update `README.md` checkboxes

---

## Verification

Run on a real device or emulator (not just `flutter analyze`/`flutter test` — this is a timer + audio feature).

1. **Cold start** — app launches, no Hive errors after registering new adapters and opening the `sessions` box.
2. **Happy path** — start a workout with ≥2 exercises and ≥2 sets each. Finish each set, confirm:
   - Rest timer counts down from the exercise's `restTime.inSeconds`.
   - System alert sound + medium haptic fires on the 3 → 2 → 1 ticks (phone not on silent).
   - Timer auto-advances to next set at 0.
   - On the last set, no rest is shown; "Workout complete" SnackBar appears and screen pops.
3. **Pause/Resume** — during rest, tap Pause: countdown freezes. Tap Resume: continues from where it stopped.
4. **Skip** — both during exercise (logs skipped set, advances) and "Skip Rest" (cancels timer, advances).
5. **Edited actuals** — change reps/weight before Finish Set; verify the saved `LoggedSet` reflects the entered values (check via History → detail).
6. **Partial save** — start a workout, log one set, tap Android back / iOS swipe-back → confirm dialog. Choose Save → History shows the workout with a "Partial" chip and duration ≈ time elapsed.
7. **Discard** — repeat (6) and choose Discard → nothing in History.
8. **History persistence** — fully restart the app; both completed and partial sessions are still listed in newest-first order.
9. **Workout deletion safety** — delete the underlying workout; existing history sessions still render using their denormalised `workoutName`.
10. **Empty history** — fresh install (or after clearing the box) shows the empty state.
