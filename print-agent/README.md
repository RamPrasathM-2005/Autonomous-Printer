# Print agent

The agent authenticates to the backend, advertises station/printer state, claims released jobs, verifies file SHA-256 and size, submits to CUPS, and reports confirmed status. Customer browsers do not receive the agent token or direct storage paths.

For this Windows test installation, `start_all.bat` runs the agent on 127.0.0.1:5000 with `MOCK_CUPS=true`. Mock printing requires the backend's explicit permission and a verified Razorpay test payment. It does not produce paper.

Open `http://127.0.0.1:5000/kiosk` on the station computer for the responsive release-code keypad. It posts codes in a JSON body to the local authenticated agent bridge, never in URLs. Successful release only queues the job; the polling worker performs the atomic claim and durable submission. Check the customer's order page for actual progress. The keypad has no payment shortcut or automatic print-completion timer. `PORT` defaults to 5000 and can be changed in the agent environment; update any local terminal URL accordingly.

For physical output use Linux, CUPS and pycups, a configured queue, `MOCK_CUPS=false`, and backend `ALLOW_MOCK_PRINTING=false`. Run `python -m app.main` from `print-agent` under a restricted OS account. Install `pycups` and OS CUPS development packages where required. `STORAGE_ROOT` must reference the same protected storage as the backend; a remote agent needs a private authenticated filesystem mount. Public document download is intentionally absent.

Copy `.env.example` only for a new installation. Protect `.env`, the SQLite journal under `STATE_ROOT`, and spool files. One process owns the journal using an OS lock; do not run multiple agent workers or delete the journal to retry printing. Local endpoints are restricted to loopback Host and explicit browser origins. Keep port 5000 private.

The agent records PREPARED before submission and SUBMITTED with the returned CUPS job ID. After restart, submitted jobs are monitored and final reports retried. A crash between printer submission and persisting its job ID cannot be resolved automatically; it is held for operator review, never blindly submitted again. Missing CUPS history is UNKNOWN, not success. This is intentionally conservative because paper output cannot be made transactionally atomic with a SQL database.

See [operations and security](../docs/SECURITY.md).
