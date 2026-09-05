# 018 — UI Consistency Fixes

## Progress

- [ ] **PR 1 — Spacing scale + alignment fixes** (branch `ui/spacing-scale-alignment`)
- [ ] **PR 2 — Type scale** (branch `ui/type-scale`)
- [ ] **PR 3 — Workout icon plumbing** (branch `ui/workout-icon-everywhere`)
- [ ] **PR 4 — Exercise field columns** (branch `ui/exercise-field-columns`)
- [ ] **PR 5 — Bottom navigation** (branch `ui/bottom-nav`)

## Context

The MVP is functionally done, but the UI reads as "off" without any single
screen looking wrong. The cause is that the defects live in the *relationships*
between elements, not in the elements themselves — so a screen-by-screen review
passes everything and then reaches for tidiness findings instead.

Measured on a Pixel 8 emulator (1080×2400 @ 2.625x), Workouts screen:

| Element | Measured |
|---|---|
| "Workouts" headline | 22.5dp |
| Card edge | 15.6dp |
| Card icon tile | 32.0dp |
| Workout name | 90.7dp |

The headline hangs ~7dp right of the cards beneath it, aligning with neither the
card edge nor the card content. The same 22-vs-16 mismatch appears in
`create_workout` (the "EXERCISES" label) and `run_list_screen`.

Separately, the "Runs" headline renders **centred** (spans x=438-643px, centre
540.5px on a 1080px screen) while "Workouts" is left-aligned at 22.5dp. Two peer
screens, different alignment *and* different headline size (44 vs 36).

Root causes, both systemic:

- **No spacing scale.** Eight different left margins across `lib/presentation`
  (4, 8, 10, 12, 16, 18, 22, 32), several off any 4/8pt grid.
- **No type scale in use.** The `TextTheme` in `app_theme.dart:412-431` is never
  read — `textTheme` appears exactly once in all of `lib/`, at its own
  definition. Instead there are 245 hand-typed `fontSize` literals passed to the
  `displayStyle`/`bodyStyle`/`monoStyle` helpers.

Goal: fix the consistency problems in a sequence of independently-shippable PRs.
Each PR leaves `flutter analyze` and `flutter test` green.

## Testing approach

These are layout changes, so the meaningful assertion is *position*, not
appearance. `tester.getTopLeft(find.x(...)).dx` returns widget layout bounds
(not glyph bounds), so it is deterministic under `flutter_test`'s font fallback
and is a fair thing to assert against.

The pattern for PR 1, written **before** the fix so it fails first:

```dart
final headline = tester.getTopLeft(find.text('Workouts')).dx;
final card     = tester.getTopLeft(find.byType(WorkoutListCard).first).dx;
expect(headline, card);
```

`flutter test` green is necessary but not sufficient for this plan — every PR
also needs a visual check on the Pixel 8 emulator before it's called done, since
the whole point is how it looks.

**Risk to watch:** `test/support/pump_app.dart` notes that screens already
overflow at true device width (~412dp) under test because the custom fonts
aren't loaded and the fallback font has wider metrics. Increasing any horizontal
inset could push a screen from "overflows only in tests" to "overflows on
device". Check the emulator, not just the test run.

## PR 1 — Spacing scale + alignment fixes

The visible win, and the foundation for everything after it.

- Add spacing constants to `lib/theme/app_theme.dart` alongside the existing
  `kRadius`. A small set only — the values actually needed, not a speculative
  full scale:
  `kSpaceXs = 4`, `kSpaceSm = 8`, `kSpaceMd = 16`, `kSpaceLg = 24`, `kSpaceXl = 32`.
- Settle on **16dp** as the screen inset. It's what every card and list already
  uses, so it's the smaller diff and needs no card changes — the headers move to
  meet the cards, not the other way round.
- Fix the Runs centred headline. In `run_list_screen.dart:67-84` the inner
  `Column` sets `CrossAxisAlignment.start`, but it shrink-wraps to the text width
  and the *outer* `Column` (line 40) uses the default `CrossAxisAlignment.center`,
  so the padded block gets centred and the `.start` is a no-op. Set
  `crossAxisAlignment: CrossAxisAlignment.stretch` (or `.start`) on the outer
  `Column`.
