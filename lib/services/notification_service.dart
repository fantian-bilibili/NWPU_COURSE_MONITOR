import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  Future<void> initialize() async {
    if (_initialized || !_supported) {
      return;
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const WindowsInitializationSettings windowsInit =
        WindowsInitializationSettings(
          appName: 'NWPU Course Monitor',
          appUserModelId: 'HClO3.NWPU.CourseMonitor.1',
          guid: '0de31c39-bf09-4d76-8ed3-5fcbf4b26f71',
        );
    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      windows: windowsInit,
    );
    await _plugin.initialize(settings: settings);
    await _requestPermission();
    await _configureTimezone();
    _initialized = true;
  }

  Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    try {
      final TimezoneInfo timezoneInfo =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> _requestPermission() async {
    if (!_supported) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> reschedule({
    required List<Course> courses,
    required AppSettings settings,
    required DateTime now,
  }) async {
    if (!_supported) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    await _plugin.cancelAll();

    if (settings.reminderMinutesBefore <= 0) {
      return;
    }

    final DateTime dateOnlyNow = DateTime(now.year, now.month, now.day);
    for (int day = 0; day < 21; day++) {
      final DateTime date = dateOnlyNow.add(Duration(days: day));
      final List<Course> dayCourses = courses
          .where(
            (Course course) => course.sessions.any(
              (CourseSession session) =>
                  session.occursOn(date, settings.termStartMonday),
            ),
          )
          .toList();

      for (final Course course in dayCourses) {
        for (final CourseSession session in course.sessions) {
          if (!session.occursOn(date, settings.termStartMonday)) {
            continue;
          }
          final DateTime? classStart = _classStartAt(
            date: date,
            startPeriod: session.startPeriod,
            settings: settings,
          );
          if (classStart == null) {
            continue;
          }
          final DateTime remindAt = classStart.subtract(
            Duration(minutes: settings.reminderMinutesBefore),
          );
          if (!remindAt.isAfter(now)) {
            continue;
          }

          final int notificationId =
              (course.id.hashCode ^ remindAt.millisecondsSinceEpoch) &
              0x7fffffff;
          await _plugin.zonedSchedule(
            id: notificationId,
            title: '即将上课: ${course.name}',
            body:
                '${settings.reminderMinutesBefore} 分钟后开始，地点 ${course.location.isEmpty ? '未设置' : course.location}',
            scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'course_reminders',
                '课程提醒',
                channelDescription: '课程开始前提醒',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
              windows: WindowsNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    }
  }

  DateTime? _classStartAt({
    required DateTime date,
    required int startPeriod,
    required AppSettings settings,
  }) {
    final int? startMinutes = periodStartMinutesAt(settings, startPeriod);
    if (startMinutes == null) {
      return null;
    }
    final int safe = startMinutes.clamp(0, 24 * 60 - 1);
    return DateTime(date.year, date.month, date.day, safe ~/ 60, safe % 60);
  }
}
