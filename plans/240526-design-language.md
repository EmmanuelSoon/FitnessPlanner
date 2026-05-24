# Design Language Implementation — "Quiet" Direction

**Date:** 24/05/26  
**Source:** Claude Design handoff — Fitness Planner.html

---

## Summary

Implement the "Quiet" visual direction from the design handoff across all screens. The design uses a calm, editorial aesthetic with Space Grotesk + Manrope typography, rounded cards with soft shadows, and 8 pastel color themes.

---

## Design Tokens

### Typography
- **Display font:** Space Grotesk (wt 500/600/700)
- **Body font:** Manrope (wt 400/500/600/700)
- **Mono font:** JetBrains Mono (for numbers in active screen)

### Spacing (comfy density)
- Padding: 18px
- Gap: 14px
- Card radius: 20px

### Default Theme (Mint, Light)
| Token | Value |
|---|---|
| bg | #E6EDE7 |
| surface | #F0F4F0 |
| surfaceAlt | #D4DFD6 |
| ink | #0F1411 |
| inkDim | #566058 |
| inkMute | #9AA49B |
| accent | deep teal (~#1B7A6B) |
| accentInk | #F0F4F0 |

---

## Files to Create

1. `lib/theme/app_theme.dart` — Color token classes, 8 themes, ThemeData builder
2. `lib/providers/theme_provider.dart` — Riverpod provider for active theme + dark mode

## Files to Update

1. `pubspec.yaml` — add `google_fonts` package
2. `lib/main.dart` — wire theme provider
3. `lib/presentation/workout_list_screen.dart` — custom header, card redesign, FAB, empty state
4. `lib/presentation/create_workout.dart` — exercise edit cards with 4-field grid, preview screen
5. `lib/presentation/workout_session_screen.dart` — hero numbers, progress dots, rest timer ring
6. `lib/presentation/history_screen.dart` — redesigned session cards
7. `lib/presentation/session_detail_screen.dart` — styled set rows

---

## Screen-by-Screen Changes

### Workout List (Home)
- Remove AppBar → custom header with large "Workouts" title (44px Space Grotesk)
- Date in small uppercase muted text
- SwatchGlyph icon → opens Appearance picker bottom sheet
- History icon → navigate to history
- Workout cards: rounded-20, surface bg, soft shadow, 44×44 icon tile, display-font title
- FAB: accent colour, elevated shadow, `+` icon

### Empty State
- Centered, dashed circle (80×80) with dumbbell icon
- "Nothing here yet." in display font (28px)
- Description text, primary button "Create your first workout"

### Create/Edit Workout
- Custom header bar with back + check icons
- Workout name field: display font, 28px, underline only
- Exercise list: label "EXERCISES" + count
- Each exercise card: index pill, name, 4-cell grid (Sets/Reps/Weight/Rest)
- Add exercise: dashed outline button
- Sticky bottom CTA: "Preview workout →"

### Workout Preview
- Summary stats grid (duration / sets / volume) 
- Set sequence as rows grouped by exercise
- Sticky bottom: Edit + Save Workout buttons

### Delete Confirmation
- Bottom sheet modal over blurred list
- Drag handle, title "Delete 'X'?", description, Cancel + Delete buttons

### Active Workout
- Close button + elapsed time in header
- Progress dots (set tracking)
- Hero exercise name (30px)
- Hero numbers: reps + weight (84px)
- "Next exercise" caption
- Big "Set complete ✓" button (64h, accent bg)

### Rest Timer
- Circular SVG progress ring (accent stroke)
- Countdown in display font (76px)
- "Up next" card below ring
- +15s / Skip rest buttons

### Appearance Picker (bottom sheet)
- Title "Appearance" + close button
- 4×2 grid of theme tiles (mini mockup per tile)
- Light/Dark segmented control
- "Done" button
