import 'package:shared_preferences/shared_preferences.dart';

/// Unified persistent session store for Mobile (APK), Web, and Desktop.
/// Backed by SharedPreferences (localStorage on Web, XML on Android APK)
/// with synchronous in-memory caching.
class SessionStore {
  static SharedPreferences? _prefs;
  static final Map<String, String> _cache = {};

  static Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    for (final key in _prefs!.getKeys()) {
      final val = _prefs!.getString(key);
      if (val != null) {
        _cache[key] = val;
      }
    }
  }

  static String? read(String key) => _cache[key] ?? _prefs?.getString(key);

  static void write(String key, String value) {
    _cache[key] = value;
    _prefs?.setString(key, value);
  }

  static void clear(String key) {
    _cache.remove(key);
    _prefs?.remove(key);
  }
}

String? readSessionValue(String key) => SessionStore.read(key);
void writeSessionValue(String key, String value) => SessionStore.write(key, value);
void clearSessionValue(String key) => SessionStore.clear(key);
