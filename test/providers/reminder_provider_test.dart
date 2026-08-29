import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_planner/providers/reminder_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('build() defaults to disabled, 18:00, when nothing is persisted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(reminderProvider.future);

    expect(state.enabled, isFalse);
    expect(state.time, const TimeOfDay(hour: 18, minute: 0));
  });

  test('setEnabled() persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(reminderProvider.future);

    await container.read(reminderProvider.notifier).setEnabled(true);

    expect(container.read(reminderProvider).value?.enabled, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reminder_enabled'), isTrue);
  });

  test('setTime() persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(reminderProvider.future);

    await container.read(reminderProvider.notifier).setTime(const TimeOfDay(hour: 7, minute: 30));

    expect(container.read(reminderProvider).value?.time, const TimeOfDay(hour: 7, minute: 30));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('reminder_hour'), 7);
    expect(prefs.getInt('reminder_minute'), 30);
  });

  test('a fresh notifier reads back previously persisted values', () async {
    final first = ProviderContainer();
    await first.read(reminderProvider.future);
    await first.read(reminderProvider.notifier).setEnabled(true);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final state = await second.read(reminderProvider.future);

    expect(state.enabled, isTrue);
  });
}
