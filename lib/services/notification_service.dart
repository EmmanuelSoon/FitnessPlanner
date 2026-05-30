import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/models/mesocycle.dart';
import '../domain/models/day_override.dart';
import '../domain/models/workout.dart';
import '../domain/schedule/schedule_logic.dart';

const _channelId = 'workout_reminders';
const _channelName = 'Workout Reminders';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fall back to UTC if timezone detection fails.
    }

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Create the notification channel (required on Android 8+).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Pre-workout reminders from PlateUp',
          importance: Importance.high,
        ));
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // Cancels all pending notifications and re-schedules the next [horizonDays]
  // days that have a workout assigned. Notifications fire at [time] on each
  // day. Uses inexact scheduling (no exact-alarm permission required).
  Future<void> rescheduleAll({
    required Mesocycle? meso,
    required DayOverride? Function(DateTime) overrideForDate,
    required List<Workout> workouts,
    required TimeOfDay time,
    required bool enabled,
    int horizonDays = 21,
  }) async {
    await _plugin.cancelAll();
    if (!enabled || meso == null) return;

    final workoutMap = {for (final w in workouts) w.id: w};
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < horizonDays; i++) {
      final day = today.add(Duration(days: i));
      final workoutId = workoutIdForDate(meso, overrideForDate(day), day);
      if (workoutId == null) continue;

      final workoutName = workoutMap[workoutId]?.name ?? 'Workout';
      final scheduledDate = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (scheduledDate.isBefore(now)) continue;

      await _plugin.zonedSchedule(
        i,
        'Time to prep for your workout!',
        workoutName,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Pre-workout reminders from PlateUp',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
