# 004 — Mesocycles + Calendar with Reminders

## Context

The user trains on a fixed **5-weeks-on / 1-week-off** rhythm with a fixed weekday
schedule (e.g. Mon rest, Tue rest, Wed Pull, Thu Intervals, Fri Pull, Sat Zone-2 run,
Sun Push). Today the app only stores standalone workouts and lets you start/log them
ad-hoc — there's no notion of a training block, no calendar, and no reminders. The user
wants to actually *use* the app to follow and log this program: define the block once,
see it laid out on a calendar, know which week they're on, shuffle individual days when
life happens, trigger an early rest week, and get a daily nudge for the day's workout.

**Decisions made with the user:**
- A **mesocycle** = N training weeks + M rest weeks (e.g. 5 + 1). **No auto-progression**
  (deferred — requires a recommendation system; out of scope for this plan).
- Weekly layout = **fixed weekday template** (1=Mon..7=Sun → workoutId, nullable). The
  same workout may be assigned to multiple weekdays. Cardio days are just regular Workouts.
- After the rest week, the **same** mesocycle template **repeats automatically**, indefinitely.
- Reminders = **one global daily time** (a single app setting). Any day with a scheduled
  workout fires a local notification at that time.
- Calendar = **custom-built month grid** styled with the existing design tokens.

## Architecture overview

The keystone is a **pure schedule-derivation function** `workoutIdForDate(meso, override, date)`
that both the Calendar UI and the NotificationService consume. Keeping it pure (no Flutter/Hive
imports) makes early-rest, set-current-week, and per-day overrides robust and unit-testable.

New persistence: Hive typeId **4** (Mesocycle) + **5** (DayOverride), boxes `mesocycles`
and `overrides`. New Riverpod providers mirror the existing repo + `AsyncNotifierProvider`
pattern. One notification service, one pure-logic file, plus calendar + mesocycle-setup
screens. Entry points are header icons added to `WorkoutListScreen` (no bottom-nav refactor).

## Data model

### `lib/domain/models/mesocycle.dart` (typeId 4)
```
class Mesocycle {
  final String id;
  final String name;
  final int trainingWeeks;             // e.g. 5
  final int restWeeks;                 // e.g. 1
  final DateTime originalAnchor;       // IMMUTABLE; normalized to Monday 00:00 of cycle-1 week-1
  final Map<int, String?> weekdayWorkouts; // 1..7 -> workoutId or null (rest)
  final List<CycleAdjustment> adjustments; // append-only event log (see below)
}
```
- `originalAnchor` is **never mutated**. A non-Monday start date is snapped to its Monday.
- `weekdayWorkouts` is the repeating template; same workoutId may repeat; `null` = rest day.
- JSON follows the existing **JSON-string adapter pattern** (mirror `workout_adapter.dart`).
  `Map<int,String?>` keys must be stringified for `json.encode` (`e.key.toString()` / `int.parse`
  on read); DateTimes via `toIso8601String()`/`DateTime.parse` (like `WorkoutSession`).

```
enum AdjustmentType { earlyRest, setCurrentWeek }
class CycleAdjustment {
  final DateTime effectiveDate;     // normalized to the Monday it takes effect
  final AdjustmentType type;
  final int? targetCycleWeekIndex;  // 0-based week within a full cycle (len = trainingWeeks+restWeeks)
}
```

### `lib/domain/models/day_override.dart` (typeId 5)
```
enum OverrideKind { setWorkout, rest }
class DayOverride {
  final String mesocycleId;
  final DateTime date;       // normalized to 00:00 local
  final OverrideKind kind;
  final String? workoutId;   // required when kind == setWorkout
}
```
- Stored in a **separate box** keyed `'<mesocycleId>|<yyyy-MM-dd>'` (date-addressed → O(1)
  lookup; editing the template never disturbs overrides, and vice-versa).
- Covers all three edit ops without touching the template:
  - **Move** A from D1→D2 = `rest` on D1 + `setWorkout(A)` on D2.
  - **Clear a day** = `rest` override.
  - **Add ad-hoc** = `setWorkout(A)` on a would-be-rest date.

