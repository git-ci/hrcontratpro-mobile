import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'api_service.dart';
import 'auth_service.dart';

class CheckinReminderService {
  static const _channelId = 'checkin_reminder';
  static const _channelName = 'Rappel pointage d\'arrivée';
  static const _notificationId = 2000;
  static const _legacyNotificationCount = 7;
  static const _lastReminderDateKey = 'checkin_reminder_last_date';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  static Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      if (await android?.canScheduleExactNotifications() == false) {
        await android?.requestExactAlarmsPermission();
      }
    }
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Programme un rappel unique 15 minutes avant la fermeture du pointage.
  static Future<void> scheduleReminders() async {
    try {
      await cancelReminders();
      if (!AuthService.isLoggedIn) return;

      final now = DateTime.now();
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        return;
      }

      if (await _isCheckedInToday()) return;

      final deadline = await _fetchEarliestDeadline();
      if (deadline == null || now.isAfter(deadline)) return;

      final reminderTime = deadline.subtract(const Duration(minutes: 15));
      final deadlineLabel = '${deadline.hour.toString().padLeft(2, '0')}h'
          '${deadline.minute.toString().padLeft(2, '0')}';
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Rappel 15 minutes avant la fermeture du pointage d\'arrivée',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final today = _dateKey(now);
      final lastReminderDate = prefs.getString(_lastReminderDateKey);

      if (!reminderTime.isAfter(now)) {
        if (lastReminderDate != today) {
          final remaining = deadline.difference(now).inMinutes;
          await _plugin.show(
            _notificationId,
            '⏰ Rappel pointage',
            'Il vous reste $remaining min avant la fermeture ($deadlineLabel). Pointez maintenant !',
            details,
          );
          await prefs.setString(_lastReminderDateKey, today);
        }
        return;
      }

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canScheduleExactly = Platform.isAndroid &&
          await android?.canScheduleExactNotifications() == true;
      if (Platform.isAndroid && !canScheduleExactly) {
        developer.log(
          'Exact alarms unavailable; scheduling the check-in reminder inexactly.',
          name: 'CheckinReminderService',
          level: 900,
        );
      }

      await _plugin.zonedSchedule(
        _notificationId,
        '⏰ Rappel pointage',
        'Il vous reste 15 min avant la fermeture ($deadlineLabel). Pointez maintenant !',
        tz.TZDateTime.from(reminderTime, tz.local),
        details,
        androidScheduleMode: canScheduleExactly
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await prefs.setString(_lastReminderDateKey, today);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to schedule the check-in reminder.',
        name: 'CheckinReminderService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> cancelReminders() async {
    final failedIds = <int>[];
    Object? firstError;
    StackTrace? firstStackTrace;
    for (var id = _notificationId;
        id < _notificationId + _legacyNotificationCount;
        id++) {
      try {
        await _plugin.cancel(id);
      } catch (error, stackTrace) {
        failedIds.add(id);
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (failedIds.isNotEmpty) {
      developer.log(
        'Could not cancel reminder notifications: ${failedIds.join(', ')}.',
        name: 'CheckinReminderService',
        error: firstError,
        stackTrace: firstStackTrace,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<bool> _isCheckedInToday() async {
    final now = DateTime.now();
    final todayStr = _dateKey(now);
    final data = await ApiService.getMyAttendance();
    final records = data['records'] as List;

    return records.any((r) =>
        r['date'] == todayStr &&
        (r['status'] == 'present' ||
            r['status'] == 'retard' ||
            r['status'] == 'mission'));
  }

  static Future<DateTime?> _fetchEarliestDeadline() async {
    final sites = await ApiService.getAttendanceSites();
    String? earliest;
    for (final site in sites) {
      if (site['active'] != true) continue;
      final deadline = site['checkin_deadline'] as String?;
      if (deadline != null &&
          deadline.isNotEmpty &&
          (earliest == null || deadline.compareTo(earliest) < 0)) {
        earliest = deadline;
      }
    }
    if (earliest == null) return null;

    final parts = earliest.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid check-in deadline: $earliest');
    }
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
