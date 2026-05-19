import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../models/event_model.dart';

class EventNotificationService {
  EventNotificationService._();
  static final EventNotificationService instance = EventNotificationService._();

  static const _prefKey = 'event_notifications_enabled';
  // v2: channel recreated so Samsung picks up Importance.max
  static const _channelId = 'event_reminders_v2';
  static const _channelName = 'Event Reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? _android;
  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tzdata.initializeTimeZones();
    _prefs = await SharedPreferences.getInstance();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Delete the old channel so the device doesn't use cached (lower) importance.
    await _android?.deleteNotificationChannel('event_reminders');

    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    ));

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await _android?.requestNotificationsPermission();

    // Request exact-alarm permission (Android 12+).
    final canExact = await _android?.canScheduleExactNotifications() ?? true;
    if (!canExact) {
      await _android?.requestExactAlarmsPermission();
    }

    // Battery optimisation exemption — Samsung/Xiaomi/OnePlus kill the
    // AlarmManager BroadcastReceiver when the app is in the battery-restricted
    // group, silently dropping scheduled notifications.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  bool get isEnabled => _prefs?.getBool(_prefKey) ?? true;

  Future<void> setEnabled(bool value) async {
    await _prefs?.setBool(_prefKey, value);
  }

  Future<void> scheduleForEvents(List<EventModel> events) async {
    if (_prefs == null) return;
    await _plugin.cancelAll();
    if (!isEnabled) return;
    if (!await _canScheduleExact()) return;
    for (final event in events) {
      await _scheduleEvent(event);
    }
  }

  Future<bool> _canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  // ── Countdown auto-start alarm ─────────────────────────────────────────────

  static const _countdownNotifId = 999998;

  /// Schedules an AlarmManager-backed alarm at [eventStartMs].
  /// When it fires, a fullScreenIntent notification brings the app to foreground
  /// so [didChangeAppLifecycleState(resumed)] can auto-start tracking.
  Future<void> scheduleCountdownAutoStart(int eventStartMs) async {
    await _plugin.cancel(_countdownNotifId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (eventStartMs <= nowMs) return;
    final target = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, eventStartMs);
    try {
      await _plugin.zonedSchedule(
        _countdownNotifId,
        '🏃 Time to Run!',
        'Your event has started — opening RunMate now.',
        target,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed countdown auto-start alarm: $e');
    }
  }

  Future<void> cancelCountdownAutoStart() async {
    await _plugin.cancel(_countdownNotifId);
  }

  // ── Per-event reminders ────────────────────────────────────────────────────

  Future<void> _scheduleEvent(EventModel event) async {
    final eventTime = event.eventDateTime;
    if (eventTime.isBefore(DateTime.now())) return;

    final base = event.id.hashCode.abs() % 500000;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final eventMs = eventTime.millisecondsSinceEpoch;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    // 24-hour reminder
    final time24h = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, eventMs - const Duration(hours: 24).inMilliseconds);
    if (time24h.millisecondsSinceEpoch > nowMs) {
      try {
        await _plugin.zonedSchedule(
          base * 2,
          event.name,
          'Event starts tomorrow at ${_formatTime(eventTime)}',
          time24h,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('Scheduled 24h reminder for "${event.name}" at $time24h');
      } catch (e) {
        debugPrint('Failed 24h schedule: $e');
      }
    }

    // 5-minute reminder
    final time5m = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, eventMs - const Duration(minutes: 5).inMilliseconds);
    if (time5m.millisecondsSinceEpoch > nowMs) {
      try {
        await _plugin.zonedSchedule(
          base * 2 + 1,
          event.name,
          'Event starts in 5 minutes at ${_formatTime(eventTime)}',
          time5m,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('Scheduled 5m reminder for "${event.name}" at $time5m');
      } catch (e) {
        debugPrint('Failed 5m schedule: $e');
      }
    }

    // At-start notification — only when a specific start time is set
    if (event.startTime.isNotEmpty) {
      final timeStart = tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.UTC, eventMs);
      if (timeStart.millisecondsSinceEpoch > nowMs) {
        try {
          await _plugin.zonedSchedule(
            base * 2 + 2,
            '🏃 ${event.name}',
            'The event has started! Good luck!',
            timeStart,
            details,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('Scheduled start notification for "${event.name}" at $timeStart');
        } catch (e) {
          debugPrint('Failed start schedule: $e');
        }
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
