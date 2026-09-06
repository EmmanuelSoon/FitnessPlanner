# 019 — Unify stat cell widget, remove volume stat

## Problem

- The workout preview screen (`create_workout.dart`) shows a "volume" stat
  as `${(totalVol / 1000).toStringAsFixed(1)}t` — a tonnes figure with no
  comparison point, which reads as an arbitrary/meaningless number on a
  single-session screen (confirmed with user: "utterly useless").
- `_StatCell` is defined twice, identically, as a private class in both
  `create_workout.dart` and `workout_complete_screen.dart`.
- There is also an existing `StatChip` widget in
  `lib/presentation/widgets/app_widgets.dart` that is unused anywhere,
  and is nearly identical to `_StatCell` but missing the `leftBorder`
  divider and container padding.

## Change

1. Extend `StatChip` (`app_widgets.dart`) to add the `leftBorder` bool
   param and the container padding/border, matching `_StatCell`'s current
   visual output exactly (no visual change to existing usages — there are
   none yet).
2. Replace both private `_StatCell` classes (`create_workout.dart`,
   `workout_complete_screen.dart`) with the shared `StatChip`, and delete
   the two duplicate class definitions.
3. In `create_workout.dart`'s preview screen build method, remove the
   `totalVol` computation and the third stat cell. The stats row becomes
   2 cells: Duration | Sets — matching `workout_complete_screen.dart`'s
   existing layout.

## Out of scope

- No change to `workout_complete_screen.dart`'s stats (already Duration
  + Sets only).
- No new "exercises count" or other replacement stat — discussed and
  decided against, since the per-exercise breakdown already shown below
  both stat rows makes an extra top-line stat redundant.

## Tests

- Pure refactor + removal, no new behavior introduced. No new tests
  required per CLAUDE.md refactor convention.
- No existing tests reference "volume"/"VOLUME"/`totalVol` (confirmed via
  grep), so nothing to update.
- Run `flutter analyze` and `flutter test` after the change to confirm
  green.
