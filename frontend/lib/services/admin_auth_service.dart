import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_store.dart';

/// Admin credentials persist across browser refreshes via SessionStore.
class AdminAuthService {
  static const _kAccessTokenKey = 'admin_access_token';
  static const _kRefreshTokenKey = 'admin_refresh_token';
  static const _kOriginKey = 'admin_origin';

  static String? get accessToken => SessionStore.read(_kAccessTokenKey);
  static String? get refreshToken => SessionStore.read(_kRefreshTokenKey);
  static String? get origin => SessionStore.read(_kOriginKey);
  static bool get isAuthenticated => accessToken != null;
  static Future<String?>? _refreshing;

  static Future<String?> getValidAccessToken() async {
    final token = accessToken;
    if (token == null) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map<String, dynamic>;
      final expiry = (payload['exp'] as num).toInt();
      if (expiry > DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45) {
        return token;
      }
    } catch (_) {
      return token; // The API will reject malformed tokens.
    }
    _refreshing ??= _refreshAccessToken();
    try {
      return await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  static Future<String?> _refreshAccessToken() async {
    final previousRefresh = refreshToken;
    if (previousRefresh == null) return null;
    try {
      final response = await http
          .post(
            Uri.parse('${origin ?? ApiConfig.backendUrl}/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': previousRefresh}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || refreshToken != previousRefresh) {
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final updated = data['access_token'] as String;
      SessionStore.write(_kAccessTokenKey, updated);
      return updated;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  static Future<Map<String, String>> getAuthenticatedHeaders() async {
    if (await getValidAccessToken() == null) {
      throw Exception('Administrator session expired. Please sign in.');
    }
    return authHeaders;
  }

  static Future<Map<String, dynamic>> _decode(http.Response response) async {
    if (response.statusCode >= 400) {
      switch (response.statusCode) {
        case 401:
          throw Exception('Invalid email or password.');
        case 403:
          throw Exception('An active administrator account is required.');
        case 422:
          throw Exception('Enter a valid email and password.');
        case 429:
          throw Exception(
            'Too many attempts. Please wait before signing in again.',
          );
        default:
          throw Exception('Unable to sign in. Please try again.');
      }
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .post(
          Uri.parse('$origin/api/auth/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    final tokens = await _decode(response);
    final aToken = tokens['access_token'] as String;
    final rToken = tokens['refresh_token'] as String;

    final profileResponse = await http
        .get(
          Uri.parse('$origin/api/auth/admin/me'),
          headers: {'Authorization': 'Bearer $aToken'},
        )
        .timeout(const Duration(seconds: 15));
    final profile = await _decode(profileResponse);

    SessionStore.write(_kAccessTokenKey, aToken);
    SessionStore.write(_kRefreshTokenKey, rToken);
    SessionStore.write(_kOriginKey, origin);
    return profile;
  }

  static Future<void> logout() async {
    final token = refreshToken;
    final orig = origin ?? ApiConfig.backendUrl;
    SessionStore.clear(_kAccessTokenKey);
    SessionStore.clear(_kRefreshTokenKey);
    SessionStore.clear(_kOriginKey);
    if (token != null) {
      try {
        await http
            .post(
              Uri.parse('$orig/api/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': token}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>?> currentAdmin() async {
    final token = await getValidAccessToken();
    if (token == null) return null;
    final orig = origin ?? ApiConfig.backendUrl;
    try {
      return await _decode(
        await http
            .get(
              Uri.parse('$orig/api/auth/admin/me'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10)),
      );
    } catch (_) {
      return null;
    }
  }
}
