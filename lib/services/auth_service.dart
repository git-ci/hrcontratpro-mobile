import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static Map<String, dynamic>? _user;
  static String? _token;
  static String? _role;


  static Map<String, dynamic>? get user  => _user;
  static String?               get token => _token;
  static String?               get role  => _role;
  static bool get isLoggedIn => _token != null && _user != null;

  static bool get isDG  => _role == 'dg';
  static bool get isRH  => _role == 'rh';
  static bool get isEmp => _role == 'employee';

  // ── Chargement au démarrage ──────────────────────────────────────────────────

  static Future<bool> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userStr = prefs.getString('auth_user');
    if (_token != null && userStr != null) {
      try {
        _user = jsonDecode(userStr) as Map<String, dynamic>;
        _role = _user?['role'] as String?;
        return true;
      } catch (_) {}
    }
    return false;
  }

  // ── Login ────────────────────────────────────────────────────────────────────

  static Future<void> login(String email, String password) async {
    final data = await ApiService.login(email, password);
    _token = data['token'] as String?;
    _user  = data['user'] as Map<String, dynamic>?;
    _role  = _user?['role'] as String?;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token ?? '');
    await prefs.setString('auth_user', jsonEncode(_user));
    await ApiService.saveToken(_token ?? '');
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    try { await ApiService.logout(); } catch (_) {}
    await clearSession();
  }

  /// Nettoie la session localement (sans appel API) — utilisé sur 401.
  static Future<void> clearSession() async {
    _token = null;
    _user  = null;
    _role  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await ApiService.clearToken();
  }

  // ── Refresh profil ───────────────────────────────────────────────────────────

  static Future<void> refreshProfile() async {
    try {
      final data = await ApiService.getProfile();
      _user = data;
      _role = _user?['role'] as String?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(_user));
    } catch (_) {}
  }

  // ── Route initiale selon le rôle ─────────────────────────────────────────────

  static String get initialRoute {
    switch (_role) {
      case 'dg':       return '/dg/dashboard';
      case 'rh':       return '/rh/dashboard';
      case 'employee': return '/emp/dashboard';
      default:         return '/login';
    }
  }
}
