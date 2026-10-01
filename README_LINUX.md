# Running Autonomous Printer on Ubuntu / Linux 🐧

This guide documents the setup and runtime configuration for running the complete Autonomous Self-Service Printing Platform on Ubuntu with live desktop console windows and physical HP printer integration.

---

## 🖥️ Live Desktop Consoles (Screen Windows)

To see the live real-time output and console logs of all three services directly in visual windows on your desktop screen, run:

```bash
cd /home/smartprint/Documents/SmartPrint
./start_gui_terminals.sh
```
*(Or simply run `./start_all.sh --gui`)*.

This immediately launches **3 separate visual terminal windows** arranged on your screen:
1. **[1] FastAPI Backend (Port 8000)**: Live REST API request logs, OTP verification, and database telemetry.
2. **[2] Flask Print Agent (Port 5000)**: Live CUPS job execution, printer polling, and physical print progress.
3. **[3] Flutter Frontend (Port 3000)**: Web application server serving the user portal.

---

## 🚀 Headless / Standard Terminal Mode

If you prefer running everything unified within a single terminal:
```bash
./start_all.sh
```
*(Press `Ctrl+C` at any time to cleanly stop all background services).*

---

## 🌐 Web Interfaces & Endpoints

| Service | URL | Description |
| :--- | :--- | :--- |
| **Flutter Web Application** | [`http://127.0.0.1:3000`](http://127.0.0.1:3000) | Customer workflow: Upload PDF/images, configure print options, Razorpay checkout, and OTP generation. |
| **Kiosk Touchscreen Terminal** | [`http://127.0.0.1:8000/kiosk`](http://127.0.0.1:8000/kiosk) | Interactive physical kiosk interface with virtual touchscreen numpad, OTP validation, and live print telemetry. |
| **FastAPI Interactive Docs** | [`http://127.0.0.1:8000/docs`](http://127.0.0.1:8000/docs) | Swagger UI for testing all REST endpoints. |
| **Flask Print Agent Health** | [`http://127.0.0.1:5000/health`](http://127.0.0.1:5000/health) | Diagnostics, CUPS connection status, and heartbeat ping. |
| **Station Hardware Status** | [`http://127.0.0.1:5000/local/status`](http://127.0.0.1:5000/local/status) | Real-time CUPS printer status (`READY`), paper levels, and active job count. |

---

## 🖨️ Physical Printer Configuration & Root Cause Fix

### Why the printer previously showed "COMPLETED" without printing:
1. **Network Subnet Mismatch**:
   - The physical **HP LaserJet 400 M401dn** is located on IP address `10.1.100.60`.
   - The Ubuntu PC network interface `enp2s0` was only configured with IP `172.17.3.5/22`, making `10.1.100.60` unreachable ("The printer is unreachable at this time").
   - **Fix Applied**: Added secondary IP `10.1.100.250/24` permanently in NetworkManager (`nmcli con mod "Wired connection 1" +ipv4.addresses "10.1.100.250/24"`).
2. **CUPS Connection Protocol**:
   - CUPS was initially configured with an unresolvable mDNS IPP URI (`ipp://HP%20LaserJet...local/`).
   - **Fix Applied**: Updated CUPS device URI to standard raw JetDirect socket `socket://10.1.100.60:9100` and attached the official HP LaserJet 400 M401 PostScript PPD driver.
3. **Backend Premature Simulation**:
   - The backend had a background simulation thread (`_simulate_backend_printing`) that prematurely forced orders into `COMPLETED` after 5 seconds even when the physical printer was unreachable.
   - **Fix Applied**: Disabled fake backend simulation whenever the real print agent is online, allowing the real CUPS hardware status to govern the job lifecycle.
4. **State Machine Idempotency**:
   - Transitioning from `PRINTING` to `PRINTING` threw a 400 Bad Request error. Added idempotency guard (`if current == target: return`) in `state_machine.py`.

---

## 🧪 Automated Testing

Both suites are verified 100% passing:
```bash
./venv/bin/python -m pytest backend/tests
./venv/bin/python -m pytest print-agent/tests
```
