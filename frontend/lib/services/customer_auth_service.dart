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

    if (_accessToken != null) {
      // Validate or refresh in background
      _refreshProfileQuietly();
    }
  }

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<void> _refreshProfileQuietly() async {
    if (_accessToken == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _currentUser = UserProfile.fromJson(data);
        writeSessionValue(_kUserProfileKey, jsonEncode(_currentUser!.toJson()));
        userNotifier.value = _currentUser;
      } else if (res.statusCode == 401 && _refreshToken != null) {
        await _tryRefreshToken();
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
        writeSessionValue(_kAccessTokenKey, _accessToken!);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> sendOtp(String phone, {String purpose = 'login'}) async {
    final cleanPhone = phone.trim();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': cleanPhone, 'purpose': purpose}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Failed to send OTP code.');
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone.trim(), 'otp': otp.trim()}),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Invalid verification code.');
    }
  }

  Future<UserProfile> studentLogin({
    required String phone,
    required String otp,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/student/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone.trim(), 'otp': otp.trim()}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Login failed. Please check your OTP.');
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
    required String phone,
    required String department,
    required String otp,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/student/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName.trim(),
        'roll_number': rollNumber.trim().toUpperCase(),
        'phone': phone.trim(),
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
    String? phone,
  }) async {
    if (_accessToken == null) throw const ApiError('User not logged in.');
    final payload = <String, dynamic>{
      if (fullName != null) 'full_name': fullName.trim(),
      if (department != null) 'department': department.trim(),
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
    if (_accessToken == null) return [];
    final res = await http.get(
      Uri.parse('$_baseUrl/api/orders/my'),
      headers: authHeaders,
    ).timeout(const Duration(seconds: 12));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiError(data['message'] ?? 'Failed to fetch order history.');
    }

    final list = data as List;
    return list.map((item) => PrintOrder.fromJson(item as Map<String, dynamic>)).toList();
  }
}
