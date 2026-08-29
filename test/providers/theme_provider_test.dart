import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_planner/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('build() defaults to the mint theme, light mode, when nothing is persisted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(themeProvider.future);

    expect(state.themeKey, 'mint');
    expect(state.isDark, isFalse);
  });

  test('setThemeKey() persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.future);

    await container.read(themeProvider.notifier).setThemeKey('ocean');

    expect(container.read(themeProvider).value?.themeKey, 'ocean');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_key'), 'ocean');
  });

  test('setDark() persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.future);

    await container.read(themeProvider.notifier).setDark(true);

    expect(container.read(themeProvider).value?.isDark, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme_dark'), isTrue);
  });

  test('a fresh notifier reads back previously persisted values', () async {
    final first = ProviderContainer();
    await first.read(themeProvider.future);
    await first.read(themeProvider.notifier).setThemeKey('ocean');
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final state = await second.read(themeProvider.future);

    expect(state.themeKey, 'ocean');
  });
}
