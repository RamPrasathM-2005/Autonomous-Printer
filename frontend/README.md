# 📱 Autonomous Printer - Flutter Frontend

Cross-platform client application built with **Flutter 3.x** supporting **Web (Chrome)**, **Android (APK)**, and **Windows Desktop**. It guides users through kiosk selection, multi-document upload, live 3D visualizer & print configuration, Razorpay checkout, and OTP print release.

---

## 📋 Prerequisites

Before running the frontend, ensure you have the following installed:

1. **Flutter SDK (3.13 or newer)**:
   - Verify installation by running:
     ```bash
     flutter doctor
     ```
2. **Google Chrome**: For running the web application.
3. *(Optional for Android)*: **Android Studio** and **Android SDK Command-line Tools** with an Android Emulator or physical USB debugging device.
4. *(Optional for Windows Desktop)*: **Visual Studio 2022** with "Desktop development with C++" workload installed.

---

## ⚙️ Network & API Configuration

The frontend connects to the FastAPI backend (port `8000`) and the local print agent (port `5000`).

### Target Addresses by Platform:
| Platform | Backend URL | Print Agent URL |
| :--- | :--- | :--- |
| **Web Browser (Chrome)** | `http://127.0.0.1:8000` | `http://127.0.0.1:5000` |
| **Windows Desktop** | `http://127.0.0.1:8000` | `http://127.0.0.1:5000` |
| **Android Emulator** | `http://10.0.2.2:8000` | `http://10.0.2.2:5000` |
| **Physical Phone (Wi-Fi)** | `http://<YOUR_PC_LAN_IP>:8000` | `http://<YOUR_PC_LAN_IP>:5000` |

> **Tip**: You can switch or test network endpoints directly inside the running app anytime by navigating to the **Settings (`/settings`)** screen.

---

## 🚀 Step-by-Step: How to Run

### Step 1: Navigate to the Frontend Directory
```bash
cd frontend
```

### Step 2: Fetch Flutter Packages
```bash
flutter pub get
```

### Step 3: Run the Application

#### Option A: Run in Web Browser (Google Chrome - Recommended)
```bash
flutter run -d chrome --web-port 3000
```
The app will open automatically at **[http://localhost:3000](http://localhost:3000)**.

#### Option B: Run on Windows Desktop
```bash
flutter run -d windows
```

#### Option C: Run on Android (Device or Emulator)
```bash
# Check connected devices
flutter devices

# Launch on target device
flutter run -d <device-id>
```

---

## 📦 Building Production Bundles

### Build Android APK:
```bash
flutter build apk --release
```
The output APK is generated at:
```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

### Build Web Production Bundle:
```bash
flutter build web --release
```
The deployable static files are placed in:
```text
frontend/build/web/
```

---

## 💳 Razorpay Web Payment Note

On the Web platform, Razorpay's JavaScript checkout library is embedded in [frontend/web/index.html](web/index.html):
```html
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
```
When running on `http://localhost:3000`, the interactive payment modal will open directly in the browser. In development/test mode, test card and UPI dummy payments are supported without actual financial charges.

---

## 🧪 Static Analysis & Code Quality

Verify that all Dart source code passes flutter analysis with 0 errors:

```bash
flutter analyze
```

---

## 🛠️ Common Troubleshooting

| Issue | Resolution |
| :--- | :--- |
| **CORS errors in browser console** | Ensure the backend FastAPI server is running with CORS enabled (CORS is preconfigured for all origins in `backend/app/main.py`). |
| **Port 3000 occupied** | Run on an alternate port: `flutter run -d chrome --web-port 3001`. |
| **Pub get failed or lock conflicts** | Delete `.dart_tool/` and `pubspec.lock`, then run `flutter pub get`. |