### Active mesocycle
Multiple mesocycles may be stored, but exactly **one is active**, tracked by
`active_mesocycle_id` in shared_preferences (avoids multi-write "unset all others" races).
Calendar + reminders read the active one; none set → calendar shows an onboarding state.

## Schedule derivation — `lib/domain/schedule/schedule_logic.dart` (pure)

**Why an append-only event log instead of a rolling anchor:** mutating one anchor on each
early-rest / set-current-week would re-derive *past* dates and corrupt history. Instead,
`originalAnchor` stays fixed forever and each `CycleAdjustment` only affects dates on/after
its `effectiveDate`. Deriving a date picks the **latest adjustment whose `effectiveDate ≤ date`**
(falling back to the original anchor as an implicit `targetCycleWeekIndex = 0`).

```dart
DateTime _mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1)); // Mon=1
}

// Phase anchor effective for `date`: latest adjustment <= date, folded into a virtual Monday.
DateTime _phaseAnchor(Mesocycle m, DateTime date) {
  DateTime bestEff = m.originalAnchor; int bestIdx = 0;
  for (final a in m.adjustments) {
    if (!a.effectiveDate.isAfter(date) && !a.effectiveDate.isBefore(bestEff)) {
      bestEff = a.effectiveDate; bestIdx = a.targetCycleWeekIndex ?? 0;
    }
  }
  return bestEff.subtract(Duration(days: bestIdx * 7));
}

int cycleWeekIndexForDate(Mesocycle m, DateTime date) {
  final len = m.trainingWeeks + m.restWeeks;
  final weeks = _mondayOf(date).difference(_phaseAnchor(m, date)).inDays ~/ 7;
  return ((weeks % len) + len) % len; // floor-mod, safe for pre-anchor dates
}

bool isRestWeek(Mesocycle m, DateTime date) =>
    cycleWeekIndexForDate(m, date) >= m.trainingWeeks;

// THE master function (Calendar + Notifications).
String? workoutIdForDate(Mesocycle m, DayOverride? ov, DateTime date) {
  if (ov != null) return ov.kind == OverrideKind.rest ? null : ov.workoutId;
  if (isRestWeek(m, date)) return null;
  return m.weekdayWorkouts[date.weekday];
}

// Banner label, e.g. "Week 3 of 5 · Training" / "Rest week 1 of 1".
ScheduleStatus statusForDate(Mesocycle m, DateTime date) { /* from cycleWeekIndexForDate */ }
```

- **set current week**: append `setCurrentWeek(targetCycleWeekIndex = chosen, effectiveDate = this Monday)`.
- **early rest**: append `setCurrentWeek(targetCycleWeekIndex = trainingWeeks, effectiveDate = this Monday)`
  — rest begins now; once the rest week(s) elapse the floor-mod naturally rolls into training
  week-1 of the next cycle, no special-casing.
- On append, if an adjustment with the same `effectiveDate` exists, **replace** it (dedupe).

## Repositories + providers (mirror existing patterns)

- `lib/data/mesocycle_repository.dart` — `getAll/save/delete` over `Hive.box<Mesocycle>('mesocycles')`,
  exposed via plain `Provider` (copy `workout_repository.dart`).
- `lib/data/override_repository.dart` — `get(mesoId,date)`, `forMeso(mesoId)`, `save`, `clear`,
  keyed `'<mesoId>|<yyyy-MM-dd>'`.
- `lib/providers/mesocycle_providers.dart`:
  - `mesocyclesProvider` (`AsyncNotifierProvider<…,List<Mesocycle>>`) with `save/delete`,
    `appendAdjustment(mesoId, adj)`, `setActive(id)`; each mutation `invalidateSelf(); await future;`.
  - `activeMesocycleProvider` — active-id (prefs, copy `theme_provider.dart`) joined with the list → `Mesocycle?`.
  - `overridesProvider` — `setWorkout/setRest/clear/move(from,to)`.
