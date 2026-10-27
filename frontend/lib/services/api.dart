// Talks to the SignBridge FastAPI backend. All screens use Api.I - no URLs anywhere else.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data.dart';

class ApiException implements Exception {
  final int status; // 0 = could not reach the server
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api I = Api._();

  /// Override when needed:  flutter run --dart-define=API_URL=http://192.168.1.20:8000
  static const String _envUrl = String.fromEnvironment('API_URL');
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000'; // Android emulator -> your PC
    return 'http://localhost:8000'; // Chrome / desktop
  }

  String? _token;
  Map<String, dynamic>? user;

  String? get token => _token;
  bool get isLoggedIn => _token != null && user != null;
  String get role => (user?['role'] as String?) ?? 'hearing';

  /// ws://... address for websockets (same host as the REST API)
  String wsUrl(String path) => baseUrl.replaceFirst(RegExp(r'^http'), 'ws') + path;
  String get fullName => (user?['full_name'] as String?) ?? '';
  String get email => (user?['email'] as String?) ?? '';
  String get language => (user?['preferred_language'] as String?) ?? 'en';
  String get firstName {
    final n = fullName.trim();
    return n.isEmpty ? '' : n.split(RegExp(r'\s+')).first;
  }

  // ---------- token storage ----------
  Future<void> _saveToken(String? t) async {
    _token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  /// Called on app start: loads the saved token and checks it with the server.
  Future<bool> restore() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
    if (_token == null) return false;
    try {
      user = Map<String, dynamic>.from(await _request('GET', '/users/me') as Map);
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) await _saveToken(null); // token expired or user deleted
      return false;
    }
  }

  // ---------- low level ----------
  String _errorText(dynamic body, int status) {
    if (body is Map && body['detail'] != null) {
      final d = body['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        final first = d.first as Map;
        final loc = (first['loc'] is List) ? (first['loc'] as List).last.toString() : '';
        return '${loc.isEmpty ? '' : '$loc: '}${first['msg']}';
      }
    }
    return 'Request failed ($status)';
  }

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    http.Response res;
    try {
      final req = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/json';
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 15)));
    } catch (_) {
      throw ApiException(0, 'Cannot reach the server at $baseUrl. Is the backend running?');
    }
    dynamic data;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(res.statusCode, _errorText(data, res.statusCode));
  }

  // ---------- auth ----------
  /// Asks the backend whether Firebase login is switched on.
  Future<void> loadConfig() async {
    try {
      final c = await _request('GET', '/auth/config') as Map;
      AppConfig.backendFirebase = c['firebase'] == true;
    } catch (_) {/* backend offline - the login screen will say so */}
  }

  /// Sends the Firebase ID token to the backend. Returns true when the account was just created.
  Future<bool> firebaseLogin(String idToken, {String? role, String? fullName, String language = 'en'}) async {
    final data = await _request('POST', '/auth/firebase',
        body: {'id_token': idToken, if (role != null) 'role': role, if (fullName != null) 'full_name': fullName, 'preferred_language': language});
    await _saveAuth(data);
    return data['is_new_user'] == true;
  }

  // role chosen on the register form is kept until the e-mail is verified and the user signs in for the first time
  Future<void> savePendingRole(String email, String role) async =>
      (await SharedPreferences.getInstance()).setString('pending_role_${email.toLowerCase()}', role);

  Future<String?> takePendingRole(String email) async {
    final p = await SharedPreferences.getInstance();
    final k = 'pending_role_${email.toLowerCase()}';
    final v = p.getString(k);
    if (v != null) await p.remove(k);
    return v;
  }

  Future<void> _saveAuth(dynamic data) async {
    await _saveToken(data['access_token'] as String);
    user = Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<void> register({required String fullName, required String email, required String password, required String role, String language = 'en'}) async {
    await _saveAuth(await _request('POST', '/auth/register',
        body: {'full_name': fullName, 'email': email, 'password': password, 'role': role, 'preferred_language': language}));
  }

  Future<void> login(String email, String password) async {
    await _saveAuth(await _request('POST', '/auth/login', body: {'email': email, 'password': password}));
  }

  Future<void> logout() async {
    user = null;
    await _saveToken(null);
  }

  Future<void> updateProfile({String? fullName, String? language, String? role}) async {
    final body = <String, dynamic>{if (fullName != null) 'full_name': fullName, if (language != null) 'preferred_language': language, if (role != null) 'role': role};
    user = Map<String, dynamic>.from(await _request('PATCH', '/users/me', body: body) as Map);
  }

  // ---------- data ----------
  Future<List<Map<String, dynamic>>> history({String? mode, int limit = 50}) async {
    final r = await _request('GET', '/history', query: {'limit': '$limit', if (mode != null) 'mode': mode}) as List;
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> textToSign(String text) async =>
      Map<String, dynamic>.from(await _request('POST', '/text-to-sign', body: {'text': text}) as Map);

  /// Live sessions: returns the session code (e.g. SB-123456)
  Future<String> createSession() async => (await _request('POST', '/sessions') as Map)['code'] as String;

  Future<String> joinSession(String code) async =>
      (await _request('POST', '/sessions/join', body: {'code': code.trim()}) as Map)['code'] as String;

  Future<List<Map<String, dynamic>>> vocabulary() async {
    final r = await _request('GET', '/vocabulary') as List;
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

// ---------- helpers ----------
String prettyDate(String iso) {
  final s = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(iso) ? iso : '${iso}Z'; // backend stores UTC
  final d = DateTime.tryParse(s)?.toLocal();
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${m[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

HistoryItem historyFromJson(Map<String, dynamic> j) {
  final signToText = j['mode'] == 'sign_to_text';
  return HistoryItem(
    signToText ? 'Sign→Text' : 'Text→Sign',
    (signToText ? j['output_text'] : j['input_text']) as String,
    signToText ? 'Signs: ${j['input_text']}' : 'Matched signs: ${j['output_text']}',
    prettyDate(j['created_at'] as String),
  );
}
