import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_error.dart';

class PrintAgentService {
  static final PrintAgentService _instance = PrintAgentService._internal();
  factory PrintAgentService() => _instance;
  PrintAgentService._internal();

  String get _agentUrl => ApiConfig.agentUrl;

  Future<bool> checkAgentHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_agentUrl/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAgentStatus() async {
    final response = await http
        .get(Uri.parse('$_agentUrl/local/status'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw const ApiError('Station unavailable. Try again later.');
    }
  }

  Future<Map<String, dynamic>> releaseWithOtp(String otp) async {
    final response = await http
        .post(
          Uri.parse('$_agentUrl/local/release'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'otp': otp.trim()}),
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiError.fromCode(data['error'] as String?);
    }
    return data;
  }

  Future<Map<String, dynamic>> releasePrintJob({
    required String stationId,
    required String otp,
  }) async {
    return await releaseWithOtp(otp);
  }

  Future<Map<String, dynamic>> releaseJobWithOtp(String otp) async {
    try {
      final res = await releaseWithOtp(otp);
      return {'success': true, ...res};
    } catch (e) {
      return {'success': false, 'error': userError(e)};
    }
  }
}