- Migrate the 22dp and 18dp horizontal insets on **scroll surfaces** to 16dp:
  `workout_list_screen.dart:72`, `run_list_screen.dart:68`, and the section
  labels in `create_workout.dart` ("ICON", "WARM-UP", "EXERCISES").
- **Leave bottom sheets alone.** They're a separate surface with no adjacent
  cards to align to, so their 22dp inset isn't part of the problem. This is
  judgement, not find-and-replace — roughly 16 horizontal call sites use 22/18
  and not all of them should change.

Tests (`test/widgets/`): headline-left-edge equals card-left-edge on
`workout_list_screen_test.dart`, `run_list_screen_test.dart`, and section-label
equals exercise-card on `create_workout_test.dart`.

## PR 2 — Type scale

Mostly a maintainability fix. Only one part of it is visible.

- Resolve the dead `TextTheme` in `app_theme.dart:412-431` — **delete it**. The
  app has its own `displayStyle`/`bodyStyle`/`monoStyle` helpers and three font
  families; wiring the Material `TextTheme` up properly would mean rewriting all
  245 call sites to `Theme.of(context).textTheme.*` and losing the per-call
  `color`/`letterSpacing` ergonomics the helpers give. Deleting it removes
  something that currently misleads anyone who edits it expecting a visual change.
- Add named size constants next to the helpers, so there is one lever per
  semantic role rather than a literal per call site.
- Migrate **only the roles where the drift is visible**: screen headlines
  (Workouts 44 vs Runs 36 — pick one) and the all-caps section labels (currently
  10/11/12 depending on file).
- **Do not migrate the 245 body/caption literals in this PR.** Most of the drift
  is 11-vs-12-vs-13 on caption text, which is invisible in isolation and on
  different screens. A 245-site mechanical diff is unreviewable and risks silent
  visual regressions for no user-facing gain. Adopt the constants as screens get
  touched for other reasons.

Tests: the headline-size assertions are weak (asserting a `fontSize` mostly
restates the implementation), so this PR leans on existing tests staying green
plus an emulator check that Workouts and Runs headlines now match.

## PR 3 — Workout icon plumbing

Small and self-contained. The icon picked in New/Edit Workout is currently only
read by the calendar grid.

- `WorkoutListCard` (`app_widgets.dart:176`) doesn't accept an icon at all and
  hardcodes `Icons.fitness_center_rounded` at line 224. Add a `String? icon`
  param.
- Swap three call sites to the existing `workoutIconFor(workout.icon)` helper
  (`lib/domain/models/workout_icons.dart:14`, currently used in exactly one place):
  `app_widgets.dart:224`, `workout_start_preview_screen.dart:246`,
  `workout_picker.dart:102`.
- **Leave `workout_list_screen.dart:320`** — that's the empty-state
  illustration and should stay generic.
- The doc comment on `kWorkoutIcons` says "shown as a small dot/icon on the
  calendar", so calendar-only was the original intent. Update the comment to
  match the new behaviour.

Tests: a workout with `icon: 'cardio'` renders a heart (not a dumbbell) in the
list card, the preview screen, and the picker. Failing first.

## PR 4 — Exercise field columns

**Decided: move SETS and REST onto the superset group.**

In `create_workout.dart:963-1026` the field row is built conditionally, driven by
`showSets: isSingle || isFirstInGroup` and `showRest: isSingle || isLastInGroup`
(line 263-264). The result:

| Row | Columns |
|---|---|
| Standalone exercise | SETS / REPS / WEIGHT / REST |
| Superset, first | SETS / REPS / WEIGHT |
| Superset, partner | REPS / WEIGHT / REST |

So column 1 means "sets" on one row and "reps" on the next. Scanning down a
column doesn't mean the same thing row to row.

