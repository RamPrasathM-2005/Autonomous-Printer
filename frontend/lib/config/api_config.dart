import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/session_store.dart';

const String kBackendUrl = String.fromEnvironment('BACKEND_URL');
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const String kActiveTunnelUrl = String.fromEnvironment('ACTIVE_TUNNEL_URL');

class ApiConfig {
  static const String _keyBackendUrl = 'backend_base_url';
  static const String _keyBackendOrigin = 'backend_override_origin';
  static const String _keyAgentUrl = 'agent_base_url';
  static const String _keySelectedStationId = 'selected_station_id';

  /// Normalizes a backend URL by trimming trailing slashes and stripping any trailing `/api`
  /// so that all API callers appending `/api/...` produce standard paths.
  static String normalizeBackendUrl(String url) {
    var cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.endsWith('/api')) {
      cleaned = cleaned.substring(0, cleaned.length - 4).replaceAll(RegExp(r'/+$'), '');
    }
    return cleaned;
  }

  // Smart defaults: Environment variable > Cloudflare Tunnel / Origin > Localhost
  static String get defaultBackendUrl {
    if (kBackendUrl.isNotEmpty) return normalizeBackendUrl(kBackendUrl);
    if (kApiBaseUrl.isNotEmpty) return normalizeBackendUrl(kApiBaseUrl);

    if (kIsWeb) {
      return normalizeBackendUrl(Uri.base.origin);
    }
    // On physical mobile devices, if active Cloudflare tunnel is known, prefer it so remote/cellular works!
    if (!kIsWeb &&
        kActiveTunnelUrl.isNotEmpty &&
        kActiveTunnelUrl.startsWith('http')) {
      return normalizeBackendUrl(kActiveTunnelUrl);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get defaultAgentUrl {
    const configured = String.fromEnvironment('AGENT_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return 'http://127.0.0.1:5001';
  }

  static String backendUrl = defaultBackendUrl;
  static String agentUrl = defaultAgentUrl;
  static String? selectedStationId = 'PRINT-SERVER-001';
  static String get baseUrl => backendUrl;

  static List<String> get fallbackCandidates => [
    if (backendUrl.isNotEmpty) backendUrl,
    if (kActiveTunnelUrl.isNotEmpty && kActiveTunnelUrl.startsWith('http'))
      normalizeBackendUrl(kActiveTunnelUrl),
    if (!kIsWeb) 'http://127.0.0.1:8000',
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      'http://10.0.2.2:8000',
  ];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    await SessionStore.init(prefs);
    String? storedBackend = prefs.getString(_keyBackendUrl);
    String? storedAgent = prefs.getString(_keyAgentUrl);

    String? runtimeEnvUrl;
    if (kIsWeb) {
      // In web mode, dynamically query /env.json so changing BACKEND_URL in .env
      // takes effect immediately on page refresh without needing code changes or rebuilds.
      try {
        final uri = Uri.parse('/env.json');
        final response = await http.get(uri).timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('BACKEND_URL')) {
            final configured = data['BACKEND_URL']?.toString().trim() ?? '';
            final parsed = configured.isEmpty ? Uri.base.origin : normalizeBackendUrl(configured);
            if (parsed.isNotEmpty) {
              runtimeEnvUrl = parsed;
            }
          }
        }
      } catch (_) {
        // Fall back gracefully if /env.json is not available
      }
    }

    if (runtimeEnvUrl != null && runtimeEnvUrl.isNotEmpty) {
      storedBackend = runtimeEnvUrl;
      await prefs.setString(_keyBackendUrl, storedBackend);
      if (kIsWeb) {
        await prefs.setString(_keyBackendOrigin, Uri.base.origin);
      }
    } else if (kIsWeb) {
      final queryBackend =
          Uri.base.queryParameters['backend'] ??
          Uri.base.queryParameters['tunnel'];
      if (queryBackend != null && queryBackend.trim().isNotEmpty) {
        storedBackend = normalizeBackendUrl(queryBackend);
        await prefs.setString(_keyBackendUrl, storedBackend);
        await prefs.setString(_keyBackendOrigin, Uri.base.origin);
      } else if (kBackendUrl.isNotEmpty || kApiBaseUrl.isNotEmpty) {
        storedBackend = defaultBackendUrl;
        await prefs.setString(_keyBackendUrl, storedBackend);
      } else {
        // Same-origin proxy also applies on localhost. Discard stale direct-port
        // overrides from previous deployments when no explicit config is given.
        storedBackend = normalizeBackendUrl(Uri.base.origin);
        await prefs.setString(_keyBackendUrl, storedBackend);
        await prefs.setString(_keyBackendOrigin, Uri.base.origin);
      }
    } else {
      // Native Android / iOS mobile app
      if (storedBackend == null || storedBackend.contains('10.0.2.2')) {
        storedBackend = defaultBackendUrl;
        await prefs.setString(_keyBackendUrl, storedBackend);
      }
    }

    if (storedAgent == null || (storedAgent.contains('10.0.2.2') && kIsWeb)) {
      storedAgent = defaultAgentUrl;
      await prefs.setString(_keyAgentUrl, storedAgent);
    }

    backendUrl = normalizeBackendUrl(storedBackend);
    agentUrl = storedAgent;
    selectedStationId =
        (kIsWeb ? Uri.base.queryParameters['station'] : null) ??
        prefs.getString(_keySelectedStationId) ?? 'PRINT-SERVER-001';
  }

  static bool get isTunneled => backendUrl.contains('trycloudflare.com');

  static Future<void> updateBackendUrl(String url) async {
    backendUrl = normalizeBackendUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendUrl, backendUrl);
    if (kIsWeb) await prefs.setString(_keyBackendOrigin, Uri.base.origin);
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
