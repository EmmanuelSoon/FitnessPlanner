# 024 — Migrate to material_ui/cupertino_ui, unblock CI

## Context

PR #70 merged, but CI's "Upgrade & Analyze" job is failing. The workflow
floats on `channel: stable` with no pinned Flutter version, and
`flutter pub upgrade` lets it drift freely. Since the last green run
(2026-11-01, Flutter 3.47.9), the floating channel moved to 3.50.1, which
formally deprecates `package:flutter/material.dart` and
`package:flutter/cupertino.dart` in favor of standalone `material_ui` /
`cupertino_ui` packages. `flutter analyze` now reports 58 info-level
`deprecated_member_use` issues across nearly the whole repo and exits
non-zero — so `flutter test` and the APK build never even run.

Decision: migrate now rather than pin-and-defer. `pub get` (not
`pub upgrade`) becomes the PR-gate dependency step. One pinned CI job,
no separate floating-stable canary.

**Key constraint:** local Flutter is 3.44.6 — older than 3.47 (when
`material_ui` became consumable) and short of 3.50. The official migration
tool (`dart fix --apply --code=migrate_design_widgets`) and the
`material_ui`/`cupertino_ui` packages themselves require a current SDK, so
upgrading the local Flutter SDK is a hard prerequisite.

## Scope (as actually shipped — this plan was revised after review flagged
## the first draft was out of sync with the diff)

- 52 files import `package:flutter/material.dart`, 6 import
  `package:flutter/cupertino.dart`, **5 files import both**
  (`lib/presentation/calendar_screen.dart`,
  `lib/presentation/mesocycle_setup_screen.dart`,
  `lib/presentation/widgets/number_picker_sheet.dart`,
  `test/widgets/calendar_screen_test.dart`,
  `test/widgets/mesocycle_setup_screen_test.dart`) — all under `lib/` and
  `test/`. Bare import swap via the official `dart fix` code; no manual
  widget-by-widget changes were needed (stock `MaterialApp`/`ThemeData`/
  `Icons`/widgets throughout).
- No `flutter_localizations` dependency, so the localization-delegate part
  of the migration doesn't apply.
- `google_fonts` had to be upgraded 8.2.1 → 9.0.0: that's the first version
  returning `material_ui`-typed `TextTheme`/`ThemeData` instead of the old
  `flutter/material` types — without it, `flutter analyze` fails with a
  genuine `TextTheme`/`TextTheme?` type-mismatch error in
  `lib/theme/app_theme.dart`'s `buildMaterialTheme`.
- The `google_fonts` 9.0.0 upgrade surfaced a real test-flakiness bug: our
  bundled font asset filenames (`Manrope-SemiBold.ttf`, etc.) exactly match
  `google_fonts`' own naming convention, so it dynamically re-registers
  them via `FontLoader` on first use in each test file's isolate — firing
  a one-time "system fonts changed" message whose resulting frame callback
  arrives after the triggering test's pump returns. Flutter's test harness
  now fails a test if that callback is still pending right after teardown.
  Fixed via `test/flutter_test_config.dart`, which pre-warms every bundled
  weight (with `allowRuntimeFetching = false`, so a weight that isn't
  actually bundled fails there with a clear "not found in application
  assets" error, rather than later as an unrelated test's confusing
  "animation still running" failure) before any test builds a widget tree.
- `flutter build apk --debug` (CI's last gate) failed separately: the
  pinned Gradle wrapper (8.14) and Android Gradle Plugin (8.11.1) are below
  Flutter 3.50.1's minimums (Gradle ≥9.3.1, AGP ≥9.1.1). Bumped to the
  current `flutter create` template defaults — Gradle 9.5.0, AGP 9.3.1,
  Kotlin Gradle Plugin 2.4.20 — and moved the now-hard-error-deprecated
  `android { kotlinOptions {} }` block to the modern top-level
  `kotlin { compilerOptions {} }` DSL. (Not pursuing AGP 9's full "built-in
  Kotlin" migration now — our `health` dependency applies the Kotlin
  Gradle Plugin directly and hasn't been updated to support it yet; this
  is a backlog item, tracked by the warning Flutter's tooling prints on
  every build.)
- Running the real Android build locally produced an `android/build/`
  Gradle output directory that wasn't covered by `.gitignore` (only
  `/android/app/debug|profile|release` were) — added `/android/build/`.
