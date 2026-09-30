import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyBackendUrl = 'backend_base_url';
  static const String _keyAgentUrl = 'agent_base_url';
  static const String _keySelectedStationId = 'selected_station_id';

  // Smart defaults: 127.0.0.1 works on Web, Desktop, and Physical Mobile (via adb reverse)
  static String get defaultBackendUrl => 'http://127.0.0.1:8000';
  static String get defaultAgentUrl => 'http://127.0.0.1:5001';

  static String backendUrl = defaultBackendUrl;
  static String agentUrl = defaultAgentUrl;
  static String? selectedStationId = 'PRINT-SERVER-001';
  static String get baseUrl => backendUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedBackend = prefs.getString(_keyBackendUrl);
    String? storedAgent = prefs.getString(_keyAgentUrl);

    // Auto-correct any leftover emulator loopback 10.0.2.2 to 127.0.0.1
    if (storedBackend != null && storedBackend.contains('10.0.2.2')) {
      storedBackend = 'http://127.0.0.1:8000';
      await prefs.setString(_keyBackendUrl, storedBackend);
    }
    if (storedAgent != null && (storedAgent.contains('10.0.2.2') || storedAgent.contains(':5000'))) {
      storedAgent = 'http://127.0.0.1:5001';
      await prefs.setString(_keyAgentUrl, storedAgent);
    }

    backendUrl = storedBackend ?? defaultBackendUrl;
    agentUrl = storedAgent ?? defaultAgentUrl;
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
