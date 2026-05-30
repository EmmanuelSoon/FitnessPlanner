import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderState {
  final bool enabled;
  final TimeOfDay time;

  const ReminderState({
    this.enabled = false,
    this.time = const TimeOfDay(hour: 18, minute: 0),
  });

  ReminderState copyWith({bool? enabled, TimeOfDay? time}) => ReminderState(
    enabled: enabled ?? this.enabled,
    time: time ?? this.time,
  );
}

class ReminderNotifier extends AsyncNotifier<ReminderState> {
  static const _keyEnabled = 'reminder_enabled';
  static const _keyHour = 'reminder_hour';
  static const _keyMinute = 'reminder_minute';

  @override
  Future<ReminderState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderState(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      time: TimeOfDay(
        hour: prefs.getInt(_keyHour) ?? 18,
        minute: prefs.getInt(_keyMinute) ?? 0,
      ),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    state = AsyncData(state.value!.copyWith(enabled: enabled));
  }

  Future<void> setTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, time.hour);
    await prefs.setInt(_keyMinute, time.minute);
    state = AsyncData(state.value!.copyWith(time: time));
  }
}

final reminderProvider =
    AsyncNotifierProvider<ReminderNotifier, ReminderState>(ReminderNotifier.new);
