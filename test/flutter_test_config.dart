import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Our bundled font assets (pubspec.yaml's `flutter: fonts:` section) use the
// exact filenames google_fonts expects (e.g. "Manrope-SemiBold.ttf"), so the
// first time a weight is used, google_fonts dynamically re-registers it via
// FontLoader — which fires a one-time "system fonts changed" message. That
// message arrives asynchronously, scheduling a frame callback after the
// triggering test's final pump returns, which Flutter's test harness now
// flags as a leaked callback and fails the test on. Loading every bundled
// weight here, before any test builds a widget tree, absorbs that one-time
// callback while no listeners exist yet, so it never leaks into a real test.
//
// Keep [_bundledWeights] in sync with pubspec.yaml's `flutter: fonts:`
// section. allowRuntimeFetching is off (matching main.dart) so a weight
// missing from that section fails here with a clear "not found in the
// application assets" error, instead of surfacing later as an unrelated
// test's confusing "animation still running" failure.
const _bundledWeights = [FontWeight.w400, FontWeight.w500, FontWeight.w600];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final w in _bundledWeights) {
    GoogleFonts.spaceGrotesk(fontWeight: w);
    GoogleFonts.manrope(fontWeight: w);
    GoogleFonts.jetBrainsMono(fontWeight: w);
  }
  GoogleFonts.manrope(fontWeight: FontWeight.w700); // Manrope-Bold.ttf only.

  await GoogleFonts.pendingFonts();

  return testMain();
}
