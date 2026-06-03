# Plan: Warm-up beeps, screen-off regression, Health Connect auto-sync

## Context

Three issues reported during/after recent workout & Health Connect work:

1. **Warm-up beeps too noisy** — a timed warm-up exercise (30s) beeps *every second* for the
   full duration. It should beep only during the final countdown, matching the rest timer.
2. **Screen turns off during workout (regression)** — introduced in PR #18 when `WarmupScreen`
   gained its own wakelock toggle. The warm-up navigates to the session via `pushReplacement`,
   and the old route's `dispose()` runs *after* the new route's `initState()`. So the session
   enables wakelock, then the warm-up's late `dispose()` disables it → screen sleeps mid-workout.
3. **Manual-only Health Connect sync** — sync only happens via a button on the Runs screen.
   Want auto-sync when the Runs screen opens, plus pull-to-refresh.

## Fix 1 — Warm-up beep only in final 3 seconds

File: `lib/presentation/warmup_screen.dart`, `_startTimer()` (lines 111-128).

The `else` branch beeps + haptics on every tick. Gate it to the final 3 seconds, mirroring the
rest-timer pattern in `workout_session_screen.dart:199-200`
(`if (_restSecondsRemaining <= 3 && _restSecondsRemaining > 0)`).

```dart
setState(() => _timedSecondsRemaining--);
if (_timedSecondsRemaining <= 0) {
  t.cancel();
  HapticFeedback.heavyImpact();
  _advanceExercise();
} else if (_timedSecondsRemaining <= 3) {     // final-countdown beeps only
  _playBeep();
  HapticFeedback.mediumImpact();
}
```

(`> 0` already guaranteed since we're in the `else` of `<= 0`.) The pre-start and "get ready"
3-second interstitials are unchanged — they are already short countdowns.

## Fix 2 — Keep screen on during workout (wakelock handoff)

File: `lib/presentation/warmup_screen.dart`.

The warm-up screen owns wakelock only while it is the active screen. When it hands off to the
session (which manages its own wakelock), it must NOT disable wakelock on dispose. Add a handoff
flag:

- Add field: `bool _navigatedToWorkout = false;`
- In `_goToWorkout()` (line 170), set `_navigatedToWorkout = true;` before `pushReplacement`.
- In `dispose()` (line 57), guard the disable:
  ```dart
  if (!_navigatedToWorkout) WakelockPlus.disable();
  ```

This keeps wakelock enabled (owned by `WorkoutSessionScreen`) when starting the workout, while
still releasing it if the user backs out of the warm-up. `WorkoutSessionScreen`'s existing
enable/disable logic (initState line 63, dispose line 77, finish/back-out paths) is unchanged and
correct.

> Note: This is the concrete Dart-level regression. If a device test still shows the screen
> sleeping after this fix, the secondary suspect is the `FlutterFragmentActivity` swap from PR #22
> (`MainActivity.kt`) interacting with `wakelock_plus`; only investigate that if the test fails.

## Fix 3 — Auto-sync on Runs screen open + pull-to-refresh

File: `lib/presentation/run_list_screen.dart`. Reuse the existing `_syncFromHealthConnect()`
(lines 109-172). Scope: Runs screen, no global/provider refactor.

**3a. Silent auto-sync on open.** Add a `bool silent` param so the automatic sync doesn't spam
snackbars (suppress the "Already up to date" and error snackbars; still surface a successful
import count). Manual button and pull-to-refresh call it non-silent (full feedback).

```dart
Future<void> _syncFromHealthConnect({bool silent = false}) async { ... }
// suppress the "Already up to date" branch and the two error snackbars when silent
```

Trigger once on open via `initState`:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => _syncFromHealthConnect(silent: true),
  );
}
```
(Add `initState` to `_RunListScreenState`; it is already a `ConsumerState`.)

**3b. Pull-to-refresh.** Wrap the list area (build lines 76-94) in a `RefreshIndicator` whose
`onRefresh` calls `_syncFromHealthConnect()` (non-silent — manual gesture). For the gesture to work
in the empty/loading/error states (currently non-scrollable `Center` widgets), make the content
always scrollable:
- Data branch `ListView.separated`: add `physics: const AlwaysScrollableScrollPhysics()`.
- Empty/loading/error branches: wrap each in a `ListView`/`SingleChildScrollView` with
  `AlwaysScrollableScrollPhysics` (so the empty state can also be pulled to sync).

`RefreshIndicator(color: c.accent, backgroundColor: c.surface, onRefresh: _syncFromHealthConnect, child: ...)`.

## Critical files

- `lib/presentation/warmup_screen.dart` — Fix 1 (`_startTimer`) and Fix 2 (`dispose`, `_goToWorkout`, new flag).
- `lib/presentation/run_list_screen.dart` — Fix 3 (`initState`, `silent` param, `RefreshIndicator`).
- (Reference only, no change) `lib/presentation/workout_session_screen.dart` — rest-timer beep
  pattern to mirror; session wakelock ownership.

## Verification

Build & run on the physical device (release-phone skill / `flutter run`).

1. **Warm-up beeps**: Start a workout with a warm-up. During a 30s timed exercise, confirm
   silence until the last 3 seconds, then beep + vibrate each of the final 3 ticks. Confirm
   pre-start and get-ready 3-2-1 countdowns still beep.
2. **Screen stays on**: Start a workout, let warm-up hand off to the session, then leave the
   phone untouched past the system screen-timeout (e.g. 30s). Screen must stay on for the whole
   session. Back out of a warm-up (back button) and confirm the screen is allowed to sleep again.
3. **Auto-sync + pull-to-refresh**: Open the Runs screen → runs sync automatically without an
   "Already up to date" snackbar (count snackbar only if new runs imported). Pull down on the
   list (and on the empty state) → spinner shows, sync runs, full snackbar feedback appears.

No automated tests exist for these UI flows; verification is manual on-device.
