import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _key = 'app_device_uuid';
  static String? _cached;

  /// Retourne l'UUID unique de cette installation.
  /// Généré une seule fois au premier appel, puis persisté.
  static Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(_key);
    if (stored == null || stored.isEmpty) {
      stored = const Uuid().v4();
      await prefs.setString(_key, stored);
    }
    _cached = stored;
    return stored;
  }
}
