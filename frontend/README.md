# Autonomous Printer - Flutter Frontend 📱

The official cross-platform client (Android APK, Web, Windows Desktop) for the Autonomous Self-Service Printing Platform.

---

## 🌟 Screens & Feature Matrix

The frontend implements the complete 8-step workflow defined in the system specification:

1. **Stations (`/stations`)**:
   - Live discovery of nearby printing kiosks via `GET /api/print-servers`.
   - Real-time online/offline indicator, paper levels, queue length, and QR code scanner.

2. **Upload Document (`/upload`)**:
   - Supports PDF, PNG, and JPG documents.
   - Client-side file size and format validation.
   - SHA-256 client hash generation for data integrity.
   - Multipart upload to FastAPI (`POST /api/documents/upload`).

3. **Print Options & Pricing Engine (`/options`)**:
   - Number of copies (1 - 50).
   - Page range selector (`all` or comma-separated pages like `1-3, 5`).
   - Color mode: Monochrome vs Full Color.
   - Duplex mode: Simplex (single-sided) vs Duplex (double-sided).
   - Media size: A4, Letter, Legal.
   - Submits job configuration to FastAPI (`POST /api/orders`) for authoritative pricing calculation.

4. **Payment & Webhook Confirmation (`/payment`)**:
   - Itemized billing breakdown (page count, base rate, duplex discount, tax, total).
   - Razorpay payment order initiation (`POST /api/payments/create`).
   - Mock/simulated Razorpay payment verification callback for seamless testing.

5. **OTP Release & Order Tracking (`/otp`)**:
   - Secure 6-digit release OTP code with visual display.
   - 15-minute active countdown timer.
   - Live polling of order status (`WAITING_FOR_OTP` → `PRINTING` → `COMPLETED`).

6. **Kiosk Station Terminal (`/terminal`)**:
   - Interactive on-screen keypad simulating the physical printer touchscreen.
   - Direct release to local print agent (`POST /local/release`).

7. **Order History (`/history`)**:
   - Comprehensive log of past print jobs with colored status chips and timestamps.

8. **Network Settings (`/settings`)**:
   - Configurable Backend URL (FastAPI) and Print Agent URL (Flask).
   - One-tap presets for Android Emulator (`10.0.2.2`), Localhost (`127.0.0.1`), and LAN IP.
   - Real-time backend connection ping test.

---

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK 3.13+ installed.
- Android SDK installed (if building APK or running on Android device/emulator).

### Run Application

```bash
# 1. Install dependencies
flutter pub get

# 2. Run in browser (Chrome)
flutter run -d chrome

# 3. Run on Windows desktop
flutter run -d windows

# 4. Run on Android device / emulator
flutter run
```

### Build Android APK

```bash
flutter build apk --debug
```

The APK will be generated at:
```text
build/app/outputs/flutter-apk/app-debug.apk
```
