# Backend

Run commands from `backend` using the repository virtual environment.

```powershell
..\.venv\Scripts\python.exe -m app.db.migrate
..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Run the reconciliation worker in a separate supervised process:

```powershell
..\.venv\Scripts\python.exe -m app.worker
```

Read-only operational status:

```powershell
..\.venv\Scripts\python.exe -m app.ops
```

Copy `.env.example` only for a new installation; preserve the existing configured `.env`. Generate independent random secrets for JWT and OTP hashing, and a Fernet key for OTP encryption. Use real Razorpay **test** credentials for development. A webhook secret is separate from the API key secret. The worker needs the same settings and database as the API.

The existing installation uses MySQL database `printer`. Stop services and back up MySQL before running migrations on another installation. `app.db.migrate` is additive and repeatable. Legacy/demo payments are not trusted and their codes are disabled. Run migrations with a schema administrator, then run API/worker with a separate restricted account. Runtime uses MySQL READ COMMITTED with explicit row locks and unique constraints for transitions/idempotency.

`python -m app.db.seed` provisions a station from the agent configuration for a new database. It creates no default user/admin accounts and does not reset an existing device token. Keep raw tokens in the agent's protected environment only; the database contains a hash.

Customer API authentication uses short-lived guest bearer sessions, not the unused legacy user-login code. There is no public admin registration or payment-state override. `/api/maintenance/cleanup` requires an administrator token; normal cleanup runs in the worker. Prefer the local read-only operations command for monitoring.

See [security and deployment](../docs/SECURITY.md) for webhook events, review procedures, live-mode preparation, and limitations.
