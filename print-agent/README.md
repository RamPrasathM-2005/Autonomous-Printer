# 🖨️ Achuppori - Flask Print Agent

Lightweight local daemon built with **Python 3.12+** and **Flask**. Designed to run on the kiosk controller (Ubuntu Linux, Raspberry Pi, or local Windows machine). It connects directly to the physical printer via **CUPS (Common Unix Printing System)** or standard `lp` commands, sends heartbeats to the central FastAPI backend, and releases print jobs upon OTP verification.

---

## 📋 Prerequisites

- **Python 3.12+** ([python.org](https://www.python.org/downloads/))
- **CUPS Printing System**:
  - **Linux / Raspberry Pi**: Pre-installed on most distributions or installable via:
    ```bash
    sudo apt update && sudo apt install -y cups libcups2-dev
    ```
  - **Windows (Development)**: Set `MOCK_CUPS=true` in `.env` to simulate CUPS execution without requiring a physical printer hardware daemon.

---

## ⚙️ Environment Configuration

1. In the `print-agent/` directory, copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
   *(On Windows PowerShell: `Copy-Item .env.example .env`)*

2. Configure your `.env` variables:
   ```env
   # Station Identifier matching backend print_servers table
   AGENT_ID="PRINT-SERVER-001"

   # Backend API Endpoint
   BACKEND_URL="http://127.0.0.1:8000/api"

   # Secret device authentication token configured for this station
   AGENT_TOKEN="test-agent-device-token-secret"

   # Path to shared document storage (relative or absolute)
   STORAGE_ROOT="../backend/storage"

   # Polling & Heartbeat Intervals (in seconds)
   POLL_INTERVAL_SECONDS=3
   HEARTBEAT_INTERVAL_SECONDS=15

   # Physical CUPS Printer Settings
   CUPS_SERVER="localhost"
   PRINTER_NAME="Default_Office_Printer"

   # Set to 'true' for local development on Windows without CUPS
   # Set to 'false' in production on Linux with real CUPS printer
   MOCK_CUPS=true
   ```

---

## 🚀 Step-by-Step: How to Run

### Step 1: Navigate to the Print Agent Directory
```bash
cd print-agent
```

### Step 2: Create and Activate a Python Virtual Environment

- **On Windows (PowerShell)**:
  ```powershell
  python -m venv venv
  .\venv\Scripts\Activate.ps1
  ```

- **On Linux / Raspberry Pi**:
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  ```

### Step 3: Install Required Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 4: Run the Print Agent
```bash
python app/main.py
```

When started successfully, you will see output similar to:
```text
[INFO] Starting Flask Print Agent for station: PRINT-SERVER-001
[INFO] Heartbeat thread started (interval: 15s)
[INFO] Job poller thread started (interval: 3s)
 * Running on http://127.0.0.1:5000
```

---

## 🔍 Verification & Health Check

In a separate terminal or browser:

```bash
curl http://127.0.0.1:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "agent_id": "PRINT-SERVER-001",
  "printer": "Default_Office_Printer",
  "mock_cups": true
}
```

---

## 🧪 Running Automated Tests

Run the pytest suite to verify job polling, CUPS command translation, and local OTP release:

```bash
pytest -v
```

---

## 🐧 Production Linux Systemd Service (Autonomous 24/7 Daemon)

To have the print agent start automatically on kiosk boot on Ubuntu or Raspberry Pi OS:

1. Create a service file at `/etc/systemd/system/printplatform-agent.service`:
   ```ini
   [Unit]
   Description=Autonomous Print Agent Daemon
   After=network.target cups.service
   Wants=cups.service

   [Service]
   User=pi
   Group=lpadmin
   WorkingDirectory=/opt/Autonomous-Printer/print-agent
   EnvironmentFile=/opt/Autonomous-Printer/print-agent/.env
   ExecStart=/opt/Autonomous-Printer/print-agent/venv/bin/python app/main.py
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```

2. Enable and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable printplatform-agent
   sudo systemctl start printplatform-agent
   sudo systemctl status printplatform-agent
   ```

---

## 🛠️ Common Troubleshooting

| Issue | Resolution |
| :--- | :--- |
| **`pycups` installation fails on Windows** | Windows does not support native `pycups`. The codebase automatically detects Windows and uses simulated `lp` / mock drivers. Ensure `MOCK_CUPS=true` in `.env`. |
| **Backend heartbeats returning 401 Unauthorized** | Verify that `AGENT_TOKEN` in `print-agent/.env` matches the `auth_token` registered in the backend's `print_servers` database table. |
| **Document file not found during print** | Check `STORAGE_ROOT` in `.env`. It must point to the folder where the backend stores documents (e.g., `../backend/storage`). |
