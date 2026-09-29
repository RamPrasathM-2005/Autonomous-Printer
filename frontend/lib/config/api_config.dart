import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyBackendUrl = 'backend_base_url';
  static const String _keyAgentUrl = 'agent_base_url';
  static const String _keySelectedStationId = 'selected_station_id';

  // Default URLs: 10.0.2.2 for Android emulator, 127.0.0.1 for local/desktop
  static String defaultBackendUrl = 'http://10.0.2.2:8000';
  static String defaultAgentUrl = 'http://10.0.2.2:5001';

  static String backendUrl = defaultBackendUrl;
  static String agentUrl = defaultAgentUrl;
  static String? selectedStationId = 'PRINT-SERVER-001';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    backendUrl = prefs.getString(_keyBackendUrl) ?? defaultBackendUrl;
    agentUrl = prefs.getString(_keyAgentUrl) ?? defaultAgentUrl;
    selectedStationId = prefs.getString(_keySelectedStationId) ?? 'PRINT-SERVER-001';
  }

  static Future<void> updateBackendUrl(String url) async {
    backendUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendUrl, backendUrl);
  }

  static Future<void> updateAgentUrl(String url) async {
    agentUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgentUrl, agentUrl);
  }

  static Future<void> updateSelectedStationId(String stationId) async {
    selectedStationId = stationId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedStationId, stationId);
  }
}
