# Autonomous Self-Service Printing Platform 🖨️

A production-ready, self-hosted autonomous printing platform connecting a modern **Flutter** mobile/desktop frontend, a high-performance **FastAPI** backend, and a lightweight **Flask Print Agent** controlling physical **CUPS** printers.

---

## 🏗️ System Architecture

```text
┌────────────────────────────────┐
│   Flutter Mobile App / Kiosk   │
│  (Android APK, Web, Desktop)   │
└───────────────┬────────────────┘
                │
                │ 1. Discover stations
                │ 2. Upload document (PDF/PNG/JPG)
                │ 3. Configure print options & get price
                │ 4. Pay via Razorpay
                │ 5. Receive 6-digit release OTP
                │
                ▼
┌────────────────────────────────┐       Shared Local Storage       ┌────────────────────────────────┐
│      FastAPI Backend API       │ ◄──────────────────────────────► │       Flask Print Agent        │
│          (Port 8000)           │      (/var/local/storage)        │          (Port 5001)           │
├────────────────────────────────┤                                  ├────────────────────────────────┤
│ - Auth & Session Management    │                                  │ - Heartbeat to backend         │
│ - Authoritative Pricing Engine │                                  │ - Station keypad OTP release   │
│ - Razorpay Payment & Webhooks  │                                  │ - CUPS option translation      │
│ - Secure OTP State Machine     │                                  │ - Real-time job telemetry      │
│ - MySQL / SQLAlchemy ORM       │                                  │ - pycups / lp execution        │
└────────────────────────────────┘                                  └───────────────┬────────────────┘
                                                                                    │
                                                                                    ▼
                                                                    ┌────────────────────────────────┐
                                                                    │      CUPS Printer Daemon       │
                                                                    │   (Thermal / Laser / Inkjet)   │
                                                                    └────────────────────────────────┘
```

### Key Architectural Tenets
- **100% Self-Hosted on Linux**: Zero dependency on third-party cloud storage (No S3, Firebase, Firestore, or Cloudinary). All files are stored directly on the local filesystem with atomic write operations and strict path traversal validation.
- **Backend as Single Source of Truth**: Document metadata, page counts, pricing calculation, order lifecycle, and OTP release tokens are strictly validated on the backend.
- **Physical Isolation**: The print agent runs directly on the kiosk hardware next to the printer, communicating with the central backend over authenticated REST endpoints and heartbeats.

---

## 🚀 Main User & Kiosk Workflow

1. **Station Selection**: Discover active kiosk stations via `GET /api/print-servers` or scan a kiosk QR code.
2. **Document Upload**: Select PDF, JPG, or PNG. Client validates size/type, calculates SHA-256 hash, and uploads via `POST /api/documents/upload`.
3. **Print Options & Price Calculation**: Configure copies, page ranges, duplex (single/double-sided), color mode (monochrome/color), and paper size (A4, Letter, Legal). The backend computes authoritative pricing.
4. **Order Placement & Razorpay Payment**: Order is created via `POST /api/orders` and Razorpay payment order initiated via `POST /api/payments/create`.
5. **Secure 6-Digit OTP Generation**: Once payment is verified, the order enters `WAITING_FOR_OTP` and generates a 6-digit release code with a 15-minute expiration countdown.
6. **Physical Print Release**: The user approaches the kiosk touchscreen/keypad, enters their 6-digit OTP, and the agent triggers `POST /local/release` to send the document to CUPS.
7. **Live Tracking & History**: Live polling tracks the order status from `PENDING` → `PAID` → `WAITING_FOR_OTP` → `PRINTING` → `COMPLETED`.

---

## 📂 Project Structure

```text
Autonomous-Printer/
├── backend/                         # FastAPI Central Backend
│   ├── app/
│   │   ├── api/                     # REST API routes (auth, documents, orders, payments, agent)
│   │   ├── config/                  # Settings, database connection & security configs
│   │   ├── db/                      # SQLAlchemy models, sessions & seed data
│   │   ├── schemas/                 # Pydantic v2 validation models
│   │   ├── services/                # Pricing, OTP, document storage, and job services
│   │   └── utils/                   # Crypto, rate limiting, and state machines
│   ├── tests/                       # Pytest automated test suite
│   ├── .env.example                 # Backend environment variable template
│   └── requirements.txt             # Backend Python dependencies
│
├── frontend/                        # Flutter Application (Android, Web, Desktop)
│   ├── android/                     # Android native project files & Gradle build
│   ├── lib/
│   │   ├── config/                  # API endpoints, SharedPreferences & dark theme
│   │   ├── models/                  # Document, Order, Payment & PrintServer models
│   │   ├── screens/                 # 8 dedicated screens for each step of workflow
│   │   │   ├── main_nav_screen.dart
│   │   │   ├── stations_screen.dart
│   │   │   ├── upload_screen.dart
│   │   │   ├── print_options_screen.dart
│   │   │   ├── payment_screen.dart
│   │   │   ├── otp_release_screen.dart
│   │   │   ├── station_terminal_screen.dart
│   │   │   ├── orders_history_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/                # Backend API service & Print Agent client
│   │   └── widgets/                 # Reusable UI widgets (OTP cards, badges, station cards)
│   └── pubspec.yaml                 # Flutter dependencies & metadata
│
├── print-agent/                     # Flask Local Print Agent & CUPS Interface
│   ├── app/
│   │   ├── routes/                  # /health, /local/status, /local/release endpoints
│   │   ├── services/                # Backend poller, CUPS driver, local document finder
│   │   └── main.py                  # Agent entrypoint (Port 5001)
│   ├── tests/                       # Agent unit & integration tests
│   ├── .env.example                 # Agent configuration template
│   └── requirements.txt             # Agent Python dependencies
│
├── requirements.txt                 # Unified repository Python dependencies
└── README.md                        # Project documentation
```

