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

**Why this is lower-risk than it looks:** none of this app's other
dependencies (`flutter_riverpod`, `hive_flutter`, `google_fonts`,
`shared_preferences`, `flutter_launcher_icons`, `wakelock_plus`,
`audioplayers`, `vibration`, `flutter_local_notifications`, `timezone`,
`flutter_timezone`, `health`) inject Material/Cupertino widgets into the
app's own widget tree — they're plugins or pure data/style helpers. So
`MaterialUiCompatibilityBridge` should not be necessary here. Confirmed
empirically via a clean `flutter analyze` after migration, not assumed.

## Scope

- 52 files import `package:flutter/material.dart`, 6 import
  `package:flutter/cupertino.dart` (3 overlap) — all under `lib/` and
  `test/`. Bare import swap via the official `dart fix` code; no manual
  widget-by-widget changes expected (stock `MaterialApp`/`ThemeData`/
  `Icons`/widgets throughout — confirmed via `lib/main.dart`,
  `lib/theme/app_theme.dart`, `test/support/pump_app.dart`).
- No `flutter_localizations` dependency, so the localization-delegate part
  of the migration doesn't apply.
- This is a refactor (mechanical import migration + CI config) — no new
  tests required, but the full existing suite must stay green.

## Steps

1. Upgrade local Flutter SDK (`flutter upgrade`), record the resulting
   exact version.
2. `flutter pub add material_ui cupertino_ui`.
3. `dart fix --dry-run --code=migrate_design_widgets` to preview, then
   `dart fix --apply --code=migrate_design_widgets`. Re-grep for any
   leftover `flutter/material.dart` / `cupertino.dart` imports.
4. Verify locally in order: `flutter analyze` (0 issues) → `flutter test`
   (full suite green) → `flutter build apk --debug` (compiles).
5. Pin the SDK version for reproducibility:
   - `pubspec.yaml`: tighten `environment:` with the new minimum.
   - `.github/workflows/flutter_ci.yml`: add `flutter-version: <exact>` to
     the `subosito/flutter-action@v2` step, replacing `channel: stable`;
     change `flutter pub upgrade` → `flutter pub get`.
   - `README.md`: update the stated Flutter SDK requirement.
6. Commit, push, open PR (`chore: migrate to material_ui/cupertino_ui and
   pin Flutter CI version`).

## Files touched

- `lib/**/*.dart`, `test/**/*.dart` — import swaps only, via `dart fix`.
- `pubspec.yaml` / `pubspec.lock` — new deps, tightened `environment:`.
- `.github/workflows/flutter_ci.yml` — pin exact Flutter version, switch
  `pub upgrade` → `pub get`.
- `README.md` — update stated Flutter version requirement.

## Verification

- `flutter analyze` clean (0 issues).
- `flutter test` fully green (499 tests at time of writing).
- `flutter build apk --debug` succeeds.
- Push and confirm the GitHub Actions run on the PR goes green end to end.

## Non-goals

- Not adding a scheduled/canary workflow against floating stable.
- Not introducing `MaterialUiCompatibilityBridge` unless `flutter analyze`
  or runtime testing actually shows it's needed.
