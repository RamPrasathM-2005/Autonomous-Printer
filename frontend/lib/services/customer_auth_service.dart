import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/order.dart';
import '../models/user_profile.dart';
import 'api_error.dart';
import 'session_store.dart';

class CustomerAuthService {
  static final CustomerAuthService _instance = CustomerAuthService._internal();
  factory CustomerAuthService() => _instance;
  CustomerAuthService._internal();

  static const String _kAccessTokenKey = 'student_auth_access_token';
  static const String _kRefreshTokenKey = 'student_auth_refresh_token';
  static const String _kUserProfileKey = 'student_auth_user_profile';

  String? _accessToken;
  String? _refreshToken;
  UserProfile? _currentUser;

  final ValueNotifier<UserProfile?> userNotifier = ValueNotifier<UserProfile?>(null);

  bool get isLoggedIn => _currentUser != null && _accessToken != null;
  UserProfile? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  String get _baseUrl => ApiConfig.backendUrl;

  Future<void> init() async {
    _accessToken = readSessionValue(_kAccessTokenKey);
    _refreshToken = readSessionValue(_kRefreshTokenKey);
    final rawProfile = readSessionValue(_kUserProfileKey);
    if (rawProfile != null) {
      try {
        final decoded = jsonDecode(rawProfile) as Map<String, dynamic>;
        _currentUser = UserProfile.fromJson(decoded);
        userNotifier.value = _currentUser;
      } catch (_) {}
    }

    if (_accessToken != null || _refreshToken != null) {
      // Validate or refresh session quietly
      _refreshProfileQuietly();
    }
  }

  bool _isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
      final exp = decoded['exp'] as int?;
      if (exp == null) return false;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return DateTime.now().toUtc().isAfter(expiryDate.subtract(const Duration(seconds: 45)));
    } catch (_) {
      return true;
    }
  }

  Future<String?> getValidAccessToken() async {
    if (_accessToken != null && !_isTokenExpired(_accessToken)) {
      return _accessToken;
    }
    if (_refreshToken != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return _accessToken;
      }
    }
    return null;
  }

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<void> _refreshProfileQuietly() async {
    final token = await getValidAccessToken();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _currentUser = UserProfile.fromJson(data);
        writeSessionValue(_kUserProfileKey, jsonEncode(_currentUser!.toJson()));
        userNotifier.value = _currentUser;
      } else if (res.statusCode == 401 && _refreshToken != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed && _accessToken != null) {
          final retryRes = await http.get(
            Uri.parse('$_baseUrl/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
          ).timeout(const Duration(seconds: 6));
          if (retryRes.statusCode == 200) {
            final data = jsonDecode(retryRes.body) as Map<String, dynamic>;
            _currentUser = UserProfile.fromJson(data);
            writeSessionValue(_kUserProfileKey, jsonEncode(_currentUser!.toJson()));
            userNotifier.value = _currentUser;
          }
        }
      }
    } catch (_) {}
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _accessToken = data['access_token'];
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
          writeSessionValue(_kRefreshTokenKey, _refreshToken!);
        }
        writeSessionValue(_kAccessTokenKey, _accessToken!);
        return true;
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        // Refresh token permanently expired or revoked
        logout();
      }
    } catch (_) {}
    return false;
  }

  Future<void> sendOtp(String email, {String purpose = 'login'}) async {
    final cleanEmail = email.trim().toLowerCase();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': cleanEmail,
        'purpose': purpose,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Failed to send verification code.');
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    final cleanEmail = email.trim().toLowerCase();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': cleanEmail,
        'phone': cleanEmail,
        'otp': otp.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Invalid verification code.');
    }
  }

  Future<UserProfile> studentLogin({
    required String email,
    required String otp,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/student/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': cleanEmail,
        'phone': (phone ?? cleanEmail).trim(),
        'otp': otp.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Login failed. Please check your verification code.');
    }

    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
    final userJson = data['user'] as Map<String, dynamic>;
    _currentUser = UserProfile.fromJson(userJson);

    writeSessionValue(_kAccessTokenKey, _accessToken!);
    if (_refreshToken != null) {
      writeSessionValue(_kRefreshTokenKey, _refreshToken!);
    }
    writeSessionValue(_kUserProfileKey, jsonEncode(_currentUser!.toJson()));

    userNotifier.value = _currentUser;
    return _currentUser!;
  }

  Future<UserProfile> studentSignup({
    required String fullName,
    required String rollNumber,
    required String email,
    required String department,
    required String otp,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/student/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName.trim(),
        'roll_number': rollNumber.trim().toUpperCase(),
        'email': cleanEmail,
        'phone': (phone ?? cleanEmail).trim(),
        'department': department.trim(),
        'otp': otp.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Registration failed. Please check your details.');
    }

    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
    final userJson = data['user'] as Map<String, dynamic>;
    _currentUser = UserProfile.fromJson(userJson);

    writeSessionValue(_kAccessTokenKey, _accessToken!);
    if (_refreshToken != null) {
      writeSessionValue(_kRefreshTokenKey, _refreshToken!);
    }
    writeSessionValue(_kUserProfileKey, jsonEncode(_currentUser!.toJson()));

    userNotifier.value = _currentUser;
    return _currentUser!;
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? department,
    String? email,
    String? phone,
  }) async {
    if (_accessToken == null) throw const ApiError('User not logged in.');
    final payload = <String, dynamic>{
      if (fullName != null) 'full_name': fullName.trim(),
      if (department != null) 'department': department.trim(),
      if (email != null) 'email': email.trim().toLowerCase(),
      if (phone != null) 'phone': phone.trim(),
    };

    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: authHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Failed to update profile.');
    }

    _currentUser = UserProfile.fromJson(data);
    writeSessionValue(_kUserProfileKey, jsonEncode(_currentUser!.toJson()));
    userNotifier.value = _currentUser;
    return _currentUser!;
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    clearSessionValue(_kAccessTokenKey);
    clearSessionValue(_kRefreshTokenKey);
    clearSessionValue(_kUserProfileKey);
    userNotifier.value = null;
  }

  Future<List<PrintOrder>> fetchMyOrders() async {
    final token = await getValidAccessToken();
    if (token == null) return [];
    final res = await http.get(
      Uri.parse('$_baseUrl/api/orders/my'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 12));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Failed to fetch order history.');
    }

    final list = data as List;
    return list.map((item) => PrintOrder.fromJson(item as Map<String, dynamic>)).toList();
  }
}
