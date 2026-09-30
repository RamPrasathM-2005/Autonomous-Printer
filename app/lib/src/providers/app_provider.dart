import 'package:flutter/material.dart';

class AppProvider with ChangeNotifier {
  bool _isDarkMode = false;
  String _stationName = 'Station Kiosk #01 (Library Ground Floor)';
  String _stationId = 'STN-LIB-01';
  bool _isOnline = true;

  bool get isDarkMode => _isDarkMode;
  String get stationName => _stationName;
  String get stationId => _stationId;
  bool get isOnline => _isOnline;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setStationInfo(String name, String id) {
    _stationName = name;
    _stationId = id;
    notifyListeners();
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }
}
