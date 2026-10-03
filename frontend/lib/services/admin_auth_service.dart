import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Admin credentials stay in memory and are separate from customer sessions.
class AdminAuthService {
  static String? _accessToken;
  static String? _refreshToken;
  static String? _origin;

  static Future<Map<String, dynamic>> _decode(http.Response response) async {
    if (response.statusCode >= 400) {
      switch (response.statusCode) {
        case 401:
          throw Exception('Invalid email or password.');
        case 403:
          throw Exception('An active administrator account is required.');
        case 422:
          throw Exception('Enter a valid email and password.');
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
    final profileResponse = await http
        .get(
          Uri.parse('$origin/api/auth/admin/me'),
          headers: {'Authorization': 'Bearer ${tokens['access_token']}'},
        )
        .timeout(const Duration(seconds: 15));
    final profile = await _decode(profileResponse);
    _accessToken = tokens['access_token'] as String;
    _refreshToken = tokens['refresh_token'] as String;
    _origin = origin;
    return profile;
  }

  static Future<void> logout() async {
    final token = _refreshToken;
    final origin = _origin;
    _accessToken = null;
    _refreshToken = null;
    _origin = null;
    if (token != null && origin != null) {
      await http
          .post(
            Uri.parse('$origin/api/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': token}),
          )
          .timeout(const Duration(seconds: 10));
    }
  }

  static Future<Map<String, dynamic>?> currentAdmin() async {
    if (_accessToken == null || _origin != ApiConfig.backendUrl) return null;
    try {
      return await _decode(
        await http
            .get(
              Uri.parse('$_origin/api/auth/admin/me'),
              headers: {'Authorization': 'Bearer $_accessToken'},
            )
            .timeout(const Duration(seconds: 10)),
      );
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
      _origin = null;
      return null;
    }
  }
}
