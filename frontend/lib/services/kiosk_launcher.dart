import 'package:flutter/foundation.dart';
import 'kiosk_launcher_stub.dart'
    if (dart.library.js_interop) 'kiosk_launcher_web.dart';

class KioskLauncher {
  static void openKioskScreen([String otp = '']) {
    if (kIsWeb) {
      openKioskScreenPlatform(otp);
    }
  }
}
