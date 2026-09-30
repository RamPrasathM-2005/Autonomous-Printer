import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('openKioskScreen')
external void _openKioskScreen(JSString otp);

void openKioskScreenPlatform(String otp) {
  try {
    _openKioskScreen(otp.toJS);
  } catch (e) {
    debugPrint('[KioskLauncher] Error opening kiosk: $e');
  }
}
