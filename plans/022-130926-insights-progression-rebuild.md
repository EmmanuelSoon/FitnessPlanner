# 022 — Insights: rebuild around progression

## Progress

- [x] PR 1 — Shared e1RM, chronological helper, time windows
- [ ] PR 2 — Lift series + progression summary + ranking
- [ ] PR 3 — Muscle-group tag on exercises and logged sets
- [ ] PR 4 — Weekly sets by muscle group
- [ ] PR 5 — Chart axis rebuild
- [ ] PR 6 — Insights tab rebuild (verdict + ledger + weekly sets)
- [ ] PR 7 — Lift detail screen
- [ ] PR 8 — Running pass

## Context

Plan 020 built the Insights tab as four descriptive charts. It shipped, and the
verdict is that it doesn't answer the question it exists to answer. Verbatim:

1. "the axis is too minimal to know what is going on"
2. "the headline of reps or tonnage is just number with no explanation or i dont
   understand what it even means"
3. "the exercise trend shows top set which also doesnt really show progress. it
   is just 1 set."
4. "the pills to click for each exercise is also quite clunky to use"
5. "the reps being a total number for the week is also quite useless. i can do
   100 bicep curls and 5 heavy squats but it is not more difficult or better
   progression than 20 bicep curls and 20 heavy squats that week"

Every complaint is about **substance**, not decoration. Plan 020 contains no
progression logic at all — no 1RM over time, no stall detection, no
load-weighted volume. It plots what was logged; it never says whether it was
good. The intended outcome of this plan is that the tab answers one question on
sight: **am I progressing, where, and what's stuck.**

There is direct precedent for this critique. Plan 019 / PR #52 removed a bare
"12.4t" from the workout preview as "utterly useless" in isolation, and plan 020
recorded the rule that tonnage may only reappear contextualised as a delta or
trend point, never as a lone figure. This plan extends that rule: **no number
ships without the sentence that explains it.**

### Decisions already made

- Estimated 1RM (Epley) replaces top-set weight as the strength metric.
- Full rebuild of the tab, not an additive section.
- Weekly work becomes **working sets per muscle group**, not reps or tonnage.
- Muscle group becomes a **real persisted tag** on exercises, not a name lookup.
- The ranked lift list is the exercise picker; tapping a lift pushes a full
  detail screen. The horizontal chip row is deleted.
- Running is fixed last, in a droppable final PR.

### Correction to the stated approach

Swapping `actualWeight` for Epley inside `computeExerciseTrend` would **not**
fix complaint 3. `personal_records.dart:128` takes the max e1RM across sets, so
a naive swap still plots a single set — it fixes the unit, not the complaint.
The session's point must aggregate: **mean of the top three sets** (§ Metric
semantics).

### Live bug found

`estimatedOneRm` via Epley returns `weight * (1 + reps/30)`, which at `reps == 1`
yields `w * 1.033`. The existing `bestEst1Rm` personal record therefore reports a
genuine 100 kg single as **103.3 kg**. PR 1 fixes this, which is a user-visible
change to an already-shipped record — call it out in that PR's body.

---

## Metric semantics

These are the load-bearing decisions. Everything else is presentation.

**Estimated 1RM.** `estimatedOneRm(weight, reps)` returns `null` when
`weight <= 0 || reps <= 0 || reps > 12`, returns `weight` exactly at `reps == 1`,
else `weight * (1 + reps / 30)`. The cap at 12 is because Epley holds to within
~3% to about 10 reps and diverges past 12 as the set stops being a strength
effort. Reps are **not** clamped to 12 — clamping fabricates a number. `null`
means "no point for this session", and the count of excluded sessions is carried
on the summary so the UI can explain a gap in the line rather than leave a
mystery.

**The session's point: mean of the top three sets.** Rejected alternatives, with
reasons, because this is the single most important choice here:
- *Max across sets* — repeats the exact flaw the user named.
- *Volume-weighted across all sets* — perverse: adding a light back-off set
  lowers the score, so the metric punishes doing more work.
- *Top-three mean* — captures the day's repeatable quality, survives one
  miscounted rep, and rewards three hard sets over one hard set plus junk.

