import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/providers/theme_provider.dart';
import 'package:fitness_planner/theme/app_theme.dart';

/// Pumps [child] wrapped in the `ProviderScope`/`ProviderContainer` +
/// `AppThemeScope` + `MaterialApp` every presentation-layer screen expects,
/// then settles.
///
/// Pass [container] (built with your own overrides) when the widget under
/// test reads a provider synchronously in `initState` — build the container
/// first and `await container.read(someProvider.future)` before calling
/// this, so the provider has already resolved by the time `initState` runs.
/// When [container] is omitted, an internal `ProviderScope` is created from
/// [overrides] instead (simpler, but providers may still be loading during
/// the very first build).
///
/// Sets a wide phone-sized surface (rather than flutter_test's default
/// 800×600). Wider than a typical real device on purpose: the app's custom
/// fonts (SpaceGrotesk/Manrope) aren't loaded under `flutter_test`, so text
/// falls back to a substitute font with wider glyph metrics — several
/// screens overflow a true device width (~412) purely because of this test
/// artifact, not a real layout bug.
///
/// [overrides] is untyped (`Override` isn't part of riverpod 3.4.2's public
/// API surface) — pass a list of `xProvider.overrideWith(...)` calls as
/// usual; Dart's implicit dynamic downcast makes this work.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  dynamic overrides,
  ProviderContainer? container,
  Size surfaceSize = const Size(600, 915),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themed = AppThemeScope(
    appTheme: const ThemeState().appThemeData,
    child: MaterialApp(home: child),
  );

  await tester.pumpWidget(
    container != null
        ? UncontrolledProviderScope(container: container, child: themed)
        : ProviderScope(overrides: overrides ?? const [], child: themed),
  );
  await tester.pumpAndSettle();
}
