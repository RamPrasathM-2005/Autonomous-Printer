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

  static Future<List<Map<String, dynamic>>> getDepartments({String? search}) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final query = (search != null && search.trim().isNotEmpty) ? '?q=${Uri.encodeComponent(search.trim())}' : '';
    final response = await http
        .get(
          Uri.parse('$origin/api/departments$query'),
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
        throw Exception(err['message'] ?? 'Failed to load departments.');
      } catch (_) {
        throw Exception('Failed to load departments (HTTP ${response.statusCode}).');
      }
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>> getDepartmentDetail(int id) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .get(
          Uri.parse('$origin/api/departments/$id'),
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
        throw Exception(err['message'] ?? 'Failed to load department details.');
      } catch (_) {
        throw Exception('Failed to load department details (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getDepartmentReport({
    int? departmentId,
    String? startDate,
    String? endDate,
    int? userId,
    String? printerId,
    String? status,
    bool? isColor,
  }) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final params = <String, String>{};
    if (departmentId != null) params['department_id'] = departmentId.toString();
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (userId != null) params['user_id'] = userId.toString();
    if (printerId != null) params['printer_id'] = printerId;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (isColor != null) params['is_color'] = isColor.toString();

    final uri = Uri.parse('$origin/api/reports/department').replace(queryParameters: params.isNotEmpty ? params : null);

    final response = await http
        .get(
          uri,
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
        throw Exception(err['message'] ?? 'Failed to generate department report.');
      } catch (_) {
        throw Exception('Failed to generate department report (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getDetailedPrintJobs({
    int? departmentId,
    int? userId,
    String? printerId,
    String? status,
    bool? isColor,
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (departmentId != null) params['department_id'] = departmentId.toString();
    if (userId != null) params['user_id'] = userId.toString();
    if (printerId != null) params['printer_id'] = printerId;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (isColor != null) params['is_color'] = isColor.toString();
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

    final uri = Uri.parse('$origin/api/reports/jobs').replace(queryParameters: params);

    final response = await http
        .get(
          uri,
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
        throw Exception(err['message'] ?? 'Failed to load print jobs.');
      } catch (_) {
        throw Exception('Failed to load print jobs (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getPrintJobDetail(String jobId) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .get(
          Uri.parse('$origin/api/reports/jobs/$jobId'),
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
        throw Exception(err['message'] ?? 'Failed to load job details.');
      } catch (_) {
        throw Exception('Failed to load job details (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
