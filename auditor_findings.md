# Auditor Findings — Code Clarity & Design Review

Date: 2026-09-07
Scope: full `lib/` codebase review (architecture, duplication, test coverage, lint hygiene). No code changes were made — this is a read-only assessment for future planning.

## What's healthy

- Clean layering — `domain/` (pure models/logic), `data/` (Hive repos), `providers/` (Riverpod), `presentation/` are well separated, and `main.dart` is a tidy composition root.
- Strong test discipline — 60+ test files, near 1:1 coverage of domain/data/provider files, TDD conventions are actually followed (per plans/016).
- No lint suppressions, no TODOs/FIXME, no stray `print`s — the codebase is disciplined about not accumulating debt markers.
- Domain logic (schedule_logic, insights calculators) is properly separated from widgets and independently tested.

## Findings, in suggested priority order

### 1. Override/RunOverride duplication (data + provider layers)

`lib/data/override_repository.dart` and `lib/data/run_override_repository.dart` are byte-for-byte identical except for the type name — same `_key()` date-hashing logic, same CRUD shape (`get`/`forMeso`/`save`/`clear`).

The same mirroring repeats one layer up in `lib/providers/mesocycle_providers.dart`: `OverridesNotifier` and `RunOverridesNotifier` are near-duplicate state machines (one comment literally says "Mirrors OverridesNotifier.move for workouts").

**Suggestion:** a generic `HiveRepository<T>` (keyed by an extractor function) would collapse both repo pairs into one implementation, and likely simplify the notifier pair too. Low risk, high value — best refactor-to-effort ratio in the repo.

### 2. Four "god screens"

- `lib/presentation/create_workout.dart` — 1,676 lines, 10 classes
- `lib/presentation/workout_session_screen.dart` — 1,315 lines
- `lib/presentation/calendar_screen.dart` — 1,001 lines, single 838-line state class
- `lib/presentation/insights_screen.dart` — 946 lines

These mix state management, business logic, and multiple widget definitions in one file.

Concretely, in `create_workout.dart`, `_WarmupExerciseCardState` and `_ExerciseSlotCardState` are near-identical (`_setTimed`/`_toggleMode`/`_rename`/`_applyTemplate` duplicated almost verbatim) — candidates for unifying into one configurable widget rather than two parallel ones.

**Suggestion:** split each of these four files into `screen.dart` + `widgets/*.dart` per logical section. Consider pulling multi-step form state (create_workout, mesocycle_setup) into a dedicated controller/notifier so the widget classes shrink to layout only. Treat this as an ongoing "extract rather than add" policy when touching these screens, rather than a dedicated big-bang refactor sprint — restructuring 1,600-line files in one PR is risky.

### 3. Date-key formatting duplicated and inconsistent

The `'${d.year}-${d.month}-${d.day}'`-style day-key logic is duplicated across 13 files, with inconsistent zero-padding between them — e.g. `lib/data/override_repository.dart` pads (`month.toString().padLeft(2, '0')`), `lib/data/run_repository.dart` does not.

Not currently a bug (each use is self-contained), but a landmine for the next person who compares or persists one of these keys across call sites. `lib/domain/format.dart` already exists as the natural home for shared formatting — it currently has exactly one function (`formatClock`).

**Suggestion:** add a `dateKey(DateTime)` function to `format.dart` and do a mechanical sweep of the 13 call sites.

Files touching this pattern: `workout_complete_screen.dart`, `create_workout.dart`, `workout_start_preview_screen.dart`, `record_run_screen.dart`, `calendar_screen.dart`, `workout_session_screen.dart`, `widgets/number_picker_sheet.dart`, `widgets/month_grid.dart`, `run_detail_screen.dart`, `data/run_override_repository.dart`, `data/run_repository.dart`, `data/override_repository.dart`, `domain/format.dart`.

### 4. Platform-integration services are untestable as written

`lib/services/health_service.dart` and `lib/services/notification_service.dart` are the only non-trivial files with zero test coverage — not an oversight, but a design gap: both call their plugin (`Health()`, the notifications plugin) as a static singleton directly, so there's nothing to inject a fake into.

Given how seriously this repo otherwise enforces TDD, this is the one place the architecture is actively fighting the testing convention.

**Suggestion:** wrap the plugin calls behind a small interface (doesn't need to abstract the plugin itself, just the mapping/scheduling logic around it) so the parts that actually have bugs in practice — mapping plugin data to domain models, reminder scheduling — can be unit-tested.

## Non-findings (checked, ruled out)

- `lib/theme/app_theme.dart` (542 lines) — large but mostly color-token data (`AppColorThemeDef` spans ~270 lines), not logic. Not a concern.
- Test coverage gaps otherwise are limited to `main.dart`, `format.dart` (trivial), `widgets/app_widgets.dart`, `widgets/month_grid.dart` — all low-risk, presentational, or trivial enough that the gap isn't urgent.

## Suggested sequencing

1. Finding #1 (repo/notifier consolidation) — contained, mechanical, immediately shrinks the codebase.
2. Finding #3 (date-key centralization) — touches overlapping files, natural to bundle with #1.
3. Finding #4 (testable service wrappers).
4. Finding #2 (god screens) — ongoing policy rather than a dedicated sprint.
