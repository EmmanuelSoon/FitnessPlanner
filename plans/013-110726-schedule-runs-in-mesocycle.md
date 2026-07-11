# Schedule Run Days in a Mesocycle

## Context

The mesocycle feature lets users lay out a weekly strength-training template
(`Mesocycle.weekdayWorkouts`, 1=Mon..7=Sun → workoutId) that auto-fills the
calendar. Runs today are only ever *logged after the fact* (`RunSession` +
`RecordRunScreen`); there is no way to **plan** a run as part of a training block.

This feature adds **planned run targets** to the weekly template — a run type
(Easy/Tempo/Interval/Long/Race/Other) plus optional distance and duration
targets — assigned per weekday alongside strength days. Planned runs show on the
calendar, can be moved/cleared on individual dates (like workouts), pre-fill the
"Log a run" screen when the user actually does the run, and are included in the
daily reminder notification.

Decisions confirmed with the user:
- Target captures **type + distance + duration** (distance & duration optional).
- Planned runs are **suppressed during rest/deload weeks** (same as workouts).
- **Full per-date overrides** (move/clear a planned run on a specific date).
- Daily reminders **include planned runs**.

## Design overview

Mirror the existing workout-template + per-date-override architecture exactly,
so run planning reuses proven patterns and leaves workout code untouched:

| Workouts (existing)                     | Runs (new, parallel)                    |
|-----------------------------------------|-----------------------------------------|
| `Mesocycle.weekdayWorkouts: Map<int,String?>` | `Mesocycle.weekdayRuns: Map<int,PlannedRun?>` |
| `DayOverride` (box `overrides`, typeId 5) | `RunOverride` (box `run_overrides`, typeId 6) |
| `workoutIdForDate(m, ov, date)`         | `plannedRunForDate(m, ov, date)`        |
| `OverridesNotifier` / `overridesProvider` | `RunOverridesNotifier` / `runOverridesProvider` |

## 1. Data model

### New `PlannedRun` — `lib/domain/models/planned_run.dart` (new file)
Nested value object (serialized inside Mesocycle/RunOverride JSON — **no Hive
adapter/typeId of its own**). Reuses the existing `RunType` enum from
`run_session.dart`. Adds a `summaryLabel` helper (e.g. `"Easy · 5.0 km · 30 min"`,
omitting absent parts) reused across setup screen, calendar cell, and day sheet.

### `Mesocycle` — `lib/domain/models/mesocycle.dart`
Add `final Map<int, PlannedRun?> weekdayRuns;` alongside `weekdayWorkouts`:
- constructor: `this.weekdayRuns = const {}` (default → backward compatible),
- `copyWith` gains `weekdayRuns`,
- `toJson`: emit `weekdayRuns` as `{weekdayString: plannedRun.toJson()|null}`,
- `fromJson`: parse with `?? {}` default so **old stored mesocycles load fine**.
- **No change to `MesocycleAdapter` (typeId 4)** — it just wraps the JSON string.

### New `RunOverride` — `lib/domain/models/run_override.dart` (new file)
Mirror `day_override.dart`: `enum RunOverrideKind { setRun, clearRun }` and
`RunOverride { mesocycleId, date, kind, plannedRun? }` with toJson/fromJson.
New adapter `run_override_adapter.dart` — copy of `DayOverrideAdapter` with
`typeId = 6` (JSON-string wrapper). typeIds 0–5 are taken; 6 is free.

## 2. Schedule logic — `lib/domain/schedule/schedule_logic.dart`
Add `plannedRunForDate(Mesocycle m, RunOverride? ov, DateTime date)` mirroring
`workoutIdForDate`: override wins (clearRun → null); else null on rest weeks;
else `m.weekdayRuns[date.weekday]`.

## 3. Persistence wiring — `lib/main.dart`
- `Hive.registerAdapter(RunOverrideAdapter());`
- `await Hive.openBox<RunOverride>('run_overrides');`

## 4. Repository + providers

### `lib/data/run_override_repository.dart` (new)
Copy `override_repository.dart` retyped to `RunOverride`, box `'run_overrides'`;
expose `runOverrideRepositoryProvider`.