Each point also carries `best` (the max single set) so the chart and the records
list can never silently disagree.

**Window endpoints are also averaged.** `startValue` is the mean of the first
three points in the window, `currentValue` the mean of the last three. Using
single endpoints makes the entire summary hostage to two noisy sessions — the
same flaw as complaint 3, one level up.

**Stalled** is `|percentDelta| < 2.5%` **or** `weeksSinceBest >= 6`. The 2.5%
floor is set by the metric's own noise: one miscounted rep moves Epley by 3.3%,
so anything below that is indistinguishable from a logging error. The six-week
arm catches the case percent-delta misses — a lift that peaked two months ago and
drifted sideways is stuck regardless of where the window endpoints happen to
land. Regressing is `<= -2.5%`.

**Deload weeks are excluded from endpoint selection.** A window ending on a rest
week flips every lift to "regressing". `computeLiftProgress` takes
`Set<DateTime> excludedWeekStarts`; the screen populates it from
`schedule_logic.isRestWeek`, keeping the domain file dependency-free.

**Minimum data to rank: 4 sessions and a 21-day span.** Lifts below either
threshold are excluded from the ledger entirely rather than shown as
"insufficient data" — a half-populated ledger is worse than an empty one with a
clear instruction. Spans under 42 days set `isExtrapolated`, because a per-30-day
rate from three weeks of data is a guess.

**Working set** = one performed, non-skipped, non-timed set. Verified safe:
warm-ups live on `Workout.warmup`, are run from a separate screen, and are never
written into `session.sets` — `workout_session_screen.dart` is the only place
`LoggedSet` is constructed. Timed holds are counted separately and never folded
into the working-set total; a plank is not a set of squats.

---

## Design

The tab lives inside an existing system and must not look imported: 8
user-selectable themes × light/dark, tokens only (`bg`, `surface`, `surfaceAlt`,
`ink`, `inkDim`, `inkMute`, `hairline`, `hairlineSoft`, `accent`, `accentInk`,
`danger`), Space Grotesk display / Manrope body, `kRadius` 20, hand-rolled
`CustomPainter` charts, no chart package.

**Colour — direction is never encoded in hue.** No green-up / red-down. Three
reasons, in order: the `stone` theme sets `accent == ink`, so any
accent-versus-ink signal collapses there; there is no categorical palette
anywhere in the app to borrow from; and it is the default move every fitness
dashboard makes. Direction is encoded **positionally** instead — bars grow right
from a shared zero line for gains and left for losses, so progress is read from
geometry. `accent` stays the single emphasis colour, on the "now" endpoint only.
`danger` stays reserved for destructive actions, as today.

**Type — no new typeface.** JetBrains Mono is bundled and has zero call sites
across `lib/`, and a ledger of aligned figures is the obvious excuse to use it.
Rejected: the app has one consistent rule — numbers are `displayStyle` (Space
Grotesk) w600 with negative tracking, everywhere — and breaking it in one tab
would make Insights the odd screen out. The unused font is the accessory to take
off before leaving the house. Uppercase section labels are kept **against**
general design advice because they are established app vocabulary
(`_SectionLabel`, `StatChip`, `PRCard`); consistency wins over the general rule.

**The hero is a sentence, not a number.** This is the direct answer to complaint
2. A big figure with a small label is exactly what's there now and exactly what
he can't interpret. The top of the tab states the finding in display type, with
the method in quiet body text beneath it:

```
Five of nine lifts are moving.
Deadlift and barbell row haven't in six weeks.

Estimated 1RM, top three sets averaged, last 12 weeks.
```

Low-data and all-stalled states are directions, not moods:
- *Not enough yet*: "Log four sessions of a lift and it'll show up here."
- *All stalled*: "Nothing has moved in six weeks. Your last four sessions
  repeated the same weights."

**The memorable element is the ledger.** One card, one row per lift, dots joined
by a bar on a shared percentage axis — a dumbbell plot, which is both a
legitimate chart type for ranked before/after comparison and, here, literally the
shape of a loaded bar. Long bar means moving; a bare dot means stuck, and that
reads at a glance without a legend. This is where the boldness is spent;
everything around it stays quiet.

