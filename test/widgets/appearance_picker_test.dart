import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_planner/presentation/widgets/appearance_picker.dart';
import 'package:fitness_planner/providers/theme_provider.dart';

import '../support/pump_app.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.future);
  });

  Future<void> pumpOpener(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(builder: (context) {
        return TextButton(
          onPressed: () => showAppearancePicker(context),
          child: const Text('open'),
        );
      }),
      container: container,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows every color theme and the current mode', (tester) async {
    await pumpOpener(tester);

    expect(find.text('Mint'), findsOneWidget);
    expect(find.text('Sky'), findsOneWidget);
    expect(find.text('Lavender'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('picking a theme tile updates themeProvider.themeKey', (tester) async {
    await pumpOpener(tester);

    await tester.tap(find.text('Sky'));
    await tester.pumpAndSettle();

    expect(container.read(themeProvider).value?.themeKey, 'sky');
  });

  testWidgets('picking Dark updates themeProvider.isDark', (tester) async {
    await pumpOpener(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(themeProvider).value?.isDark, isTrue);
  });

  testWidgets('Done closes the sheet', (tester) async {
    await pumpOpener(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNothing);
  });
}