**This is a presentation-only change — the model is already right.** `Superset`
already owns both fields (`superset.dart:11-12`), and its doc comment already
describes them as "a shared set count and a single rest period". The pickers
even write straight to the group today (`s.sets = v`, `s.restAfterSet = v`).
The only thing wrong is that two group-level fields are rendered *inside*
individual exercise rows. So: no model change, no Hive adapter change, no
persistence migration.

- Render SETS and REST once per superset, on the group itself, not in the
  exercise rows.
- Every exercise row then shows REPS (or DURATION) / WEIGHT, uniformly — same
  labels, same order, every row.
- Delete `showSets`/`showRest` and the `isFirstInGroup`/`isLastInGroup` plumbing
  at `create_workout.dart:263-264`; they exist only to serve the old layout.
- A single-exercise superset still needs its SETS and REST visible — make sure
  the group-level control renders for groups of one, not just for real supersets,
  or the standalone case loses two fields.

Tests: build a workout with one standalone exercise and one 2-exercise superset;
assert every visible exercise row exposes the same field labels in the same
order, and that SETS/REST appear exactly once per group.

## PR 5 — Bottom navigation

**Decided: bottom nav.** This supersedes two tracked items rather than patching
them — the header icon row (nav mixed with settings) and the calendar's missing
back affordance. Peer screens stop needing back buttons because they become tabs,
and the nav-vs-settings ambiguity disappears because settings leaves the row.

- Add `lib/presentation/home_shell.dart` — a `NavigationBar` over an
  `IndexedStack`. `IndexedStack` keeps each tab's state and scroll position
  across switches, which `Navigator.push` currently doesn't.
- **Four destinations:** Workouts, Calendar, Runs, History.
- **Appearance stays a header icon** on Workouts. One theme picker doesn't earn
  a tab or a settings screen, and it's no longer ambiguous once it's the only
  icon in that header.
- `main.dart:110` — `home:` changes from `WorkoutListScreen()` to `HomeShell()`.
- Remove the four-icon row from `workout_list_screen.dart:88-156`, keeping only
  the appearance swatch. The `_EmptyState` at `:282-289` has its own copy of the
  same row — update both.
- Remove the back arrow from `run_list_screen.dart:43-46`. The sync icon in that
  header stays; it's a screen action, not navigation.
- Calendar keeps its chevron-left/right month controls. They stop being
  ambiguous once there's no back button for them to be confused with.
- **Detail screens stay pushes**, not tabs: `CreateWorkoutScreen`,
  `WorkoutStartPreviewScreen`, `MesocycleSetupScreen`, `RecordRunScreen`,
  `RunDetailScreen`, `SessionDetailScreen`.
- **Watch the FABs.** `workout_list_screen.dart:220-230` positions its FAB at
  `bottom: 36 + MediaQuery.of(context).padding.bottom`, which assumed no nav bar
  underneath. Both it and the Runs FAB need to clear the `NavigationBar`, and
  the list `SliverPadding` bottom insets (currently 120) want rechecking too.

Tests: tapping each destination shows the matching screen; switching away and
back preserves scroll position (the `IndexedStack` guarantee); detail screens
still push over the shell rather than replacing it.

**Ordering note:** PR 1 and PR 5 barely overlap. PR 1 changes horizontal *insets*
and the Runs `Column` alignment; PR 5 changes *what's in* the header rows and how
screens are reached. The headline stays in both worlds, so PR 1's work survives.
If you'd rather not touch `run_list_screen` twice, PR 5 can move first — but PR 1
is the cheap visible win and the one that addresses the original complaint.

## Out of scope

- **Calendar week-view toggle** — tracked in `Feature_tracking.md` under
  Calendar. It's a feature, not a consistency fix, and the calendar chrome
  changes underneath it in PR 5. Sequence it after PR 5.
- **The peer audit's "dead space" finding** — checked and not real. Workouts and
  Runs both anchor a FAB, and New Workout has a full-width sticky bottom CTA with
  a gradient scrim (`create_workout.dart:584-604`). What's left is "a short list
  doesn't fill a tall screen", which is how list screens work.
