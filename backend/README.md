# Smart Self-Service Printing Platform - FastAPI Backend

Central FastAPI REST API backend for the self-hosted printing platform.

## Architecture Highlights
- **Framework**: FastAPI (Python 3.12+)
- **Database**: MySQL (compatible with SQLite in local/dev testing) via SQLAlchemy 2.0
- **Authentication**: JWT (Access Token short-lived, Refresh Token stored & revocable)
- **File Storage**: Local Linux storage outside app root (`STORAGE_ROOT`) with directory traversal protection & atomic file operations
- **Payment Gateway**: Razorpay with HMAC-SHA256 signature verification & webhook idempotency
- **Print Release**: Secure 6-digit OTP with attempt rate-limiting & state machine transaction locks
- **Print Agent Protocol**: Device token authentication, heartbeat monitoring, job polling & lifecycle status reporting

## Project Structure
```text
backend/
├── app/
│   ├── main.py
│   ├── config/          # Settings, Database & Security
│   ├── db/              # SQLAlchemy Base, Session & 12 Models
│   ├── api/             # Routes (auth, docs, orders, payments, agent, maintenance) & Dependencies
│   ├── schemas/         # Pydantic v2 schemas
│   ├── services/        # Business logic (pricing, storage, otp, jobs, refunds, cleanup)
│   └── utils/           # Crypto, file security, state machines, custom errors
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
3. Run the development server:
   ```bash
   uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
   ```
4. Run tests:
   ```bash
   pytest -v
   ```

## Production Deployment (Ubuntu Linux)

### Systemd Service (`/etc/systemd/system/printplatform-backend.service`):
```ini
[Unit]
Description=Print Platform FastAPI Backend
After=network.target mysql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/printplatform/backend
EnvironmentFile=/etc/printplatform/backend.env
ExecStart=/opt/printplatform/backend/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 4
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