```
LIFT LEDGER                                  last 12 weeks

                          0%        +5%       +10%
  Bench press    82.5→90.0 ●━━━━━━━━━━━━━━━━━━━●      +9.1%
  Squat          120→125   ●━━━━━━━━●                 +4.2%
  Overhead press 47.5→48.5 ●━━━●                      +2.1%
  Deadlift       140→140   ●                            held
  Barbell row    65→62.5 ←━●                          −3.8%
                           │
                     shared zero line, inset to leave room for losses
```

**Weekly sets replace tonnage and reps.** This is complaint 5's answer: 100 curls
in three sets reads as Arms 3, twenty squats in four sets as Legs 4. The tick
mark is the 4-week trailing average, so "is this week light or heavy" is
answerable without arithmetic.

```
THIS WEEK'S SETS                      28 working sets

  Legs     ████████████│              12    heavy
  Back     ████████│                   9    typical
  Chest    ██████│                     6    typical
  Arms     ███│                        3    light
  Core     ██│                         2    typical

  One working set is one set you performed. Warm-ups and
  timed holds aren't counted.
```

**Page structure**, replacing the current six blocks with five:

```
  [ Strength | Running ]        mode
  [ 8W | 6M | 1Y | All ]        window, governs everything below

  ── verdict sentence ─────────────────  the hero
  ── lift ledger ────────────────────── tap a row → detail screen
  ── this week's sets ─────────────────
  ── recent records ───────────────────  unchanged, demoted
  ── all sessions ─────────────────────  unchanged
```

The weekly tonnage/reps area chart is **deleted**, not relocated. Eight
auto-scaled sparklines on one page are what made the tab unreadable; the ledger
is the progression view and the real chart lives one tap away with a proper axis.

**The axis fix** (complaint 1) applies to every chart: 3–4 gridlines at
nice-round values with labels, a padded nice-number range instead of raw
min→max, dated x ticks rather than only the two edges, and a stated unit. The
current chart auto-scales exactly min→max, which makes a 1 kg change fill the box
— the shape is a lie and that is why it can't be read.

---

## PR 1 — Shared e1RM, chronological helper, time windows

New `lib/domain/insights/insights_window.dart`:
- `enum InsightsWindow { eightWeeks, sixMonths, oneYear, all }`
- `int resolveWeeks(InsightsWindow, List<DateTime> dates, DateTime now)` — `all`
  resolves to `span.clamp(8, 156)`; it must resolve to a concrete count or an
  empty database yields zero buckets.
- `enum Bucketing { weekly, fourWeekly }` — weekly to 26 weeks, four-weekly
  beyond. Bucketing is a domain concern so both consumers agree.

In `personal_records.dart`, extract the inline Epley at line 128 to a shared
`double? estimatedOneRm(double weight, int reps)` with the cap and the `reps == 1`
fix, and rewire the existing call site. Add
`List<WorkoutSession> chronological(List<WorkoutSession>)` — every insights
function currently runs its own `[...sessions]..sort`, so six computations mean
six full sorts per rebuild.

Leave `weeklyVolume(weeks:)` signature alone; thread the window in as the
resolved `int`.

**Tests:** `test/domain/insights/insights_window_test.dart` (new); extend
`test/domain/insights/personal_records_test.dart` for the reps==1 and >12-rep
cases. Red first: assert `estimatedOneRm(100, 1) == 100` before the fix.

## PR 2 — Lift series, progression summary, ranking

New `lib/domain/insights/strength_progress.dart`:
- `enum LiftMetric { estimatedOneRm, repsPerSet, holdSeconds }`, and
  `LiftMetric metricFor(List<LoggedSet>)` **extracted** from the private
  `_classify` in `exercise_trend.dart`, which then imports it. Classification
  stays across-all-sets; per-session classification would flip units mid-chart.
- `class LiftSessionPoint { date, sessionId, value /*top-3 mean*/, best,
  setsCounted, setsPerformed }`
- `Map<String, List<LiftSessionPoint>> allLiftSeries(List<WorkoutSession>)` —
  **one pass**. A per-name builder called once per exercise is
  O(names × sessions × sets) on every rebuild.
