# Achuppori

Flutter web frontend, FastAPI backend, MySQL, and a local CUPS print agent. Payments use Razorpay Standard Checkout with server verification. The currently configured Windows installation uses **Razorpay test mode and simulated printing**.

## Setup on Windows and Ubuntu

Use **Flutter 3.47.5 (Dart 3.13.4)** and **Python 3.14** to match the tested build. Put Flutter/Python on PATH. Web/mobile setup disables desktop plugin generation in this project's pubspec, so Windows web builds do not require Developer Mode. Ubuntu requires `python3-venv`; physical printing additionally requires CUPS and `pycups`.

Run from the repository root after cloning:

```powershell
# Windows
python scripts/project.py setup
start_all.bat
```

```bash
# Ubuntu
python3 scripts/project.py setup
bash start_all.sh
```

Open http://127.0.0.1:3000/. Setup installs pinned Python dependencies and the committed Flutter lockfile. Fresh installations use SQLite, random local secrets and a simulated print station. Existing configuration and database records are preserved. Configure your Razorpay test keys in `backend/.env` before testing checkout; placeholder keys cannot process payments. MySQL and physical printing require your own database/station configuration.

After pulling, repeat setup if dependencies changed and restart. Launchers automatically rebuild when web sources, assets, dependencies or the Flutter SDK change. Force rebuild with `start_all.bat -Build` or `bash start_all.sh --build`; use `-Hot` or `--hot` for development. Stop Windows services with `stop_all.bat`, or the Ubuntu launcher with Ctrl+C. Logs are in `.runtime/`. Launchers check service readiness; Ubuntu includes the payment reconciliation worker and stops only its own processes.

Build only: `python scripts/project.py build` (use `python3` on Ubuntu). Direct Flutter builds work after `flutter pub get --enforce-lockfile`; generated `active_tunnel.dart` is no longer required. APK scripts use the `ACTIVE_TUNNEL_URL` build definition. Start `bash start_tunnel.sh` separately when needed. Hosted web builds use a same-origin API unless `API_BASE_URL` is specified at build time; configure matching CORS/CSP for a separate API.

The default agent health/keypad are http://127.0.0.1:5001/health and http://127.0.0.1:5001/kiosk; agent `PORT` overrides this. `.gitattributes` keeps shell scripts on LF across operating systems. GitHub CI checks Windows and Ubuntu and uploads release web bundles.

## Existing Windows installation

Double-click `start_all.bat`, then open http://127.0.0.1:3000/. The launcher starts four background processes: API, reconciliation worker, print agent, and frontend. MySQL80 must be running.

- Stop: `stop_all.bat`.
- Rebuild Flutter: `start_all.bat -Build`.
- Logs: `.runtime/`.
- Backend health: http://127.0.0.1:8000/health.
- Local API reference: http://127.0.0.1:8000/docs.
- Agent health: http://127.0.0.1:5001/health.
- Local station keypad: http://127.0.0.1:5001/kiosk (open on the station computer).

The installed Flutter SDK is at `D:\flutter_windows_3.47.5-stable\flutter`. Python dependencies are in `.venv`. Configuration belongs in `backend/.env` and `print-agent/.env`; Flutter does not consume `frontend/.env`. Never place payment secrets or agent tokens in Flutter.

Upload a PDF/image, choose options, review the server-priced order, and select **Pay with Razorpay**. Razorpay test keys exercise the same checkout, server verification, release-code and print flow as live keys. The application has no unpaid print shortcut. Use **Check payment status** to recover a lost checkout response; **Your orders** resumes orders in the current browser tab.

The Windows installation still uses simulated printing and produces no paper. Physical printing requires a configured CUPS agent.

## Payment and printing flow

1. Backend issues a random customer session; ownership applies to documents, orders, payment requests, and OTPs.
2. Backend validates document contents/options, calculates the amount, and renders an immutable print-ready PDF. Client prices and payment status are never accepted.
3. A durable payment intent creates one Razorpay order. Checkout callback HMAC is checked against the stored provider order ID. Backend fetches the payment and order and checks full capture, amount, currency, receipt, and refund state.
4. A transaction creates one job and one expiring release code. Signed webhooks and the independent reconciliation worker recover lost callbacks.
5. A release code works once at its assigned station. The authenticated agent claims the job once and checks file size/hash before submission.
6. A durable agent journal records submission and CUPS confirmation. Unknown submission or completion stays unresolved for operator review; it is never reported as success or automatically printed again.
7. Expired unused release codes and confirmed failures before submission enqueue refunds. Provider confirmation is required before a refund is complete; uncertain refund submissions are reconciled without repeated POSTs.

## Setup, operations, and deployment

- [Backend guide](backend/README.md)
- [Frontend guide](frontend/README.md)
- [Print-agent guide](print-agent/README.md)
- [Security architecture and deployment requirements](docs/SECURITY.md)

The additive security migration has been applied to this installation's `printer` MySQL database. Old records remain for review and do not become verified payments. A local pre-migration logical backup is in `.runtime/pre-security-database-backup.json`; restrict access to this file.

## Tests

From the repository root:

```powershell
cd backend
..\.venv\Scripts\python.exe -m pytest tests -q
cd ../print-agent
..\.venv\Scripts\python.exe -m pytest tests -q
cd ../frontend
flutter test --no-pub
flutter analyze --no-pub
```

From the root, `.venv\Scripts\python.exe scripts/test-mysql-security.py` creates and drops a disposable MySQL database using the configured database account. MySQL concurrency tests are opt-in using `MYSQL_SECURITY_TEST_URL`, and **destroy their isolated database tables**; only a disposable database whose name begins `printer_security_test_` is accepted. Never point tests at the application database.

Security testing reduces risk; it is not a guarantee against every attack. Public HTTPS webhook delivery, production deployment, and physical CUPS output require verification on the actual server and printer before accepting live payments.
