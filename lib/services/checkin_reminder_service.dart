import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'api_service.dart';
import 'auth_service.dart';

class CheckinReminderService {
  static const _channelId   = 'checkin_reminder';
  static const _channelName = 'Rappel pointage d\'arrivée';
  static const _baseId      = 2000; // IDs 2000–2006

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
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Planifie jusqu'à 7 rappels toutes les 5 min dans la fenêtre [deadline-30min, deadline[.
  /// Ne fait rien si : week-end, déjà pointé, ou heure dépassée.
  static Future<void> scheduleReminders() async {
    if (!AuthService.isLoggedIn) return;

    try {
      await cancelReminders();

      final now = DateTime.now();
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        return;
      }

      if (await _isCheckedInToday()) return;

      final deadline = await _fetchEarliestDeadline();
      if (deadline == null || now.isAfter(deadline)) return;

      final windowStart = deadline.subtract(const Duration(minutes: 30));
      final local = tz.local;

      // Si on est déjà dans la fenêtre, partir de la prochaine tranche de 5 min
      DateTime slot;
      if (now.isAfter(windowStart)) {
        final nextMin = ((now.minute ~/ 5) + 1) * 5;
        final addHour = nextMin >= 60;
        slot = DateTime(
          now.year, now.month, now.day,
          now.hour + (addHour ? 1 : 0),
          addHour ? nextMin - 60 : nextMin,
        );
      } else {
        slot = windowStart;
      }

      final deadlineLabel =
          '${deadline.hour.toString().padLeft(2, '0')}h'
          '${deadline.minute.toString().padLeft(2, '0')}';

      int id = _baseId;
      while (slot.isBefore(deadline) && id < _baseId + 7) {
        final remaining = deadline.difference(slot).inMinutes;
        await _plugin.zonedSchedule(
          id++,
          '⏰ Rappel pointage',
          'Il vous reste $remaining min avant la fermeture ($deadlineLabel). Pointez maintenant !',
          tz.TZDateTime.from(slot, local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription:
                  'Rappels avant la fermeture du pointage d\'arrivée',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: false,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        slot = slot.add(const Duration(minutes: 5));
      }
    } catch (_) {
      // Fonctionnalité non critique — silencieux
    }
  }

  static Future<void> cancelReminders() async {
    for (int i = _baseId; i < _baseId + 7; i++) {
      await _plugin.cancel(i);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<bool> _isCheckedInToday() async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final data = await ApiService.getMyAttendance();
      final records = (data['records'] as List?) ?? [];

      return records.any((r) =>
          r['date'] == todayStr &&
          (r['status'] == 'present' || r['status'] == 'mission'));
    } catch (_) {
      return false;
    }
  }

  static Future<DateTime?> _fetchEarliestDeadline() async {
    try {
      final sites = await ApiService.getAttendanceSites();
      if (sites.isEmpty) return null;

      String? earliest;
      for (final site in sites) {
        final d = site['checkin_deadline'] as String?;
        if (d != null && d.isNotEmpty) {
          if (earliest == null || d.compareTo(earliest) < 0) earliest = d;
        }
      }

      final hhmm = earliest ?? '10:00';
      final parts = hhmm.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year, now.month, now.day,
        int.parse(parts[0]),
        int.parse(parts.length > 1 ? parts[1] : '0'),
      );
    } catch (_) {
      return null;
    }
  }
}
