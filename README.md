# QwikPrint

Flutter web frontend, FastAPI backend, MySQL, and a local CUPS print agent. Payments use Razorpay Standard Checkout with server verification. The currently configured Windows installation uses **Razorpay test mode and simulated printing**.

## Run this installation

Double-click `start_all.bat`, then open http://127.0.0.1:3000/. The launcher starts four background processes: API, reconciliation worker, print agent, and frontend. MySQL80 must be running.

- Stop: `stop_all.bat`.
- Rebuild Flutter: `start_all.bat -Build`.
- Logs: `.runtime/`.
- Backend health: http://127.0.0.1:8000/health.
- Local API reference: http://127.0.0.1:8000/docs.
- Agent health: http://127.0.0.1:5000/health.

The installed Flutter SDK is at `D:\flutter_windows_3.47.5-stable\flutter`. Python dependencies are in `.venv`. Configuration belongs in `backend/.env` and `print-agent/.env`; Flutter does not consume `frontend/.env`. Never place payment secrets or agent tokens in Flutter.

Upload a PDF/image, choose options, review the **server-priced** order, and use Pay with Razorpay. Only genuine Razorpay test capture can issue a release code. There is no bypass payment button. If checkout loses its response, use Check payment status. Your orders on the upload screen recovers orders in the current browser session after a refresh. Closing the tab or ending the session removes customer access; this guest flow is not an account-based purchase history.

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
