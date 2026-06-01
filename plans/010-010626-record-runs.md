# 010 — Record Runs (manual entry + Samsung/Health Connect import)

## Context

The app (internally "PlateUp") today is strength-training only: Workout → Superset →
Exercise templates, logged as `WorkoutSession`/`LoggedSet`, scheduled via `Mesocycle` +
`DayOverride`. There is **no** cardio/run concept and **no** health-platform integration.

The user tracks runs on a Samsung watch and wants those runs to also live in this app.
Decisions from the planning conversation:
- **Both** import paths: auto-import from Android **Health Connect** (Samsung Health writes
  runs there) **and** manual entry / editing.
- Fields: distance, duration, pace (derived), avg heart rate, calories, cadence, notes, run type.
- Runs should appear **on the existing month calendar** alongside workouts, plus in a dedicated runs list.

Outcome: a new "Runs" vertical that mirrors the existing `WorkoutSession` →
`SessionRepository` → `sessionsProvider` → `HistoryScreen` stack, a Health Connect sync
service, and run indicators on the calendar.

> **Cadence caveat:** the Flutter `health` package does not cleanly expose running cadence
> from Health Connect. Cadence will be **manual-entry only** (optionally approximated from
> steps ÷ minutes when steps are available). All other fields import directly.

---

## Part A — Data layer (mirror the WorkoutSession stack)

Reuse the established pattern exactly: plain model + hand-written JSON `toJson`/`fromJson`,
a Hive `TypeAdapter` that JSON-encodes to a string, a thin repository, and an
`AsyncNotifierProvider`.

### 1. `lib/domain/models/run_session.dart` (new)
Immutable class modeled on `lib/domain/models/workout_session.dart`:

| Field | Type | Serialization (follow existing conventions) |
|-------|------|----------------------------------------------|
| `id` | `String` | auto-gen `DateTime.now().microsecondsSinceEpoch.toString()` like `Superset` |
| `startedAt` / `endedAt` | `DateTime` | ISO-8601 (`toIso8601String()` / `DateTime.parse`) |
| `movingTime` | `Duration` | `'movingTimeMicroseconds'` int (the `...Microseconds` convention from `exercise.dart`) |
| `distanceMeters` | `double` | `(json['distanceMeters'] as num).toDouble()` defensive cast |
| `avgHeartRate` | `int?` | nullable int |
| `calories` | `double?` | `(json['calories'] as num?)?.toDouble()` |
| `cadenceSpm` | `int?` | nullable int (manual) |
| `runType` | `RunType` enum | `type.name` / `RunType.values.byName(...)` (enum-by-name, like `OverrideKind`) |
| `notes` | `String?` | nullable string |
| `source` | `RunSource` enum `{ manual, healthConnect }` | enum-by-name; used to gate editing/dedup |
| `externalId` | `String?` | Health Connect record UUID for dedup |

Derived getters (no storage), mirroring `WorkoutSession.duration`:
- `Duration get duration => movingTime;`
- `Duration get pacePerKm` → `movingTime.inSeconds / (distanceMeters / 1000)` seconds, returned as a `Duration`; guard divide-by-zero.

`enum RunType { easy, tempo, interval, long, race, other }` in the same file.

### 2. `lib/domain/models/run_session_adapter.dart` (new)
Copy `workout_session_adapter.dart` verbatim; set **`typeId = 6`** (next free id — 0–5 are taken).

### 3. `lib/data/run_repository.dart` (new)
Copy `lib/data/session_repository.dart`. Box name `'runs'`, sorted `startedAt` desc.
Add a dedup helper for import:
```dart
bool exists(String id) => _box.containsKey(id);
List<RunSession> forDate(DateTime d); // filter by local Y-M-D, for calendar/day-sheet
```
Expose `runRepositoryProvider` like `sessionRepositoryProvider`.

### 4. `lib/providers/run_providers.dart` (new)
Copy `lib/providers/session_providers.dart`: `runsProvider`
(`AsyncNotifierProvider<RunsNotifier, List<RunSession>>`) with `saveRun` / `deleteRun`
using `invalidateSelf()` + `await future`.

