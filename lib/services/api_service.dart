import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static const _keyToken = 'auth_token';

  /// Callback déclenché automatiquement lors d'un 401 (session expirée).
  static void Function()? onUnauthorized;

  // ── Token ────────────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyToken);
  }

  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyToken, token);
  }

  static Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyToken);
  }

  static String get _base => '${AppConfig.apiBaseUrl}/api/v1';

  // ── Requête générique ────────────────────────────────────────────────────────

  static Future<dynamic> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final base = _base;
    final token = auth ? await getToken() : null;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$base$endpoint');
    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
        case 'POST':
          response = await http
              .post(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(const Duration(seconds: 20));
        case 'PUT':
          response = await http
              .put(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(const Duration(seconds: 20));
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
        default:
          throw ApiException('Méthode non supportée.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          'Impossible de joindre le serveur. Vérifiez votre connexion.');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final msg = (json is Map && json['message'] != null)
        ? json['message'] as String
        : 'Erreur ${response.statusCode}';
    if (response.statusCode == 401) {
      await clearToken();
      onUnauthorized?.call();
    }
    throw ApiException(msg, statusCode: response.statusCode);
  }

  // ── Upload multipart ─────────────────────────────────────────────────────────

  static Future<dynamic> uploadFile(
      String endpoint, File file, String field) async {
    final base = _base;
    final token = await getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$base$endpoint'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';
    req.files.add(await http.MultipartFile.fromPath(field, file.path));
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final msg = (json is Map && json['message'] != null)
        ? json['message'] as String
        : 'Erreur upload';
    throw ApiException(msg, statusCode: response.statusCode);
  }

  // ── Test connexion ───────────────────────────────────────────────────────────

  static Future<bool> testConnection() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/v1/setup/status'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkSetup() async =>
      await request('GET', '/setup/status', auth: false)
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> login(
          String email, String password) async =>
      await request('POST', '/auth/login',
          body: {'email': email, 'password': password},
          auth: false) as Map<String, dynamic>;

  static Future<void> logout() async {
    try {
      await request('POST', '/auth/logout');
    } catch (_) {}
    await clearToken();
  }

  static Future<Map<String, dynamic>> getProfile() async =>
      await request('GET', '/auth/profile') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateProfile(
          Map<String, dynamic> data) async =>
      await request('PUT', '/auth/profile', body: data) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> changePassword(
          Map<String, dynamic> data) async =>
      await request('POST', '/auth/change-password', body: data)
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> uploadProfilePhoto(File photo) async =>
      await uploadFile('/auth/profile/photo', photo, 'photo')
          as Map<String, dynamic>;

  static Future<void> deleteProfilePhoto() async =>
      await request('DELETE', '/auth/profile/photo');

  /// Récupère la photo de profil depuis l'API (retourne null si absente).
  /// L'endpoint retourne {"base64": "...", "mime_type": "..."}.
  static Future<Uint8List?> getProfilePhotoBytes() async {
    try {
      final data = await request('GET', '/auth/profile/photo') as Map<String, dynamic>;
      final b64 = data['base64'] as String?;
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null; // pas de photo
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Dashboard ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() async {
    final raw = await request('GET', '/dashboard/stats');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }
  // ── Employés ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUsers(
          {String? query, int page = 1}) async =>
      await request('GET',
              '/users?page=$page${query != null ? '&search=$query' : ''}')
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getUser(int id) async =>
      await request('GET', '/users/$id') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> createUser(
          Map<String, dynamic> data) async =>
      await request('POST', '/users', body: data) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateUser(
          int id, Map<String, dynamic> data) async =>
      await request('PUT', '/users/$id', body: data) as Map<String, dynamic>;

  static Future<void> deactivateUser(int id) async =>
      await request('POST', '/users/$id/deactivate');

  static Future<void> activateUser(int id) async =>
      await request('POST', '/users/$id/activate');

  static Future<void> resetPhoneDevice(int id) async =>
      await request('POST', '/users/$id/reset-device');

  static Future<Map<String, dynamic>> uploadUserPhoto(
          int id, File photo) async =>
      await uploadFile('/users/$id/photo', photo, 'photo')
          as Map<String, dynamic>;

  static Future<void> deleteUserPhoto(int id) async =>
      await request('DELETE', '/users/$id/photo');

  // ── Contrats ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getContracts(
          {int page = 1, String? status}) async =>
      await request('GET',
              '/contracts?page=$page${status != null ? '&status=$status' : ''}')
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getContract(int id) async =>
      await request('GET', '/contracts/$id') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> createContract(
          Map<String, dynamic> data) async =>
      await request('POST', '/contracts', body: data) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateContract(
          int id, Map<String, dynamic> data) async =>
      await request('PUT', '/contracts/$id', body: data)
          as Map<String, dynamic>;

  static Future<List<dynamic>> getMyContracts() async =>
      await request('GET', '/my-contracts') as List<dynamic>;

  static Future<Map<String, dynamic>> uploadContractPdf(
          int id, File pdf) async =>
      await uploadFile('/contracts/$id/pdf', pdf, 'pdf')
          as Map<String, dynamic>;

  /// Télécharge les octets bruts d'un fichier (PDF, image…) avec authentification.
  static Future<Uint8List> downloadBytes(String endpoint) async {
    final token = await getToken();
    final headers = <String, String>{
      'Accept': '*/*',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response = await http
        .get(Uri.parse('$_base$endpoint'), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException('Erreur téléchargement : ${response.statusCode}',
        statusCode: response.statusCode);
  }

  static Future<Uint8List> downloadContractPdf(int id) =>
      downloadBytes('/contracts/$id/pdf');

  // ── Pointage ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAttendances({String? params}) async =>
      await request('GET', '/attendance${params ?? ''}')
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getMyAttendance({String? params}) async =>
      await request('GET', '/my-attendance${params ?? ''}')
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateAttendance(
          int id, Map<String, dynamic> data) async =>
      await request('PUT', '/attendance/$id', body: data)
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> bulkAttendance(
          Map<String, dynamic> data) async =>
      await request('POST', '/attendance/bulk', body: data)
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> scanQr(String payload, String signature,
          {String? deviceId}) async =>
      await request('POST', '/attendance/scan-qr', body: {
        'payload': payload,
        'signature': signature,
        if (deviceId != null) 'phone_device_id': deviceId,
      }) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> scanMatricule(
          String matricule, String payload, String signature) async =>
      await request('POST', '/attendance/scan-matricule',
          body: {
            'matricule': matricule,
            'payload': payload,
            'signature': signature,
          },
          auth: false) as Map<String, dynamic>;

  static Future<List<dynamic>> getAttendanceSites() async =>
      await request('GET', '/sites') as List<dynamic>;

  // ── Congés ───────────────────────────────────────────────────────────────────

  static Future<dynamic> getLeavePlans(
          {int page = 1, String? status}) async =>
      await request('GET',
          '/leave-plans?page=$page${status != null ? '&status=$status' : ''}');

  static Future<Map<String, dynamic>> getMyLeavePlan() async =>
      await request('GET', '/my-leave-plan') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> createMyLeavePlan(
          Map<String, dynamic> data) async =>
      await request('POST', '/my-leave-plan', body: data)
          as Map<String, dynamic>;

  static Future<void> approveLeavePlan(int id) async =>
      await request('POST', '/leave-plans/$id/approve');

  static Future<void> rejectLeavePlan(int id, String reason) async =>
      await request('POST', '/leave-plans/$id/reject',
          body: {'reason': reason});

  // ── Demandes de contrat ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRequests({int page = 1, String? status}) async {
    final q = ['page=$page', if (status != null) 'status=$status'].join('&');
    return await request('GET', '/contract-requests?$q') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRequest(int id) async =>
      await request('GET', '/contract-requests/$id') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> createRequest(
          Map<String, dynamic> data) async =>
      await request('POST', '/contract-requests', body: data)
          as Map<String, dynamic>;

  static Future<void> approveRequest(int id, {String? comment}) async =>
      await request('POST', '/contract-requests/$id/approve',
          body: {'comment': comment});

  static Future<void> rejectRequest(int id, String reason) async =>
      await request('POST', '/contract-requests/$id/reject',
          body: {'reason': reason});

  // ── Notifications ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications({int page = 1}) async =>
      await request('GET', '/notifications?page=$page') as Map<String, dynamic>;

  static Future<int> getUnreadCount() async {
    final data = await request('GET', '/notifications/unread-count')
        as Map<String, dynamic>;
    return data['count'] ?? 0;
  }

  static Future<void> markAllRead() async =>
      await request('POST', '/notifications/mark-all-read');

  static Future<void> markRead(int id) async =>
      await request('POST', '/notifications/$id/read');

  // ── Jours fériés ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getHolidays() async =>
      await request('GET', '/attendance/holidays') as List<dynamic>;

  static Future<void> declareHoliday(Map<String, dynamic> data) async =>
      await request('POST', '/attendance/declare-holiday', body: data);
}
