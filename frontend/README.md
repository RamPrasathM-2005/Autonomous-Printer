# Flutter frontend

The implemented payment checkout targets Flutter **web**. The repository contains other platform scaffolding, but native Android/iOS checkout is not wired or validated; the conditional native checkout adapter reports unsupported. This is not a React Native application.

```powershell
flutter pub get
flutter test --no-pub
flutter build web --release --no-pub --no-web-resources-cdn
```

From the repository root, `start_all.bat -Build` builds and serves the app at http://127.0.0.1:3000/ with security headers. Production builds use same-origin `/api` by default; an explicitly separate backend can be set with `--dart-define=API_BASE_URL=https://api.example.com` and requires matching backend origins/CSP.

All prices and capture decisions come from the backend. Standard Checkout returns an untrusted callback which the server verifies. The UI never substitutes payment or print success after an exception. Check payment status recovers lost callbacks; Your orders resumes orders after a reload in the same tab. Session tokens are in sessionStorage, not persistent localStorage. Protect against XSS and clear the session between customers at a shared kiosk.

Do not put secrets in `.env`, Dart source, JavaScript, or build definitions. Only the public Razorpay key ID is delivered to checkout. The frontend `.env` is unused.

See [deployment requirements](../docs/SECURITY.md).
