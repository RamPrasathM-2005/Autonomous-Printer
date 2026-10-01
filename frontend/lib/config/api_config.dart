import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyBackendUrl = 'backend_base_url';
  static const String _keyAgentUrl = 'agent_base_url';
  static const String _keySelectedStationId = 'selected_station_id';

  // Smart defaults: 127.0.0.1 for Web, Desktop, and physical Android devices (via adb reverse).
  // 10.0.2.2 is only an Android emulator fallback.
  static String get defaultBackendUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb && !['localhost', '127.0.0.1'].contains(Uri.base.host)) {
      return Uri.base.origin;
    }
    return 'http://127.0.0.1:8000';
  }

  static String get defaultAgentUrl {
    const configured = String.fromEnvironment('AGENT_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return 'http://127.0.0.1:5000';
  }

  static String backendUrl = defaultBackendUrl;
  static String agentUrl = defaultAgentUrl;
  static String? selectedStationId = 'PRINT-SERVER-001';
  static String get baseUrl => backendUrl;

  static const List<String> fallbackCandidates = [
    'http://127.0.0.1:8000',
    'http://10.11.14.85:8000',
    'http://172.17.3.5:8000',
    'http://10.0.2.2:8000',
  ];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedBackend = prefs.getString(_keyBackendUrl);
    String? storedAgent = prefs.getString(_keyAgentUrl);

    // Auto-correct stale 10.0.2.2 URLs which cause timeouts on real devices and web
    if (storedBackend == null || (storedBackend.contains('10.0.2.2') && kIsWeb)) {
      storedBackend = defaultBackendUrl;
      await prefs.setString(_keyBackendUrl, storedBackend);
    }
    if (storedAgent == null || (storedAgent.contains('10.0.2.2') && kIsWeb)) {
      storedAgent = defaultAgentUrl;
      await prefs.setString(_keyAgentUrl, storedAgent);
    }

    backendUrl = storedBackend;
    agentUrl = storedAgent;
    selectedStationId =
        prefs.getString(_keySelectedStationId) ?? 'PRINT-SERVER-001';
  }

  static Future<void> updateBackendUrl(String url) async {
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendUrl, backendUrl);
  }

  static Future<void> setBackendUrl(String url) => updateBackendUrl(url);

  static Future<void> updateAgentUrl(String url) async {
    agentUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgentUrl, agentUrl);
  }

  static Future<void> setAgentUrl(String url) => updateAgentUrl(url);

  static Future<void> updateSelectedStationId(String stationId) async {
    selectedStationId = stationId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedStationId, stationId);
  }
}
