# 021 — Fix average pace chart showing raw seconds instead of min:sec

## Bug

On the Insights page, the "Average pace" trend chart's axis labels (min/max)
and tap-to-reveal tooltip show the raw `avgPaceSecPerKm` value (e.g. `425.8`)
instead of a formatted pace like `7:06`.

## Root cause

`weeklyRunStats` (`lib/domain/insights/running_trends.dart`) correctly computes
`avgPaceSecPerKm` as seconds/km. The "Average pace" stat card at the top of
the Insights page formats it correctly via `fmtPace` (`insights_screen.dart:339`,
which calls `formatClock`).

However, `_PaceTrendCard` (`insights_screen.dart:774`) feeds the raw
`avgPaceSecPerKm` doubles straight into the shared `AreaTrendChart` widget.
`AreaTrendChart` and its painter always format values with
`fmtTrimmedNumber` (`insights_charts.dart:8`), which just prints the number
with at most one decimal place — appropriate for the weight/volume/exercise
trend charts (kg, reps, km) that also use `AreaTrendChart`, but wrong for a
seconds-per-km series, which needs min:sec formatting instead.

This affects three things on the pace chart:
- The top-of-chart max-value label
- The bottom-of-chart min-value label
- The tap/drag tooltip's value text

## Fix

Add an optional `String Function(double)? valueFormatter` parameter to
`AreaTrendChart`, defaulting to `fmtTrimmedNumber` (preserves current
behavior for every other call site — weight, volume, exercise trend charts).
Thread it through to the three label/tooltip call sites in
`_AreaTrendChart`/`_AreaTrendPainter`.

In `_PaceTrendCard`, pass `valueFormatter: (v) => formatClock(v.round())`
(same formatting `fmtPace` already uses for the stat card, minus the
null-handling since the chart only ever receives non-null pace values).

## Files touched

- `lib/presentation/widgets/insights_charts.dart` — add `valueFormatter` param
  to `AreaTrendChart`, thread through to `_AreaTrendPainter` and its
  top/bottom label `Text` widgets and `_paintTooltip`.
- `lib/presentation/insights_screen.dart` — pass `valueFormatter` in
  `_PaceTrendCard`'s `AreaTrendChart` call.
- `test/widgets/insights_charts_test.dart` — regression test: with a custom
  `valueFormatter`, the top/bottom labels and tooltip text use it instead of
  `fmtTrimmedNumber`.

## Test plan (TDD — bug fix)

1. Write a failing widget test asserting that when `AreaTrendChart` is given
   a `valueFormatter`, the rendered top/bottom labels use the formatted
   string (e.g. series `[65.0, 426.0]` with a `formatClock`-based formatter
   renders `7:06` and `1:05`, not `426` and `65`).
2. Write a failing widget test asserting the tooltip text uses the formatter
   too (tap a point, check the painted tooltip via the existing test
   pattern — may need a way to assert painted text; if `CustomPaint` text
   isn't easily assertable, cover this via the `_PaceTrendCard`
   integration instead — see below).
3. Confirm both fail without the implementation change.
4. Implement `valueFormatter` in `AreaTrendChart`/`_AreaTrendPainter`.
5. Implement the `_PaceTrendCard` call-site change.
6. Confirm tests pass; run full `flutter test` and `flutter analyze`.

## Non-goals

- Not touching `fmtPace`, `formatClock`, or `weeklyRunStats` — those are
  already correct.
- Not changing the weight/volume/exercise trend charts' formatting.
