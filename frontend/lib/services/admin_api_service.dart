import 'dart:convert';
import 'dart:typed_data';
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

  static Future<Map<String, dynamic>> createDepartment({
    required String code,
    required String name,
    String? description,
  }) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .post(
          Uri.parse('$origin/api/departments'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode({
            'code': code.trim(),
            'name': name.trim(),
            'description': description?.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to create department.');
      } catch (_) {
        throw Exception('Failed to create department (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateDepartment({
    required int id,
    String? code,
    String? name,
    String? description,
  }) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final body = <String, dynamic>{};
    if (code != null) body['code'] = code.trim();
    if (name != null) body['name'] = name.trim();
    if (description != null) body['description'] = description.trim();

    final response = await http
        .put(
          Uri.parse('$origin/api/departments/$id'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update department.');
      } catch (_) {
        throw Exception('Failed to update department (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> deleteDepartment(int id) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .delete(
          Uri.parse('$origin/api/departments/$id'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to delete department.');
      } catch (_) {
        throw Exception('Failed to delete department (HTTP ${response.statusCode}).');
      }
    }
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

  // ----------------- PRINTER MANAGEMENT -----------------

  static Future<List<dynamic>> getPrinters() async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .get(
          Uri.parse('$origin/api/admin/printers'),
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
        throw Exception(err['message'] ?? 'Failed to load printers.');
      } catch (_) {
        throw Exception('Failed to load printers (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createPrinter(Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .post(
          Uri.parse('$origin/api/admin/printers'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to register printer.');
      } catch (_) {
        throw Exception('Failed to register printer (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> testPrinterConnection(String id) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .post(
          Uri.parse('$origin/api/admin/printers/$id/test-connection'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to test connection.');
      } catch (_) {
        throw Exception('Failed to test connection (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> deletePrinter(String id) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .delete(
          Uri.parse('$origin/api/admin/printers/$id'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to delete printer.');
      } catch (_) {
        throw Exception('Failed to delete printer.');
      }
    }
  }

  static Future<Map<String, dynamic>> updatePrinter(String id, Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .patch(
          Uri.parse('$origin/api/admin/printers/$id'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AdminAuthService.logout();
      throw Exception('Session expired or unauthorized. Please sign in again.');
    }

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update printer.');
      } catch (_) {
        throw Exception('Failed to update printer (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> togglePrinterActive(String id) async {
    final current = await getPrinters();
    final p = current.firstWhere((item) => item['id'].toString() == id, orElse: () => null);
    final currentActive = p != null && p['is_active'] == true;
    return await updatePrinter(id, {'is_active': !currentActive, 'is_enabled': !currentActive});
  }

  static Future<List<dynamic>> getPrintAgents() async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .get(
          Uri.parse('$origin/api/admin/print-agents'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to load print agents.');
      } catch (_) {
        throw Exception('Failed to load print agents.');
      }
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createPrintAgent(Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .post(
          Uri.parse('$origin/api/admin/print-agents'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to register print agent.');
      } catch (_) {
        throw Exception('Failed to register print agent.');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> deletePrintAgent(String serverId) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .delete(
          Uri.parse('$origin/api/admin/print-agents/$serverId'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to delete print agent.');
      } catch (_) {
        throw Exception('Failed to delete print agent.');
      }
    }
  }

  static Future<List<dynamic>> getAgentCupsPrinters(String serverId) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .get(
          Uri.parse('$origin/api/admin/print-agents/$serverId/cups-printers'),
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
        throw Exception(err['message'] ?? 'Failed to retrieve CUPS printers from Print Agent.');
      } catch (_) {
        throw Exception('Failed to retrieve CUPS printers from Print Agent.');
      }
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<void> updatePrintAgent(String serverId, Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .patch(
          Uri.parse('$origin/api/admin/print-agents/$serverId'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AdminAuthService.logout();
      throw Exception('Session expired or unauthorized. Please sign in again.');
    }

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update print agent.');
      } catch (_) {
        throw Exception('Failed to update print agent.');
      }
    }
  }

  static Future<List<dynamic>> getDiscoveredPrinters() async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .get(
          Uri.parse('$origin/api/admin/discovered-printers'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      return [];
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<void> dismissDiscoveredPrinter(String id) async {
    final origin = ApiConfig.backendUrl;
    await http
        .delete(
          Uri.parse('$origin/api/admin/discovered-printers/$id'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<void> updatePrintServer(String serverId, Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .patch(
          Uri.parse('$origin/api/admin/print-agents/$serverId'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update print server.');
      } catch (_) {
        throw Exception('Failed to update print server.');
      }
    }
  }


  // ----------------- USER MANAGEMENT -----------------

  static Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 15,
    String? search,
    int? departmentId,
    String? role,
    bool? isActive,
  }) async {
    final origin = ApiConfig.backendUrl;
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (departmentId != null) params['department_id'] = departmentId.toString();
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (isActive != null) params['is_active'] = isActive.toString();

    final uri = Uri.parse('$origin/api/admin/users').replace(queryParameters: params);
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
        throw Exception(err['message'] ?? 'Failed to load users.');
      } catch (_) {
        throw Exception('Failed to load users (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .post(
          Uri.parse('$origin/api/admin/users'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AdminAuthService.logout();
      throw Exception('Session expired or unauthorized. Please sign in again.');
    }

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to create user.');
      } catch (_) {
        throw Exception('Failed to create user (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .patch(
          Uri.parse('$origin/api/admin/users/$id'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AdminAuthService.logout();
      throw Exception('Session expired or unauthorized. Please sign in again.');
    }

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update user.');
      } catch (_) {
        throw Exception('Failed to update user (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> deleteUser(int id) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;

    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }

    final response = await http
        .delete(
          Uri.parse('$origin/api/admin/users/$id'),
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
        throw Exception(err['message'] ?? 'Failed to delete user.');
      } catch (_) {
        throw Exception('Failed to delete user (HTTP ${response.statusCode}).');
      }
    }
  }

  static Future<Map<String, dynamic>> toggleUserStatus(int id, bool isActive) async {
    return updateUser(id, {'is_active': isActive});
  }


  // ----------------- SYSTEM SETTINGS -----------------

  static Future<Map<String, dynamic>> getSettings() async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .get(
          Uri.parse('$origin/api/admin/settings'),
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
        throw Exception(err['message'] ?? 'Failed to load settings.');
      } catch (_) {
        throw Exception('Failed to load settings (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) async {
    final origin = ApiConfig.backendUrl;
    final response = await http
        .patch(
          Uri.parse('$origin/api/admin/settings'),
          headers: AdminAuthService.authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AdminAuthService.logout();
      throw Exception('Session expired or unauthorized. Please sign in again.');
    }

    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update settings.');
      } catch (_) {
        throw Exception('Failed to update settings (HTTP ${response.statusCode}).');
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ----------------- EXPORT REPORTS -----------------

  static Future<Uint8List> exportReportExcel({
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

    final uri = Uri.parse('$origin/api/reports/export/excel').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http
        .get(uri, headers: AdminAuthService.authHeaders)
        .timeout(const Duration(seconds: 45));

    if (response.statusCode >= 400) {
      throw Exception('Failed to export Excel report (HTTP ${response.statusCode}).');
    }

    return response.bodyBytes;
  }

  static Future<Uint8List> exportReportPdf({
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

    final uri = Uri.parse('$origin/api/reports/export/pdf').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http
        .get(uri, headers: AdminAuthService.authHeaders)
        .timeout(const Duration(seconds: 45));

    if (response.statusCode >= 400) {
      throw Exception('Failed to export PDF report (HTTP ${response.statusCode}).');
    }

    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> getDatabaseStatus() async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;
    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }
    final response = await http
        .get(
          Uri.parse('$origin/api/admin/database/status'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode >= 400) {
      throw Exception('Failed to fetch database status (HTTP ${response.statusCode}).');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Uint8List> downloadRosterTemplate() async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;
    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }
    final response = await http
        .get(
          Uri.parse('$origin/api/admin/users/import/template'),
          headers: AdminAuthService.authHeaders,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode >= 400) {
      throw Exception('Failed to download roster template (HTTP ${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> importUserRoster(Uint8List fileBytes, String filename) async {
    final origin = ApiConfig.backendUrl;
    final token = AdminAuthService.accessToken;
    if (token == null) {
      throw Exception('Admin authentication token missing. Please sign in.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$origin/api/admin/users/import'),
    );
    request.headers.addAll(AdminAuthService.authHeaders);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 400) {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Roster import failed.');
      } catch (_) {
        throw Exception('Roster import failed (HTTP ${response.statusCode}).');
      }
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}


