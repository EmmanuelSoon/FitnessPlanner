# 016 — Test Coverage

## Progress

- [x] **PR 1 — Test infra + domain layer** — [#37](https://github.com/EmmanuelSoon/FitnessPlanner/pull/37) (branch `test/domain-layer-coverage`)
- [x] **PR 2 — Repository / data layer** — [#39](https://github.com/EmmanuelSoon/FitnessPlanner/pull/39) (branch `test/repository-layer-coverage`)
- [x] **PR 3 — Providers / state notifiers** — [#40](https://github.com/EmmanuelSoon/FitnessPlanner/pull/40) (branch `test/provider-coverage`)
- [x] **PR 4 — Widget tests: core workout flow** — [#41](https://github.com/EmmanuelSoon/FitnessPlanner/pull/41) (branch `test/widget-workout-flow`)
- [ ] PR 5 — Widget tests: calendar, mesocycle, runs, shared widgets

## Context

The app has zero real tests today — `test/widget_test.dart` is an empty stub
(`void main() {}`), and `.github/workflows/flutter_ci.yml` never runs
`flutter test`. `pubspec.yaml` has no mocking library.

Goal: build up test coverage across every layer, broken into a sequence of
PRs that can land independently. Each PR should leave `flutter analyze` and
`flutter test` green and not depend on later PRs' code.

## Layer overview (what exists today)

- **Domain / pure logic** — `lib/domain/schedule/schedule_logic.dart` (meso
  phase math, overrides, rest weeks) and `lib/domain/models/*.dart` (all hand
  -written with `toJson`/`fromJson`, no codegen). No I/O — cheapest, highest
  -value tests.
- **Hive adapters** — `lib/domain/models/*_adapter.dart`, each just
  `json.encode`/`decode`'s the model's `toJson`/`fromJson` through a
  `TypeAdapter`. Exercised naturally by writing to a real (temp-dir) Hive box.
- **Repositories** — `lib/data/*.dart`, thin CRUD wrappers over a single Hive
  `Box<T>` (`WorkoutRepository`, `SessionRepository`, `MesocycleRepository`,
  `OverrideRepository`, `RunOverrideRepository`, `RunRepository`).
- **Providers** — `lib/providers/*.dart`, Riverpod `Notifier`/`AsyncNotifier`
  classes wrapping repositories, plus `shared_preferences`
  (`ActiveMesoIdNotifier`), `NotificationService` rescheduling, theme, and
  reminders.
- **Presentation** — `lib/presentation/*.dart` screens + `presentation/widgets`
  shared widgets. Highest effort per test (needs `ProviderScope` overrides,
  pumping, sometimes fake Hive/services).

## Shared test infrastructure (do this once, in PR 1)

- Add `mocktail` as a dev dependency for faking `NotificationService` /
  `HealthService` in provider and widget tests (repositories themselves are
  simple enough to fake by hand with an in-memory `List`, no mock lib needed).
- `test/support/hive_test_setup.dart` — helper that inits Hive against a temp
  directory (`Directory.systemTemp.createTempSync()`), registers all 8
  adapters (mirroring `main.dart`), and tears down/deletes the temp dir. Used
  by repository tests and any provider/widget test that needs a real box.
- `test/support/fixtures.dart` — small builder functions for the recurring
  test objects (a `Mesocycle`, a `Workout` with a superset, a `WorkoutSession`,
  a `RunSession`, `DayOverride`/`RunOverride`) so later PRs aren't repeating
  boilerplate.
- Add a `flutter test` step to `.github/workflows/flutter_ci.yml` (before the
  `Build APK` step) so coverage from PR 1 onward is enforced in CI.

## PR 1 — Test infra + domain layer — DONE ([#37](https://github.com/EmmanuelSoon/FitnessPlanner/pull/37))

Landed scoped down from the shared-infra section above: `mocktail` and the
Hive temp-dir helper aren't used by any PR-1 test, so they were deferred to
PR 2/PR 3 (added exactly when first consumed) rather than carried as unused
infrastructure. Only the CI `flutter test` step landed in PR 1.
`exercise_library_test.dart` only checks the preset list is well-formed —
the keyword search itself lives in `exercise_library_picker.dart` (a
widget), not in the domain layer, so that test moved to PR 5.

- Wire up the shared infra above.
- `test/domain/schedule/schedule_logic_test.dart`:
  - `mondayOf`, `normalizeDate`.
  - `cycleWeekIndexForDate` / `isRestWeek`: no adjustments, dates before
    `originalAnchor` (negative floor-mod), an `earlyRest` adjustment, a
    `setCurrentWeek` adjustment, and two adjustments where the later one
    should win.
  - `statusForDate` label text for training week, single rest week, and
    multi-week rest block.
  - `workoutIdForDate` / `plannedRunForDate`: no override + training week, no
    override + rest week (suppressed), `setWorkout`/`rest` override wins over
    template, `setRun`/`clearRun` override wins over template.
  - `earlyRestAdjustment` / `setCurrentWeekAdjustment` construction.
- `test/domain/models/*_test.dart` — `toJson`/`fromJson` round-trip for every
  model: `Mesocycle` (incl. nested `CycleAdjustment`, `weekdayRuns`,
  `adjustments`), `DayOverride`, `RunOverride`, `PlannedRun`, `RunSession`,
  `LoggedSet`, `Workout`/`Exercise`/`Superset`, `WorkoutSession`,
  `DefaultWarmup`. Cover nullable/optional fields explicitly (e.g. bodyweight
  exercise with no weight, no adjustments list).
- `test/domain/models/exercise_library_test.dart` — the preset list is
  well-formed (unique ids/names) and the keyword search returns expected
  matches/misses.

## PR 2 — Repository / data layer

Adds `test/support/hive_test_setup.dart` (deferred from PR 1, see above).
Using that temp-dir Hive helper, for each of `WorkoutRepository`,
`SessionRepository`, `MesocycleRepository`, `OverrideRepository`,
`RunOverrideRepository`, `RunRepository`:
- `getAll()` returns `[]` on an empty box.
- `save()` then `getAll()`/`get()` round-trips a fixture through the real
  `TypeAdapter` (this is what actually exercises each adapter's `read`/`write`
  — no separate adapter tests needed).
- `delete()` removes it.
- Any repository-specific query methods (e.g. `OverrideRepository.forMeso`,
  `.get`, `.clear`; `SessionRepository.getAll()` sort order by `startedAt`).

## PR 3 — Providers / state notifiers — DONE

Adds `mocktail` as a dev dependency (deferred from PR 1, see above).

Deviation from the plan: `NotificationService.instance` was a hard `static
final` singleton called directly from `mesocycle_providers.dart`, with no
seam for `ProviderScope` to substitute a mocktail fake. Added a small
`notificationServiceProvider` in `notification_service.dart` and changed
`rescheduleNotifications` to read it via `ref.read(...)` instead of the
static singleton — the only production-code change in this PR. `main.dart`'s
`init()` call and `reminder_picker.dart`'s `requestPermissions()` call were
left untouched (out of scope, not exercised by these tests).

`HealthService` is only called from `run_list_screen.dart` (a widget), not
from `run_providers.dart` itself, so it wasn't mocked here — that's PR 4/5's
concern instead.

- Hand-write in-memory fakes for each repository (implement the same public
  methods backed by a `Map`/`List`) rather than hitting real Hive — keeps
  these tests fast and focused on notifier logic, not persistence (already
  covered in PR 2).
- Use `mocktail` to fake `NotificationService` (verify `rescheduleAll` is
  called with expected args after mutations) and `HealthService` where
  `run_providers` touches it.
- Use `ProviderContainer` with provider overrides (repository providers →
  fakes, `sharedPreferencesProvider` or `SharedPreferences.setMockInitialValues({})`).
- Tests per provider file:
  - `workout_providers.dart` — CRUD + list reflects repository state.
  - `mesocycle_providers.dart` — `ActiveMesoIdNotifier` persistence,
    `MesocyclesNotifier` save/delete/`appendAdjustment` (dedup by
    `effectiveDate`, sort order), `OverridesNotifier` and `RunOverridesNotifier`
    set/clear/`move`/`moveRun`, and that mutations trigger a reschedule.
  - `run_providers.dart`, `session_providers.dart` — CRUD + derived state.
  - `reminder_provider.dart`, `theme_provider.dart` — state persistence.

## PR 4 — Widget tests: core workout flow — DONE

Using `ProviderScope`/`ProviderContainer` overrides with the PR 3 fakes:
- `create_workout.dart` — form validation (required fields, optional weight),
  saving a workout with a superset.
- `workout_list_screen.dart` — renders saved workouts, edit and delete
  actions.
- `workout_start_preview_screen.dart` → `workout_session_screen.dart` —
  stepping through exercises, finish-exercise starts rest timer, skip
  exercise, pause/resume, adjusting reps/weight on the fly.
- `workout_complete_screen.dart` — summary totals (time, volume) match the
  session logged.
- `history_screen.dart` / `session_detail_screen.dart` — list of past
  sessions, logged sets shown per exercise.

Findings while implementing (no production code changed in this PR):
- `workout_session_screen.dart` calls `WakelockPlus`/`AudioPlayer`/
  `Vibration` directly with no platform channel mocked under `flutter_test`.
  Verified empirically (a throwaway probe test) that this never throws or
  fails a test — no mock channel setup was needed, contrary to the original
  plan assumption.
- `flutter_test`'s default 800×600 surface, and even a real device width
  (~412), overflow several screens (`workout_session_screen.dart`'s hero
  numbers, `workout_complete_screen.dart`'s headline) because the app's
  custom fonts (SpaceGrotesk/Manrope) aren't loaded under test, so text
  falls back to a substitute font with wider glyph metrics than production.
  `test/support/pump_app.dart`'s shared `pumpApp` helper sets a wider-than-
  device 600×915 surface by default to route around this test-only
  artifact — it is not a real layout bug.
- `WorkoutStartPreviewScreen` reads `sessionsProvider` synchronously in
  `initState` to prefill reps/weight from the last session. A fresh
  `ProviderScope` hasn't resolved that provider by the first frame, so
  `pumpApp` also accepts a pre-built `container` (warmed with
  `await container.read(sessionsProvider.future)` first) for screens with
  this pattern.

## PR 5 — Widget tests: calendar, mesocycle, runs, shared widgets

- `calendar_screen.dart` + `widgets/month_grid.dart` — month navigation, day
  indicators for workouts/runs, override actions (set/rest/move) drive the
  fakes from PR 3.
- `mesocycle_setup_screen.dart` — creation wizard, early-rest / set-current-
  week actions.
- `warmup_screen.dart` — countdown / beep trigger points (fake the audio
  service if needed).
- `record_run_screen.dart`, `run_list_screen.dart`, `run_detail_screen.dart` —
  manual entry form validation, list rendering, detail display.
- Remaining shared widgets (`workout_picker`, `reminder_picker`,
  `exercise_library_picker`, `number_picker_sheet`, `appearance_picker`,
  `session_breakdown`) — one focused test each for their core interaction.

## Notes / open questions to confirm before/while implementing

- `mocktail` will be added as a new dev dependency (PR 3, deferred from the
  original PR 1 plan) — flag this in the PR description since it's a new
  package, not just tests.
- Widget tests (PR 4/5) skip real Hive and real `NotificationService`/`health`
  plugin calls by construction (fakes/mocks), so they won't catch adapter or
  plugin-channel issues — that's intentionally covered by PR 2 instead.
- Not in scope: golden/screenshot tests, integration (`integration_test`)
  tests driving a real device — flag separately if wanted later.
