# 014 — Scroll-wheel weight/reps pickers + intuitive exercise search

Branch: `feat/scroll-pickers-exercise-search`

## Problem

1. **Weight and reps are typed into narrow `TextField`s.** Hard to hit the right
   number on a small target, and the weight field accepts decimals that are never
   used (weights are whole kilograms). Existing rest/duration fields already use a
   `CupertinoPicker` wheel and feel much better.
2. **Exercise naming is disjointed.** The library sheet closes when "Type my own"
   is tapped and adds a *blank* exercise — whatever was typed in the search box is
   thrown away. Once the card exists, the name is a plain text field with no
   suggestions and no way back to the library.

## Current state (files touched)

| Location | Today |
|---|---|
| `create_workout.dart` `_ExerciseSlotCard` | WEIGHT = `_NumField` (TextField, `decimal: true`); REPS = `_PickerField` (wheel, already good); name = plain `TextField` |
| `create_workout.dart` `_openRepsPicker` (l.1476) | Private reps wheel, only usable inside this file |
| `workout_session_screen.dart` `_BigNumber` (l.1193) | 84pt `TextField` for both reps and weight, backed by `_actualRepsCtrl` / `_actualWeightCtrl` |
| `exercise_library_picker.dart` | `onBlank: VoidCallback` — discards the search query |

`Exercise.weight` is a `double` and is persisted through the Hive adapter.

## Approach

### 1. Shared wheel pickers — new `lib/presentation/widgets/number_picker_sheet.dart`

One private `_openWholeNumberPicker` sheet (same 280pt height, 44pt item extent,
"Done" button and styling as the existing rest-time picker), exposed as:

- `openRepsPicker(context, int current, void Function(int))` — range **1–50**
  (unchanged from today's reps wheel).
- `openWeightPicker(context, double current, void Function(double))` — range
  **0–300 kg, step 1**, single wheel (confirmed).
- `openSetsPicker(context, int current, void Function(int))` — range **1–10**.
- `fmtWeight(double)` → `w.round().toString()`, so `20.0` renders as `20`.

`_openRepsPicker` is deleted from `create_workout.dart` and both screens call the
shared helpers. `_openTimePicker` (rest/duration) is left exactly as-is.

**Model stays `double`.** Switching `Exercise.weight` to `int` would mean a Hive
adapter migration for data already on the device; the pickers only ever produce
whole values and `fmtWeight` hides the `.0`, which gets the same user-visible
result with none of the migration risk.

### 2. Weight/reps become wheels

**`create_workout.dart` — `_ExerciseSlotCard`:**
- WEIGHT `_NumField` → `_PickerField` showing `${fmtWeight(e.weight)} kg`,
  tapping opens `openWeightPicker`.
- Drop `_weightCtrl` and the now-unused `decimal` param on `_NumField`.
- SETS stays a text field (not raised as a problem; out of scope).

**`workout_session_screen.dart`:**
- Replace `_actualRepsCtrl` / `_actualWeightCtrl` `TextEditingController`s with
  plain `int _actualReps` / `double _actualWeight` state, prefilled per set by
  `_prefillControllers`. `_finishSet` reads the fields directly instead of
  `int.tryParse` / `double.tryParse`.
- `_BigNumber` becomes tap-to-open (same 84pt display type, so the screen looks
  unchanged) → `openRepsPicker` / `openWeightPicker`. A small chevron/underline
  hints it is tappable.

**Weight display cleanup** (`fmtWeight`) at the spots that currently print
`20.0kg`: `create_workout.dart` l.1792 & l.1852 (preview set rows),
`workout_session_screen.dart` l.716, l.936, l.939, l.1159.

### 3. Exercise search flow

**`exercise_library_picker.dart`:**
- `onBlank: VoidCallback` → `onBlank: void Function(String typedName)`, passing the
  current search text.
- The top tile becomes context-aware: `Type my own` when the box is empty,
  `Use "Incline DB Press"` when something is typed.
- New optional `initialQuery` (pre-fills and pre-filters the search box) and
  `autofocus` params.

**`create_workout.dart`:**
- `_openExercisePicker` → `onBlank: (typed) => _addExercise(name: typed)`.
- The exercise-name `TextField` in `_ExerciseSlotCard` becomes a tap target
  (visually identical: name, or "Exercise name" hint) that reopens the library
  sheet with `initialQuery: e.name` and `autofocus: true` — so pressing the name
  brings the search page straight back with the keyboard up. Picking a library
  entry renames the exercise (and switches reps/timed mode to match the template);
  "Use …" renames it to whatever was typed.
- `_nameCtrl` is dropped from `_ExerciseSlotCardState`; the name is read from the
  model.

The warm-up card's name field is left alone — warm-up exercises are not added via
the library picker, so it is outside this change.

## Verification

- `flutter analyze`
- Manual: create a workout → add via library, add via "Use <typed text>", tap a
  name to reopen search, set weight/reps by wheel; run a session and change
  reps/weight mid-set; confirm no `.0` anywhere and that saved/reloaded workouts
  keep their values.

## Decisions (confirmed before implementation)

1. **Weight wheel: single column, 0–300 kg, 1 kg steps**, opening on the current
   value.
2. **SETS becomes a wheel too** (1–10), so the exercise card has no typed numeric
   fields left.
3. **Warm-up name fields get the same library search**, via the shared
   `_ExerciseNameField`.

## Outcome

Implemented on `feat/scroll-pickers-exercise-search`. `flutter analyze` clean.
`_NumField` was deleted — with sets and weight on wheels it had no callers left,
so `create_workout.dart` no longer contains a numeric text field.
