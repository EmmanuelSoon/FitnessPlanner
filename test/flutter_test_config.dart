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
// Keep this in sync with the weights declared in pubspec.yaml.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600]) {
    GoogleFonts.spaceGrotesk(fontWeight: w);
    GoogleFonts.jetBrainsMono(fontWeight: w);
  }
  for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    GoogleFonts.manrope(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();

  return testMain();
}
