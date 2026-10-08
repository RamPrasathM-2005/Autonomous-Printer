# Achuppori department printing

Flutter serves customers and administrators. FastAPI owns the database, documents, payments, release codes and status. Each department's Raspberry Pi runs only the CUPS agent and local touchscreen kiosk. The Pi communicates outbound with the server using its own device token.

```text
Phone -> server website/API -> database + documents
Pi keypad -> paid OTP verification -> exclusive claim -> assigned CUPS queue
Pi -> persistent status journal -> server -> customer/admin status
```

## Local Ubuntu / Windows

Install Python 3.12+ and Flutter on PATH. Ubuntu full local mode also requires `sudo apt install libcups2-dev python3-dev build-essential`. From the repository:

```bash
python run-local.py setup
```

Configure `backend/.env`: administrator credentials, JWT, SMTP and Razorpay test credentials. Seed only the admin, without deleting existing records:

```bash
cd backend
# Ubuntu:
../.venv/bin/python -m app.db.seed
# Windows PowerShell:
..\.venv\Scripts\python.exe -m app.db.seed
cd ..
python run-local.py run
```

Open http://localhost:3000. Register departments and a station in admin, copy its generated ID/token to `print-agent/.env`, restart the local runner, and register the discovered CUPS queue. Windows agent testing requires explicit `MOCK_CUPS=true`.

When printing runs on a separate Pi, use `python run-server.py setup` and `python run-server.py run` on the PC instead. Set Pi `BACKEND_URL=http://PC_IP:3000/api` and `KIOSK_WEB_URL=http://PC_IP:3000`. Allow TCP 3000 through the PC firewall. The frontend runner proxies API calls so phone browsers can upload through the same LAN address.

The two launchers share one supervisor and cached web build. Ctrl+C stops child services. The server launcher starts backend, refund worker and frontend only. For public hosting use [DEPLOYMENT.md](docs/DEPLOYMENT.md)'s Nginx/systemd commands.

## Reset and seed

Stop services first. This permanently drops **every table in the configured dedicated application database**, recreates the schema, seeds exactly one administrator and clears local uploads, spool/journal, logs and runtime files. It preserves source, `.env`, virtual environments and frontend builds. No sample departments, agents or printers are created.

```bash
# Ubuntu, repository root:
.venv/bin/python scripts/reset_data.py --yes
# Windows PowerShell:
.\.venv\Scripts\python.exe scripts/reset_data.py --yes
```

A server command cannot clear a separate Pi. Stop its agent, inspect/cancel outstanding CUPS jobs, then run `print-agent/venv/bin/python scripts/reset_data.py --agent-only --yes` on the Pi. Clear browser site data on each client separately. Reset removes station registrations; register them again and update their device tokens before restarting.

Read-only conflict check: `.venv/bin/python scripts/check_database.py` (use `.\.venv\Scripts\python.exe` on Windows). Non-destructive upgrade: from backend, run `../.venv/bin/python -m app.db.migrate`.

## Validation

Run Python suites separately because both components use an `app` package:

```bash
cd backend
../.venv/bin/python -m pytest tests -q
cd ../print-agent
../.venv/bin/python -m pytest tests -q
cd ..
.venv/bin/python scripts/verify_station_flow.py
cd frontend
flutter analyze
flutter test
```

The HTTP smoke uses isolated temporary SQLite, a pre-captured payment fixture and explicit CUPS simulation. Physical printing, touchscreen interaction, SMTP, live refunds and MySQL require deployment testing. [AUDIT.md](docs/AUDIT.md) records corrections and limits.

For the security audit, fixes and automatic/manual LAN simulation commands, see [SECURITY_AUDIT.md](docs/SECURITY_AUDIT.md). Run `python scripts/verify_station_flow.py --lan` with the project virtual environment for an isolated test through this PC's LAN address.