### 5. `lib/main.dart` (edit)
Add next to the existing registrations/box-opens (lines 26–35):
```dart
Hive.registerAdapter(RunSessionAdapter());
await Hive.openBox<RunSession>('runs');
```

---

## Part B — Health Connect import

### Dependency
Add to `pubspec.yaml`: the `health` package (latest, `^13.x` or newer — verify on pub.dev at
implementation time; it is the maintained Health Connect bridge).

### Android setup (required — Health Connect will not work without all four)
1. **`android/app/build.gradle.kts`** — Health Connect requires **minSdk 26**. The current
   `minSdk = flutter.minSdkVersion` is likely below that. Override to `minSdk = 26`
   (keep `targetSdk`/`compileSdk` from Flutter). Desugaring is already enabled (line 14).
2. **`MainActivity.kt`** — change `FlutterActivity` → `FlutterFragmentActivity`
   (the `health` plugin's permission UI requires a FragmentActivity host):
   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity
   class MainActivity : FlutterFragmentActivity()
   ```
3. **`AndroidManifest.xml`** — add read permissions, package visibility, and the rationale
   handler. Representative additions:
   ```xml
   <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
   <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
   <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
   <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
   <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
   <uses-permission android:name="android.permission.health.READ_STEPS"/>

   <!-- inside <application>: privacy-policy / rationale entry point -->
   <activity-alias
       android:name="ViewPermissionUsageActivity"
       android:exported="true"
       android:targetActivity=".MainActivity"
       android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
       <intent-filter>
           <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
           <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
       </intent-filter>
   </activity-alias>

   <!-- also add the rationale action to the existing MainActivity intent-filter set -->
   <intent-filter>
       <action android:name="androidx.health.connect.action.SHOW_PERMISSIONS_RATIONALE"/>
   </intent-filter>
   ```
   Add to the existing top-level `<queries>` block:
   ```xml
   <package android:name="com.google.android.apps.healthdata"/>
   ```

### `lib/services/health_service.dart` (new)
Wrap the `health` package (singleton, mirroring `NotificationService.instance` style in
`lib/services/notification_service.dart`):
- `requestAuthorization()` — request READ for the exercise/distance/HR/calories/steps types.
- `Future<List<RunSession>> fetchRuns({required DateTime since})`:
  1. Query `HealthDataType.WORKOUT`; keep entries whose activity type is RUNNING (and
     walking/hiking optionally — confirm with user later, default RUNNING only).
  2. For each workout window, read distance, avg of `HEART_RATE`, calories
     (TOTAL/ACTIVE), and steps within `[start, end]`.
  3. Map to `RunSession` with `source: RunSource.healthConnect`,
     `id: 'hc_<recordUuid>'`, `externalId: recordUuid`, `cadenceSpm` derived from
     steps ÷ minutes if steps present else null.
- Graceful failure: if Health Connect is unavailable/denied, surface a message and fall
  back to manual entry (wrap in try/catch like the notification init in `main.dart`).

Import flow saves via `runsProvider.notifier.saveRun(...)`, skipping any run whose `id`
already exists (`runRepository.exists`) so repeated syncs don't duplicate.

---

## Part C — UI (mirror history/create screens + theme tokens)

All screens use existing tokens: `AppThemeData.of(context).c`, `displayStyle/bodyStyle/monoStyle`,
`AppHeaderBar`, `AppIconButton`, `AppButton`, `AppFab`, `kRadius`, `kPad`, `cardShadow` from
`lib/presentation/widgets/app_widgets.dart` and `lib/theme/app_theme.dart`.

### 1. `lib/presentation/run_list_screen.dart` (new)
Copy `lib/presentation/history_screen.dart`. Watches `runsProvider`, `.when(loading/error/data)`,
`ListView.separated` of `_RunCard`s. Header has a back button + a **"Sync"** `AppIconButton`
(`Icons.sync_rounded`) that calls the health service and a `+` `AppFab` that pushes
`RecordRunScreen`. Each card shows date, distance, duration, pace, and a small source badge
(manual vs watch). Tap → `RunDetailScreen`; long-press / sheet → delete via
`runsProvider.notifier.deleteRun(id)` (reuse the bottom-sheet delete pattern from `history_screen.dart`).

### 2. `lib/presentation/record_run_screen.dart` (new)
Copy the `StatefulWidget` form pattern from `lib/presentation/create_workout.dart`
(local `setState` buffer, `TextEditingController`s disposed in `dispose`, validation via
`ScaffoldMessenger.showSnackBar`). Takes optional `RunSession existingRun` for edit.
Inputs: date/time (`showDatePicker` + time), distance, duration, avg HR, calories, cadence,
run-type chips (`RunType`), notes. Pace shown live (read-only, derived). On save build a
`RunSession` (`source: manual`) and call `runsProvider.notifier.saveRun`.
*Editing an imported run is allowed but keep `source`/`externalId` so it isn't re-imported.*

### 3. `lib/presentation/run_detail_screen.dart` (new)
Copy `lib/presentation/session_detail_screen.dart` layout; show all fields + Edit/Delete.

### 4. Entry point — `lib/presentation/workout_list_screen.dart` (edit)
Add a **"Runs"** `AppIconButton` (e.g. `Icons.directions_run_rounded`) to the header `Row`
(~lines 88–137, next to the existing History/Calendar buttons) that pushes `RunListScreen`.

### 5. Calendar integration — `lib/presentation/widgets/month_grid.dart` + `lib/presentation/calendar_screen.dart` (edit)
- `CalendarScreen.build`: watch `runsProvider`, build `Map<String, List<RunSession>> runsByDay`
  keyed by the existing `_dateKey(date)` helper (line 454), and pass it to `MonthGrid`.
- `MonthGrid` / `_DayCell`: accept `Map<String, List<RunSession>> runsByDay` and render a
  distinct run indicator in the cell (e.g. a small run glyph or a second accent dot) when a
  day has runs — additive to the existing workout dot at lines 186–211. Keep cell height fixed.
- The grid currently only renders when `meso != null` (the `_NoMesoState` branch). Relax this
  so the month grid also renders when there are runs in view, so runs show even with no
  active mesocycle.
- `_showDaySheet`: when the tapped day has runs, list them (tap → `RunDetailScreen`) and add an
  **"Add run"** `AppButton` that pushes `RecordRunScreen` pre-filled with that date — reuse the
  existing sheet scaffold (drag handle, `c.surface`, `kRadius`).

---

## Files summary

**New:** `domain/models/run_session.dart`, `domain/models/run_session_adapter.dart`,
`data/run_repository.dart`, `providers/run_providers.dart`, `services/health_service.dart`,
`presentation/run_list_screen.dart`, `presentation/record_run_screen.dart`,
`presentation/run_detail_screen.dart`.

**Edit:** `main.dart`, `pubspec.yaml`, `android/app/build.gradle.kts`,
`android/app/src/main/kotlin/.../MainActivity.kt`,
`android/app/src/main/AndroidManifest.xml`, `presentation/workout_list_screen.dart`,
`presentation/calendar_screen.dart`, `presentation/widgets/month_grid.dart`.

---

## Verification

1. `flutter pub get` then `flutter analyze` — no new issues.
2. **Manual entry (no health setup needed):** run on the phone
   (`release-phone` skill / `flutter run`), open Runs → `+`, add a run with all fields,
   confirm it appears in the list, on the calendar for that date, and persists across an
   app restart (Hive). Edit and delete it.
3. **Health Connect import (physical Samsung device):** ensure Samsung Health → Settings →
   Health Connect sync is enabled and at least one recorded run has synced. In-app tap
   **Sync**, accept the Health Connect permission prompt, confirm the run imports with the
   correct distance/duration/pace/HR/calories and a "watch" source badge. Tap **Sync** again
   and confirm **no duplicates** (dedup by `externalId`). Cadence is expected blank/approximate.
4. **Calendar:** confirm run indicators render on the correct days, including with no active
   mesocycle, and that the day sheet lists runs + offers "Add run".
5. Regression: existing workout logging, history, and calendar (workout dots, day sheet
   start/move/clear) still behave as before.

## Risks / notes
- Health Connect availability varies by device/OS; the app must degrade gracefully to manual
  entry (the import is additive, never blocking).
- `minSdk` bump to 26 drops pre-Android-8 devices (negligible in 2026).
- Confirm exact `health` package API names at implementation time — they shift across major versions.