- This is a refactor (mechanical import migration + CI/build config) for
  the import swap itself, but the font-loading fix and Gradle/AGP/Kotlin
  bump are genuine behavior/tooling fixes layered on top — no new tests
  were required for the import swap; the font-loading fix is covered by
  the full suite passing deterministically (previously non-deterministic
  per test file).

## Steps (as executed)

1. Upgrade local Flutter SDK (`flutter upgrade`) → landed on 3.50.1,
   matching what CI's floating channel had already picked up.
2. `flutter pub add material_ui cupertino_ui`.
3. `dart fix --apply --code=migrate_design_widgets` (58 fixes, 53 files).
   Re-grepped for leftover `flutter/material.dart` / `cupertino.dart`
   imports — none.
4. Hit a `TextTheme`/`TextTheme?` analyzer error from `google_fonts`
   8.2.1 still returning the old `flutter/material` type; bumped the
   `google_fonts` pubspec constraint to `^9.0.0` and re-resolved.
5. `flutter test` then failed ~44 tests non-deterministically (first test
   per file, different file each run) with "An animation is still running
   even after the widget tree was disposed" / `_scheduleSystemFontsUpdate`.
   Root-caused to the `google_fonts`/`FontLoader` interaction described
   above via a scratch repro test (written and discarded) rather than
   guessing; fixed with `test/flutter_test_config.dart`.
6. `flutter build apk --debug` failed on Gradle/AGP minimums; bumped
   `android/gradle/wrapper/gradle-wrapper.properties`,
   `android/settings.gradle.kts`, and moved `kotlinOptions` to
   `kotlin { compilerOptions {} }` in `android/app/build.gradle.kts`.
   Added `/android/build/` to `.gitignore`.
7. Pinned CI: `.github/workflows/flutter_ci.yml` now sets
   `flutter-version: 3.50.1` instead of a bare `channel: stable`, and
   runs `flutter pub get` instead of `flutter pub upgrade`.
8. Tightened `pubspec.yaml`'s `environment:` (`sdk: ^3.14.0`,
   `flutter: '>=3.50.1'`) and updated `README.md`'s stated Flutter version
   to match.
9. Verified locally: `flutter analyze` (0 issues), `flutter test` (499
   passing), `flutter build apk --debug` (succeeds). Opened PR #71;
   confirmed the GitHub Actions run went green end to end.

## Files touched

- `lib/**/*.dart`, `test/**/*.dart` — import swaps via `dart fix`.
- `pubspec.yaml` / `pubspec.lock` — `material_ui`, `cupertino_ui` added;
  `google_fonts` bumped to `^9.0.0`; tightened `environment:`.
- `test/flutter_test_config.dart` — new; pre-warms bundled font weights.
- `test/support/pump_app.dart` — removed a comment that had attributed the
  600×915 test surface size to fonts not loading under `flutter_test`,
  which this migration makes untrue (confirmed by testing a true
  412-wide surface afterward: still fails for unrelated, pre-existing
  width reasons, so the surface size itself is unchanged).
- `.github/workflows/flutter_ci.yml` — pin exact Flutter version, switch
  `pub upgrade` → `pub get --enforce-lockfile` (the plain form let CI
  silently rewrite `pubspec.lock` on the runner and pass on uncommitted
  versions).
- `android/gradle/wrapper/gradle-wrapper.properties`,
  `android/settings.gradle.kts`, `android/app/build.gradle.kts` — Gradle
  9.5.0, AGP 9.3.1, Kotlin 2.4.20; `kotlinOptions` → `compilerOptions`.
- `.gitignore` — add `/android/build/`.
- `README.md` — update stated Flutter version requirement.

## Verification

- `flutter analyze` clean (0 issues).
- `flutter test` fully green (499 tests).
- `flutter build apk --debug` succeeds.
- PR #71's GitHub Actions run passed end to end (analyze → test → build).

## Known follow-ups (not done here)

- AGP 9's "built-in Kotlin" migration (removing the standalone
  `kotlin-android` plugin) is blocked on the `health` package applying
  the Kotlin Gradle Plugin directly; Flutter's tooling auto-added
  `android.builtInKotlin=false` / `android.newDsl=false` opt-outs to
  `android/gradle.properties` as a stopgap. Revisit once `health` supports
  it, or if Flutter's deprecation warning becomes a hard error.