- `class LiftProgress { exerciseName, metric, startValue, currentValue,
  absoluteDelta, percentDelta?, percentPer30Days?, sessionCount,
  excludedHighRepSessions, firstDate, lastDate, spanDays, bestDate?,
  weeksSinceBest, isExtrapolated, status }` with
  `enum LiftStatus { progressing, holding, regressing, insufficientData }`
- `LiftProgress? computeLiftProgress(List<LiftSessionPoint>, {DateTime? now,
  Set<DateTime> excludedWeekStarts})`
- `List<LiftProgress> rankedLifts(Map<String, List<LiftSessionPoint>>,
  {LiftMetric? only, DateTime? now})` — sorted by `percentPer30Days` descending.

The three metric kinds share one ranking because `percentPer30Days` is unitless,
but bodyweight percentages are structurally inflated (6→9 reps is +50%), so the
`only:` filter exists for the screen to segment. Do not cross-normalise; z-scores
at n=4 are indefensible.

**Tests:** `test/domain/insights/strength_progress_test.dart` (new) — top-3 mean
with 1/2/5 sets, averaged endpoints, the 2.5% and 6-week stall arms, deload
exclusion, min-data gating, single-pass series correctness. Extend
`exercise_trend_test.dart` for the extracted `metricFor`.

## PR 3 — Muscle-group tag on exercises and logged sets

Add `String? category` to `Exercise` (`lib/domain/models/exercise.dart`) and to
`LoggedSet`, both nullable so existing Hive JSON blobs deserialise unchanged —
**no migration script needed**. `workout_session_screen.dart` copies the category
from `Exercise` onto each `LoggedSet` at log time, denormalising it into the log
where it belongs.

Resolution chain, in `lib/domain/insights/training_load.dart`:
`set.category ?? libraryLookup(set.exerciseName) ?? 'Other'`. The library lookup
is a top-level `Map<String,String>` built once from `kExerciseLibrary`, keyed on
a normalised name (lowercased, non-alphanumerics stripped) — not a 62-entry
linear scan per set. **Exact normalised match only, no fuzzy matching:**
"Close-Grip Bench Press" is Arms while "Bench Press" is Chest, so substring or
edit-distance matching would silently reclassify.

Exercise editor gains a category selector, defaulted from the library when the
exercise is picked from it. Expose `Set<String> unmatchedExerciseNames(sessions)`
so the tab can prompt a tagging pass rather than showing a mystery "Other" bar.

**Files:** `exercise.dart`, `logged_set.dart` (+ their adapters),
`workout_session_screen.dart`, the exercise editor screen, `training_load.dart`.

**Tests:** extend `test/domain/models/` for nullable round-tripping of both
models (old JSON without the field must decode); new
`test/domain/insights/training_load_test.dart` for the resolution chain and
normalisation; widget test for the editor's selector.

## PR 4 — Weekly sets by muscle group

In `training_load.dart`:
- `class CategoryLoad { category, workingSets, timedSets, exerciseCount }`
- `class WeekLoad { weekStart, Map<String,CategoryLoad> byCategory,
  totalWorkingSets, sessionCount, isPartial }`
- `List<WeekLoad> weeklyTrainingLoad(List<WorkoutSession>, {int weeks,
  DateTime? now})` — reuse `weekStartOf` from `volume_stats.dart`.
- `enum LoadBand { light, typical, heavy, unknown }` and
  `List<CategoryLoadComparison> compareToTrailing(List<WeekLoad>,
  {int trailingWeeks = 4})`.

The trailing mean covers prior **completed** weeks only — including the
in-progress week makes every Wednesday read "light". Bands sit at ±25% of the
trailing mean: on a typical 16-set week that's ±4 sets, about one exercise, the
smallest genuinely different piece of programming. Fewer than two complete prior
weeks yields `unknown`.

**Tests:** extend `training_load_test.dart` — timed sets excluded from
`workingSets`, partial-week flag, trailing mean skipping the current week, band
boundaries at exactly ±25%, `unknown` below two prior weeks.

## PR 5 — Chart axis rebuild

