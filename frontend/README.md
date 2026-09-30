# Flutter frontend

Checkout uses Razorpay Standard Checkout on Flutter web and the official `razorpay_flutter` SDK on Android/iOS. Both return callback evidence to the same backend verification endpoint; neither authorizes printing locally. Desktop native builds direct customers to the web app. This is not a React Native application. The web build and native adapter tests run on this Windows installation; Android/iOS builds and device checkout still require validation on their respective toolchains.

```powershell
flutter pub get
flutter test --no-pub
flutter build web --release --no-pub --no-web-resources-cdn
```

From the repository root, `start_all.bat -Build` builds and serves the app at http://127.0.0.1:3000/ with security headers. Production builds use same-origin `/api` by default; an explicitly separate backend can be set with `--dart-define=API_BASE_URL=https://api.example.com` and requires matching backend origins/CSP.

Android emulator debug builds default to `http://10.0.2.2:8000`. For a USB-connected physical Android device, run `adb reverse tcp:8000 tcp:8000` and `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`. Release builds require an HTTPS backend and your own signing configuration; HTTP is permitted only by the debug manifest. Install the Android SDK before building Android. On Windows, Flutter plugin setup requires Developer Mode for symlinks; after packages resolve, the web build and tests can run with `--no-pub` without enabling desktop plugin builds. Native customer sessions currently last only for the running app process.

The station keypad runs directly on the station computer at `http://127.0.0.1:5000/kiosk`. Do not expose the agent to phones or the public internet. `AGENT_BASE_URL` can configure a local terminal build, separately from the customer backend. The [official Flutter integration guide](https://razorpay.com/docs/payments/payment-gateway/flutter-integration/standard/integration-steps/) documents the SDK and Android shrinker rules included in this project.

All prices and capture decisions come from the backend. Standard Checkout returns an untrusted callback which the server verifies. The UI never substitutes payment or print success after an exception. Check payment status recovers lost callbacks; Your orders resumes orders after a reload in the same tab. Session tokens are in sessionStorage, not persistent localStorage. Protect against XSS and clear the session between customers at a shared kiosk.

When the backend advertises unpaid test printing, checkout also shows **Test print - No payment**. Payment creation is deferred until Pay with Razorpay is selected. The test action asks the backend for an independent test authorization; it never supplies fake payment IDs or signatures. Release-code and print-queue behavior are shared with paid orders. Turn off `ALLOW_UNPAID_TEST_PRINTING` on the backend and restart it to remove this option.

Do not put secrets in `.env`, Dart source, JavaScript, or build definitions. Only the public Razorpay key ID is delivered to checkout. The frontend `.env` is unused.

See [deployment requirements](../docs/SECURITY.md).
