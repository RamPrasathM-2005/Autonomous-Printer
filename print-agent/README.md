# Smart Self-Service Printing Platform - Flask Print Agent

Local print agent running on Ubuntu machines connected to CUPS printers.

## Responsibilities
- Periodic authenticated heartbeats to FastAPI (`/api/agent/heartbeat`)
- Offline detection reporting (printer state, paper availability)
- Job polling from FastAPI (`/api/agent/jobs`) with in-memory deduplication
- Physical station OTP release (`POST /local/release`) for touchscreen/keypad input
- Secure local document lookup from shared `STORAGE_ROOT` (no network transmission needed)
- CUPS submission via `pycups` or CLI `lp` with option translation (copies, page range, duplex, color, media size, orientation)
- Real-time job status reporting (`PRINTING`, `COMPLETED`, `FAILED`) to FastAPI

## Project Structure
```text
print-agent/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── routes/          # /health and /local/status, /local/release
│   ├── services/        # backend_client, cups_service, file_service, job_poller, print_service
│   └── utils/           # logging, errors
├── tests/               # Pytest automated test suite
├── requirements.txt
├── .env.example
└── README.md
```

## Running Locally

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Copy environment file:
   ```bash
   cp .env.example .env
   ```
3. Run the agent:
   ```bash
   python app/main.py
   ```
4. Run tests:
   ```bash
   pytest -v
   ```

## Production Deployment (Ubuntu Linux)

### Systemd Service (`/etc/systemd/system/printplatform-agent.service`):
```ini
[Unit]
Description=Print Platform Flask Print Agent
After=network.target cups.service printplatform-backend.service

[Service]
User=printagent
Group=lpadmin
WorkingDirectory=/opt/printplatform/print-agent
EnvironmentFile=/etc/printplatform/agent.env
ExecStart=/opt/printplatform/print-agent/venv/bin/python app/main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