- `lib/providers/reminder_provider.dart` — global **pre-workout** `TimeOfDay`
  (`reminder_hour`/`reminder_minute`) + `enabled` bool in shared_preferences (copy
  `theme_provider.dart`). Framed in the UI as "Pre-workout reminder" — the time the user
  wants to be nudged to start preparing for their workout (e.g. "Time to prep for your
  workout!" notification body). No separate workout start time; one global time only.
- Every meso/override/reminder mutation funnels into the **reminder reschedule** (below).

## Notifications

**pubspec.yaml** add: `flutter_local_notifications`, `timezone`, `flutter_timezone` (current major lines).

**`lib/services/notification_service.dart`** — singleton wrapping `FlutterLocalNotificationsPlugin`:
- `init()`: `tz.initializeTimeZones()`, set local tz from `FlutterTimezone.getLocalTimezone()`,
  `initialize(...)`, create the `workout_reminders` channel.
- `requestPermissions()` (Android 13+ POST_NOTIFICATIONS) — triggered lazily when the user first
  enables reminders, not on cold start.
- `rescheduleAll({meso, overrideForDate, time, enabled, horizonDays = 21})`: `cancelAll()` then
  `zonedSchedule` one-shot notifications for each of the next ~21 days where
  `workoutIdForDate(...) != null`, id = day offset, title = "Time to prep for your workout!",
  body = resolved workout name (e.g. "Pull"). Use
  **`AndroidScheduleMode.inexactAllowWhileIdle`** (a daily nudge doesn't need exact alarms →
  avoids the Android 14 exact-alarm permission flow).
- **Rolling horizon refresh** (schedule is infinite): call `rescheduleAll` on app start, on
  meso save/adjustment, on override change, on reminder-time/enabled change, and on **app resume**
  (root `WidgetsBindingObserver`) to keep topping up the window as days pass.

**Android config:**
- `android/app/build.gradle.kts` — enable `isCoreLibraryDesugaringEnabled`, add
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.x")`, Java 17, `minSdk` ≥ 23.
- `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`
  permissions; the plugin's `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver`
  (BOOT_COMPLETED / MY_PACKAGE_REPLACED) so reminders survive reboot.

Wire `await NotificationService.instance.init()` in `main()`; a single `ref.listen`/sync provider
at the root watches active meso + overrides + reminder settings and calls `rescheduleAll`.

## UI (design tokens + existing widgets throughout)

All screens: `Scaffold(backgroundColor: c.bg)` + `SafeArea`, `AppHeaderBar`, `AppButton`,
`AppIconButton`, `kRadius/kPad/kGap/cardShadow`, `displayStyle/bodyStyle/monoStyle`, bottom
sheets styled like `_DeleteSheet` / appearance picker.

- **`lib/presentation/mesocycle_setup_screen.dart`** — name field; start-date picker (snapped to
  Monday); training/rest-week `CupertinoPicker` wheels (reuse `create_workout.dart` picker
  sheets); seven weekday rows each opening a **workout picker sheet** (workouts list + "Rest day"),
  same workout allowed on multiple days; sticky `AppButton('Save mesocycle')` → save + set active.
- **`lib/presentation/widgets/workout_picker.dart`** — reusable "pick a workout or Rest" sheet
  (used by setup + calendar).
- **`lib/presentation/calendar_screen.dart`** (`ConsumerStatefulWidget`, holds `_visibleMonth`):
  - Header: month/year (`displayStyle`), prev/next `AppIconButton` chevrons, "today" jump, edit-meso icon.
  - **Week-of-meso banner**: `statusForDate(activeMeso, today)` → "WEEK 3 OF 5 · TRAINING" /
    "REST WEEK 1 OF 1", with an inline "Adjust" (set-current-week sheet) and an
    **"Start rest week early"** `AppButton(outline)` (confirm sheet → append early-rest adjustment).
  - **`lib/presentation/widgets/month_grid.dart`**: Monday-first 7-col grid; weekday header;
    day cells (`GestureDetector` → rounded `Container`) showing day number + an accent marker
    when `workoutIdForDate != null`, today ring, faded rest/out-of-month days.
  - **Tap a workout day** → day sheet: **Start** (reuse `w.warmup.isNotEmpty ? WarmupScreen : WorkoutSessionScreen`
    — same branch as `workout_list_screen.dart:166`), **Move to another date** (date picker →
    `overridesProvider.move(from,to)`), **Clear/rest this day**.
  - **Tap a rest day** → day sheet: **Add a workout** (workout picker → `setWorkout` override).
  - Drag-and-drop is deferred; long-press → day-sheet "Move" is the primary reschedule path.
- **`lib/presentation/widgets/reminder_picker.dart`** — labelled "Pre-workout reminder";
  enable toggle + time wheel (the time the user wants to start prepping); on enable, request
  notification permission; writes to `reminderProvider`. No per-day time; one global setting.
- **`lib/presentation/workout_list_screen.dart`** — add two header `IconButton`s (match existing
  history/appearance 36×36, `size: 20, color: c.inkDim`): calendar (`Icons.calendar_today_rounded`)
  and mesocycle (`Icons.event_repeat_rounded` → CalendarScreen if active meso exists, else
  MesocycleSetupScreen). Add the same to `_EmptyState` header for discoverability.

## File-by-file

**New:** `domain/models/mesocycle.dart`, `mesocycle_adapter.dart` (typeId 4),
`domain/models/day_override.dart`, `day_override_adapter.dart` (typeId 5),
`domain/schedule/schedule_logic.dart`, `data/mesocycle_repository.dart`,
`data/override_repository.dart`, `providers/mesocycle_providers.dart`,
`providers/reminder_provider.dart`, `services/notification_service.dart`,
`presentation/calendar_screen.dart`, `presentation/mesocycle_setup_screen.dart`,
`presentation/widgets/month_grid.dart`, `presentation/widgets/workout_picker.dart`,
`presentation/widgets/reminder_picker.dart`, `test/schedule_logic_test.dart`.

**Edited:** `lib/main.dart` (register adapters 4/5, open `mesocycles`+`overrides` boxes,
`NotificationService.init()`, root reminder-sync), `pubspec.yaml` (3 deps),
`android/app/build.gradle.kts` (desugaring), `android/app/src/main/AndroidManifest.xml`
(permissions + receivers), `lib/presentation/workout_list_screen.dart` (header icons).

## Verification

1. `flutter pub get`; `flutter analyze` (watch `Map<int,String?>` JSON keys + null override lookups).
2. `flutter test test/schedule_logic_test.dart` — weekday mapping; rest week suppresses all days;
   cycle repeats after `cycleLen` weeks; `setCurrentWeek` only affects on/after `effectiveDate`
   (pre-adjustment date unchanged); early rest → current week rest, resumes at training week-1;
   overrides (move/clear/add) win over template; pre-anchor floor-mod.
3. User will use the verify skill after all is completed to test the flow.

---

## Bug fixes (applied post-verification)

### Fix 1 — Notification crash on startup

**Root cause:** `AndroidInitializationSettings('ic_launcher')` looks for `ic_launcher` in
`drawable/`, but that file only exists in `mipmap-*/`. The plugin throws
`PlatformException(invalid_icon, ...)`, which propagated unhandled through `main()` and
prevented `runApp()` from ever being called.

**Changes:**
- `lib/services/notification_service.dart` — changed `'ic_launcher'` → `'ic_launcher_foreground'`
  (exists in all `drawable-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/` densities).
- `lib/main.dart` — wrapped `await NotificationService.instance.init()` in `try/catch` so a
  notification init failure can never crash the app (permission may be denied at runtime).

### Fix 2 — CircularDependencyError on mesocycle save

**Root cause:** `activeMesocycleProvider` does `ref.watch(mesocyclesProvider)`. When
`MesocyclesNotifier.save()` calls `_reschedule()` → `rescheduleNotifications(ref)` →
`ref.read(activeMesocycleProvider)`, Riverpod builds `activeMesocycleProvider` from within
the mesocycles notifier's execution context — circular dependency. The error was swallowed
silently, leaving the setup form frozen with no feedback.

**Changes:**
- `lib/providers/mesocycle_providers.dart` — `rescheduleNotifications` no longer reads
  `activeMesocycleProvider`. Instead it reads `mesocyclesProvider` data and `activeMesoIdProvider`
  directly, breaking the cycle.
- `lib/presentation/mesocycle_setup_screen.dart` — `_save` now wraps the save calls in
  `try/catch` and shows a snack-bar on failure so errors are never silent.