### `lib/providers/mesocycle_providers.dart`
Add `RunOverridesNotifier` / `runOverridesProvider` mirroring `OverridesNotifier`:
`setRun(date, PlannedRun)`, `clearRun(date)`, `moveRun(from, to, PlannedRun)`
(clearRun on `from` + setRun on `to`), `clearOverride(date)`. Each calls
`_reschedule()` so reminders stay in sync. Watches `activeMesocycleProvider`.

## 5. UI

### Setup screen — `lib/presentation/mesocycle_setup_screen.dart`
- Add state `late Map<int, PlannedRun?> _weekdayRuns;` (init from
  `existingMeso?.weekdayRuns ?? {}`; else empty).
- In **WEEKLY SCHEDULE**, under each day's workout `_InfoRow`, add a compact
  **"Run"** `_InfoRow` showing `plannedRun?.summaryLabel ?? 'None'` (tinted
  `c.accent` when set). Tapping opens a run-target picker bottom sheet.
- New `_showRunTargetSheet`: RunType chips (reuse chip visual from
  `record_run_screen.dart`), distance km field, duration (minutes) field,
  **Remove run**, and **Done**. Writes into `_weekdayRuns[weekday]`.
- `_save`: include `weekdayRuns: Map.from(_weekdayRuns)`.

### Calendar cell — `lib/presentation/widgets/month_grid.dart`
- Add param `PlannedRun? Function(DateTime) plannedRunForDate` (computed in
  `CalendarScreen`, matching how `overrideForDate` is passed in).
- In `_DayCell`, when a planned run exists show a small run marker distinct from
  the logged-run shoe: outlined/dim `Icons.directions_run_rounded` (`c.inkMute`)
  for planned-not-yet-logged; existing filled shoe still means a logged run.

### Calendar day sheet — `lib/presentation/calendar_screen.dart`
- Watch `runOverridesProvider`; build `runOverrideMap` keyed by `_dateKey`. Pass
  `plannedRunForDate` into `MonthGrid` and the planned run + override into
  `_showDaySheet`.
- Add a **PLANNED RUN** section with actions mirroring workouts: **Log this run**
  (→ prefilled `RecordRunScreen`), **Move run to another date** (→ `moveRun`),
  **Clear run** (→ `clearRun`), **Reset run to scheduled** when an override exists
  (→ `clearOverride`). Existing ad-hoc "Log a run" button stays.

### Record run prefill — `lib/presentation/record_run_screen.dart`
- Add optional ctor params `initialRunType`, `initialDistanceMeters`,
  `initialDuration`. Seed `_runType`, `_distanceCtrl`, duration fields in the
  not-editing branch. Backward-compatible with existing callers.

## 6. Notifications — `lib/services/notification_service.dart` + providers
- `rescheduleAll` gains `PlannedRun? Function(DateTime) plannedRunForDate`; per
  day resolve workout + run, skip only when both null, and build a combined body
  (e.g. `"Push Day + Easy run · 5 km"`, `"Easy run · 5 km"`, or just workout).
- `rescheduleNotifications` reads the run-override repo + active meso and passes a
  `plannedRunForDate` closure.

## 7. Tracking doc — `Feature_tracking.md`
Flip line 47 to `- [x] Schedule run days in a mesocycle …`.

## Files

**New:** `lib/domain/models/planned_run.dart`,
`lib/domain/models/run_override.dart`,
`lib/domain/models/run_override_adapter.dart`,
`lib/data/run_override_repository.dart`.

**Modified:** `mesocycle.dart`, `schedule_logic.dart`, `main.dart`,
`mesocycle_providers.dart`, `mesocycle_setup_screen.dart`, `month_grid.dart`,
`calendar_screen.dart`, `record_run_screen.dart`, `notification_service.dart`,
`Feature_tracking.md`.

## Verification

1. `flutter analyze` clean.
2. Run on device (adb / `release-phone` skill).
3. **Backward compat:** launch with an existing stored mesocycle → loads fine,
   `weekdayRuns` empty, calendar unchanged.
4. **Create:** assign a workout + Easy 5 km / 30 min run to a weekday → save.
   Calendar shows both markers; rest-week days show neither.
5. **Log from target:** tap a run day → "Log this run" → `RecordRunScreen` opens
   pre-filled with Easy + 5.00 km; save → logged run appears on that day.
6. **Override:** move/clear a planned run; "Reset run to scheduled" restores it.
7. **Reminder:** enable reminders → run/combined day notification body mentions
   the run.
