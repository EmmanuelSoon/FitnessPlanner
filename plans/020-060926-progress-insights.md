# 020 — Progress & Insights (replaces History tab)

## Progress

- [x] **PR 1 — Insights tab shell + per-exercise strength trend**
- [x] **PR 2 — Volume over time (tonnage / reps)**
- [x] **PR 3 — Personal records**
- [ ] **PR 4 — Running trends**
- [ ] **PR 5 — Surface new PRs on Workout Complete**

## Context

The History tab (flat chronological session list) overlaps with Calendar,
which already shows sessions/runs per day via an inline day panel. This
replaces History with an **Insights** tab: per-exercise strength trend
charts, volume trends, personal records, and running trends.

Source of truth for the visual design: a Claude Design project
(`c3651a86-ce90-439b-aeac-0317ac8b6f08`, files `insights.jsx` + `theme.jsx`),
pulled via `DesignSync`. Its color/type system (`theme.jsx`'s `QUIET_THEMES`)
is the same 8-theme palette already in `lib/theme/app_theme.dart` — no
palette work needed. `insights.jsx` is treated as a spec, not copied
verbatim (it's React/CSS; we build native Flutter widgets matching its
layout, spacing, and component language).

**Decisions already made** (see prior conversation):
- Delete-session moves from History's list to `session_detail_screen.dart`
  (only place History uniquely provided delete). The old flat list survives
  in a much smaller role: an "All sessions" screen, reached via a row-link
  at the bottom of Insights, matching `insights.jsx`'s `ScreenAllSessions` /
  `RowLink`.
- Personal records match the design's full 6-type set: heaviest weight,
  most reps, longest hold, best est. 1RM (Epley), session tonnage, fastest
  running pace — not just the original 3 (heaviest/most-reps/longest-hold).
- PRs also surface on the Workout Complete screen the moment they're set
  (design's `ScreenCompletePR`), as a separate phase (PR 5) since it touches
  `workout_complete_screen.dart`, outside the tab itself.

**Important prior lesson (plan 019, PR #52):** a single-session tonnage
figure (`"12.4t"` with no comparison point) was removed from the workout
preview screen as "utterly useless" in isolation. `insights.jsx` reuses that
same number in two places — but both add the comparison that was missing:
the volume chart shows tonnage **against an 8-week trend line**, and the PR
list shows session tonnage **as a record with a delta vs. the previous
best** ("+1.2 t on previous best"). PR 5's Workout Complete screen keeps
this in mind explicitly: it must **not** re-add a bare tonnage stat chip
next to Duration/Sets (that's the exact thing removed) — the tonnage number
is only allowed back in when it's contextualized as a PR delta or a trend
point, never a lone figure.

## Data model recap (no changes needed)

- `WorkoutSession` (`lib/domain/models/workout_session.dart`): `sets: List<LoggedSet>`, `startedAt`.
- `LoggedSet` (`lib/domain/models/logged_set.dart`): `exerciseName`, `actualReps`, `actualWeight`, `skipped`, `heldSeconds?`. No exercise category flag — classify per set: `heldSeconds != null` → timed hold; else `actualWeight > 0` → weighted; else → bodyweight reps. (Same classification `session_breakdown.dart`'s `_setLine` already uses.)
- `RunSession` (`lib/domain/models/run_session.dart`): `distanceMeters`, `duration`, `pacePerKm`, `startedAt`.
- `SessionRepository.getAll()` / `RunRepository.getAll()` both return **newest-first**; trend calculators must reverse to chronological order.

## New domain layer — `lib/domain/insights/`

Pure functions/classes, no Flutter imports, so they're cheap to unit test
(consistent with how `schedule_logic.dart` is tested).

- `exercise_trend.dart` — `List<ExerciseTrendPoint> computeExerciseTrend(List<WorkoutSession> sessions, String exerciseName)`. One point per session that logged the exercise (chronological), classified per the rule above: weighted → max `actualWeight` among performed sets that session ("Top set", kg); bodyweight → max `actualReps` ("Best set", reps); timed → max `heldSeconds` ("Longest hold", s). Also `List<String> exerciseNamesLogged(List<WorkoutSession>)` for the chip picker, ordered by most recent use.
- `volume_stats.dart` — `List<WeekVolume> weeklyVolume(List<WorkoutSession> sessions, {int weeks = 8})`: per ISO week, `tonnageKg` (Σ `actualWeight * actualReps` over performed weighted sets) and `repVolume` (Σ `actualReps` over all performed sets, weighted + bodyweight) as two separate numbers — never summed together, matching `insights.jsx`'s explicit rule.
- `running_trends.dart` — `List<WeekRunStats> weeklyRunStats(List<RunSession> runs, {int weeks = 8})`: per week, `distanceKm`, `runCount`, `avgPaceSecPerKm`.
- `personal_records.dart` — `List<PersonalRecord> computePersonalRecords(List<WorkoutSession> sessions, List<RunSession> runs)` producing the 6 types below, each with `achievedAt`, `value`, `previousValue` (for the delta line). Also `List<PersonalRecord> recordsSetInSession(List<PersonalRecord> allTimeRecords, String sessionId)` for PR 5.
  - Heaviest weight (per exercise): max `actualWeight`, tie-break shows the reps at that weight.
  - Most reps (per exercise, bodyweight only): max `actualReps`.
  - Longest hold (per exercise): max `heldSeconds`.
  - Best est. 1RM (per exercise, weighted only): Epley `weight * (1 + reps / 30)` over performed sets, max.
  - Session tonnage: max single-session Σ(`actualWeight * actualReps`) across sessions.
  - Fastest pace (running): the single best (lowest) `pacePerKm` across all runs. (Simplification vs. the mockup's "5 km" distance-bucketed pace PRs — bucketing by race distance is ambiguous without a distance-tolerance rule; flagging this simplification for review rather than guessing bucket boundaries.)

Each gets a `test/domain/insights/*_test.dart` written first (TDD, red before green), covering: empty input, single session/run, multiple exercises, the weighted/bodyweight/timed classification boundary, and the "never summed" volume rule.

## PR 1 — Insights tab shell + per-exercise strength trend

- `lib/domain/insights/exercise_trend.dart` + test (written first).
- Rename `lib/presentation/history_screen.dart` → `lib/presentation/insights_screen.dart` (`InsightsScreen`); update `home_shell.dart`'s 4th tab: label `History` → `Insights`, icon `Icons.history_rounded` → `Icons.insights_rounded`.
- New `lib/presentation/widgets/insights_charts.dart`: `AreaTrendChart` (`CustomPainter` line+soft-fill chart with baseline hairline, live last-point dot, optional ringed PR markers — port of `insights.jsx`'s `AreaChart`) and a small pill `SegmentedControl` (port of `insights.jsx`'s `Segmented`, used for the exercise-name chip row here, and for Strength/Running + Tonnage/Reps toggles in later PRs).
- `InsightsScreen`: exercise chip row (from `exerciseNamesLogged`) + trend chart + current-value line (matches `insights.jsx`'s "Exercise trend" card), and the "All sessions" `RowLink` at the bottom.
- New `lib/presentation/all_sessions_screen.dart`: the old History list UI (session cards, no delete button, tap → `SessionDetailScreen`), reached from the `RowLink`.
- `session_detail_screen.dart`: becomes a `ConsumerWidget`; add a delete icon button to its header (reusing the confirm-sheet UI currently in `history_screen.dart`), calling `sessionsProvider.notifier.deleteSession` then popping.
- Empty state: no sessions logged yet (mirrors old History's empty state).
- Tests: `test/domain/insights/exercise_trend_test.dart`, rename/update `test/widgets/history_screen_test.dart` → `insights_screen_test.dart`, new `test/widgets/all_sessions_screen_test.dart`, update `test/widgets/session_detail_screen_test.dart` (delete flow) and `test/widgets/home_shell_test.dart` (tab label/icon).

## PR 2 — Volume over time (tonnage / reps)

- `lib/domain/insights/volume_stats.dart` + test (written first).
- `InsightsScreen`: "This week" `StatStrip` (sessions count / tonnage / reps — three cells, ported from `insights.jsx`'s `StatStrip`) with the explanatory footnote ("Tonnage counts weighted sets only..."), and a "Volume over time" card: Tonnage/Reps `SegmentedControl` toggle, current value + "vs 8w ago" % change, `AreaTrendChart`.
- Tests: `volume_stats_test.dart`, extend `insights_screen_test.dart` for the new sections.

## PR 3 — Personal records

- `lib/domain/insights/personal_records.dart` + test (written first) — the 5 non-running types only (fastest pace lands in PR 4 once `RunSession` data is wired into the same screen; the function signature already accepts `runs` so this is additive, not a breaking change).
- New `lib/presentation/records_screen.dart`: full PR list (`PRCard` per `insights.jsx`'s `ScreenRecords`), reached via "See all" from Insights.
- `InsightsScreen`: "Recent records" section (top 2 PRs) above the volume section, "See all" → `RecordsScreen`.
- Tests: `personal_records_test.dart`, `records_screen_test.dart`, extend `insights_screen_test.dart`.

## PR 4 — Running trends

- Extend `personal_records.dart` with the fastest-pace type + test.
- `InsightsScreen`: top-level Strength/Running `SegmentedControl`. Running mode: "This week" strip (distance / runs / avg pace), "Distance over time" chart, "Pace trend" chart (inverted axis — lower is faster, per `insights.jsx`'s `AreaChart(invert)`), running PRs filtered into "Recent records".
- Tests: extend `personal_records_test.dart`, `running_trends_test.dart`, extend `insights_screen_test.dart` for the mode toggle.

## PR 5 — Surface new PRs on Workout Complete

- `workout_complete_screen.dart` becomes a `ConsumerWidget`; after showing, compute `recordsSetInSession` against the just-saved session and render a "New records" section (`PRCard` list) when non-empty, plus a "See it in Insights" button navigating to the Insights tab.
- Explicitly do **not** add a tonnage `StatChip` back to the existing Duration/Sets stat strip (see plan 019 note above) — the new tonnage figure only appears inside a `PRCard`, with its delta.
- Tests: extend `workout_complete_screen_test.dart` for the PR-present and no-PR cases.

## Out of scope

- Changing Calendar's inline day-panel (`SessionBreakdown`) — untouched.
- Race-distance-bucketed pace PRs (see simplification note above) — flagged for a future pass if wanted.
- Any new dependency (e.g. `fl_chart`) — charts are hand-rolled `CustomPainter`, consistent with the rest of the app's design system and `insights.jsx`'s own hand-rolled SVG chart.

## Testing

Per CLAUDE.md: new domain functions get failing tests first (TDD), then
minimal implementation. Each PR must leave `flutter analyze` and
`flutter test` green before merge.