---

## ⚡ Quickstart Guide

### Prerequisites
- **Python**: 3.12+
- **Flutter SDK**: 3.13+ (`dart >= 3.0`)
- **Android SDK** (for APK generation) or Chrome / Edge / Desktop runner
- **CUPS** (on Linux hosts running the print agent)

---

### 1. Run the FastAPI Backend (Terminal 1)

```bash
cd backend

# Setup Python environment
python -m venv venv
# On Linux/macOS:
source venv/bin/activate
# On Windows PowerShell:
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env

# Run FastAPI development server on port 8000
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- **Interactive Swagger Docs**: `http://127.0.0.1:8000/docs`
- **ReDoc**: `http://127.0.0.1:8000/redoc`

---

### 2. Run the Flask Print Agent (Terminal 2)

```bash
cd print-agent

# Setup Python environment
python -m venv venv
# On Linux/macOS:
source venv/bin/activate
# On Windows PowerShell:
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env

# Start Flask print agent on port 5001
python app/main.py
```
- **Health Check**: `http://127.0.0.1:5001/health`
- **Station Status**: `http://127.0.0.1:5001/local/status`

---

### 3. Run the Flutter Frontend (Terminal 3)

```bash
cd frontend

# Fetch dependencies
flutter pub get
```

#### Run in Google Chrome (Fastest & Live Hot-Reload):
```bash
flutter run -d chrome
```

#### Run on Windows Desktop:
```bash
flutter run -d windows
```

#### Run on Android Emulator or Physical Phone:
```bash
flutter run
```

#### Build Android APK:
```bash
flutter build apk --debug
```
The output installable file will be generated at:
```text
frontend/build/app/outputs/flutter-apk/app-debug.apk
```

---

## ⚙️ Configuring App Network Endpoints

Inside the Flutter application, tap the **Settings** icon on the top right:
- **Chrome / Windows Desktop**:
  - Backend URL: `http://127.0.0.1:8000`
  - Print Agent URL: `http://127.0.0.1:5001`
- **Android Emulator**:
  - Tap the **"Android Emulator (10.0.2.2)"** quick preset button.
  - Backend URL: `http://10.0.2.2:8000`
  - Print Agent URL: `http://10.0.2.2:5001`
- **Physical Android Device (Same Wi-Fi)**:
  - Backend URL: `http://<YOUR_PC_LAN_IP>:8000`
  - Print Agent URL: `http://<YOUR_PC_LAN_IP>:5001`

Tap **Test Backend Connection** to verify green ping status.

---

## 🔌 API Summary

### Backend Endpoints (`http://127.0.0.1:8000`)
- `GET  /api/print-servers` — List available kiosk print stations and status.
- `POST /api/documents/upload` — Multipart upload for PDF, PNG, JPG files.
- `POST /api/orders` — Create validated order with custom print configuration.
- `GET  /api/orders/{id}` — Fetch order status, page count, and billing info.
- `POST /api/payments/create` — Generate Razorpay payment order.
- `POST /api/payments/webhook` — Razorpay webhook endpoint with HMAC-SHA256 signature verification.
- `GET  /api/orders/{id}/otp` — Retrieve 6-digit release OTP code.
- `POST /api/agent/release` — Authenticated release endpoint called by print agent.
- `POST /api/agent/heartbeat` — Print agent kiosk health registration.

### Print Agent Endpoints (`http://127.0.0.1:5001`)
- `GET  /health` — Agent uptime and diagnostic status.
- `GET  /local/status` — Local CUPS printer status and paper levels.
- `POST /local/release` — Keypad/touchscreen OTP submission releasing local CUPS print job.

---

## 🧪 Testing

```bash
# Backend test suite
cd backend
pytest -v

# Print agent test suite
cd print-agent
pytest -v

# Flutter widget tests
cd frontend
flutter test
```

---

## 📄 License
This project is licensed under the MIT License.
