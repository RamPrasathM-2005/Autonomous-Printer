import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'admin_auth_service.dart';

class AdminApiService {
  static Future<Map<String, dynamic>> getDashboardMetrics() async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .get(
          Uri.parse('$origin/api/admin/dashboard'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AdminAuthService.logout();
      throw Exception('Session expired or unauthorized. Please sign in again.');
    }

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to load dashboard metrics.');
      } catch (_) {
        throw Exception('Failed to load dashboard metrics (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
