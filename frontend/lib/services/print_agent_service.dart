import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

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
      throw Exception('Failed to get agent status');
    }
  }

  Future<Map<String, dynamic>> releaseWithOtp(String otp) async {
    // 1. Try local print-agent on port 5000 first
    try {
      final uri = Uri.parse('$_agentUrl/local/release');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'otp': otp.trim()}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Local agent unreachable or CORS blocked in browser, fallback to backend
      debugPrint('[PrintAgentService] Port 5000 call failed, falling back to backend: $e');
    }

    // 2. Reliable Fallback: Call central FastAPI backend kiosk endpoint
    final backendUri = Uri.parse('${ApiConfig.baseUrl}/agent/release-kiosk');
    final response = await http
        .post(
          backendUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'otp': otp.trim()}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'OTP Release Failed (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> releaseJobWithOtp(String otp) async {
    try {
      final res = await releaseWithOtp(otp);
      return {'success': true, ...res};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}
