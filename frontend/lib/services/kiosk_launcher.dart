import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('openKioskScreen')
external void _openKioskScreen(JSString otp);

class KioskLauncher {
  static void openKioskScreen([String otp = '']) {
    if (kIsWeb) {
      try {
        _openKioskScreen(otp.toJS);
      } catch (e) {
        debugPrint('[KioskLauncher] Error opening kiosk: $e');
      }
    }
  }
}
