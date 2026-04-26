import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

// Handler exécuté en arrière-plan (top-level, hors isolate Flutter)
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Pas d'accès au contexte Flutter ici — FCM affiche lui-même la notification
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  static final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'hrcontrat_push';
  static const _channelName = 'HrContratPro';

  static Future<void> init() async {
    // Enregistrer le handler background
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Demander la permission (iOS + Android 13+)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Canal Android haute priorité
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialiser flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotif.initialize(initSettings);

    // Notification reçue quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif == null) return;
      _localNotif.show(
        msg.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    // Envoyer le token FCM au backend
    await _registerToken();

    // Écouter les renouvellements de token
    _messaging.onTokenRefresh.listen(_sendTokenToBackend);
  }

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (_) {
      // getToken() échoue sur simulateur iOS (pas d'APNs) — on ignore
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService.saveFcmToken(token);
    } catch (_) {}
  }

  static Future<void> deleteFcmToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