Rework `AreaTrendChart` / `_AreaTrendPainter` in
`lib/presentation/widgets/insights_charts.dart`: a nice-number scale (1/2/5×10ⁿ
steps) producing 3–4 labelled gridlines, a padded round range replacing raw
min→max, dated x ticks at computed intervals, and an axis unit label. Keep the
existing tap-to-reveal tooltip and `AreaTrendChartState.touchedIndex` — PR #58
built those and tests depend on them.

This lands before the tab rebuild so the existing cards improve immediately and
the axis work can be reviewed on its own.

**Tests:** extend `test/widgets/insights_charts_test.dart` — nice-number
selection across ranges, gridline count bounds, that a flat series doesn't
produce a degenerate axis, that existing `touchedIndex` behaviour is unchanged.

## PR 6 — Insights tab rebuild

Rewrite `lib/presentation/insights_screen.dart` to the structure above. New
widgets in `lib/presentation/widgets/`: the verdict block, the ledger (with its
own `CustomPainter` for the dumbbell rows), the weekly-sets bars. Add the window
selector using the existing `SegmentedControl`.

Deleted: `_ExerciseChip` and the chip row, `_VolumeCard`, `_ThisWeekStrip`'s
tonnage and reps chips, and the "Tonnage counts weighted sets only…" caption they
required.

Extend the existing `_sync` memoisation to cover the new derived data; it exists
precisely because these functions rescan all history per rebuild, and this PR
adds more of them.

Also fix the **known empty-state gap** carried over from plan 020: the tab gates
on `sessions.isEmpty` alone, so a user with runs but no lifts sees "No sessions
yet" and can never reach Running mode.

**Tests:** rewrite `test/widgets/insights_screen_test.dart` — verdict copy for
progressing / all-stalled / insufficient-data, ledger row ordering and the
excluded-lift rule, weekly bars with bands, window switching, and the runs-only
empty-state fix. Reuse `pumpApp` and the `test/support/fixtures.dart` builders.

## PR 7 — Lift detail screen

New pushed screen: exercise name, current e1RM with delta, the full-axis chart
from PR 5 with a start-of-window marker, the sets behind each point ("Sep 2 —
3×8 @ 60 kg, e1RM 76"), and that lift's records. Reached by tapping a ledger row;
follows the pushed-sub-screen header convention (28 w500, ls −0.6).

**Tests:** new `test/widgets/lift_detail_screen_test.dart` — renders the series,
tapping a point reveals its sets, high-rep-excluded sessions are explained rather
than silently missing.

## PR 8 — Running pass

Split the pace trend by `RunType` (the field is already stored and currently
ignored) so easy runs, tempo and intervals aren't averaged into one meaningless
line, and apply the PR 5 axis. Droppable without affecting PRs 1–7.

**Tests:** extend `test/domain/insights/running_trends_test.dart` and the running
half of the screen test.

---

## Out of scope

- AI-powered progression recommendations (the open `Feature_tracking.md` item) —
  this plan builds the measurement layer that feature would need, nothing more.
- Bodyweight logging, RPE/RIR, and per-set timestamps. All absent from the data
  model; several better metrics (relative intensity, true hard-set counting,
  session density) are unreachable without them.
- Race-distance-bucketed pace PRs — still deferred from plan 020.
- Target-vs-actual adherence. `targetReps`/`targetWeight` are stored on every set
  and completely unexploited, but it's a separate question from progression.
- Any new dependency. Charts stay hand-rolled.
- A total-sets-over-time trend chart. Deliberately cut so the tab keeps one
  time-series per screen.

## Testing

TDD per CLAUDE.md: failing tests first for every PR, AAA, one assertion where
practical. Domain tests keep the existing inline `_session`/`_weighted` builder
convention; widget tests use `pumpApp` with repository provider overrides and the
`test/support/fixtures.dart` builders. `flutter test` and `flutter analyze` green
before each PR is considered done.

End-to-end verification on the device (`adb` path in CLAUDE.md, or the
`release-phone` skill): log two sessions of one lift at different loads, confirm
the lift appears in the ledger only after the 4-session threshold, confirm the
verdict sentence changes between progressing and stalled, confirm the weekly-sets
bars attribute a custom-named exercise to its tagged group, and check the ledger
and detail chart in both light and dark under at least the `stone` theme, where
`accent == ink`.
