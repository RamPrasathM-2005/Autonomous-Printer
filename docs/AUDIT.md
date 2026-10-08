# Flow audit and correction record

Audit date: 8 October 2026. Scope: the repository's Flutter client, FastAPI backend/database code, payment/refund services, station agent, kiosk, CUPS integration and deployment configuration. Work was performed from the Windows development checkout; no deployed server, Pi, touchscreen, physical HP printer or live payment account was connected.

| Finding | Correction |
| --- | --- |
| Central backend called private agent IPs and unrelated localhost fallback agents | Printing now uses authenticated outbound polling; admin discovery/test uses heartbeat observations from the assigned agent |
| Public kiosk release and server hardware proxies could release remotely | Backend station release requires a device token; customer release and retired proxy paths reject physical-release bypasses |
| Codes and printer routing contained hardcoded HP queues, invented second printers and cross-station fallbacks | Codes use actual registered station queues; release validates station/assignment; arbitrary switching and default-queue fallback are rejected |
| Third printer code generation called nonexistent functions | All real queues use the same collision-aware code generator |
| Wrong guesses could invalidate unrelated customers' paid orders | Guess throttling applies to the requesting station; unknown codes no longer mutate unrelated OTP rows |
| Stale ONLINE state could accept a new order after the Pi disconnected | Order creation requires a recent station heartbeat and an enabled registered printer |
| OTP regeneration inserted a second row despite unique order constraint | Existing per-order OTP row is updated |
| OTP endpoint provisioned release codes for unpaid orders | Captured payment is required; release separately verifies captured payment |
| Order/document/payment APIs accepted arbitrary customer record IDs | Ownership checks support customer sessions and authenticated users; order lists are scoped to the customer |
| Session tokens and enumerable OTP hashes appeared in ordinary order settings | Sensitive ownership/code values are removed from ordinary responses and agent payloads |
| Polling/kiosk/restart races could print the same released job twice | Atomic backend claim occurs before CUPS submission; local deduplication also remains |
| Lost status HTTP requests and Pi restarts lost the outcome | Durable status outbox with event IDs; submitted CUPS IDs are monitored after restart |
| Failed downloads generated a blank replacement PDF | Download failure stops printing; partial downloads use atomic replacement |
| Queue disappearance, CUPS errors and monitoring timeouts reported completion | Only explicit CUPS terminal state confirms completion; unknown outcomes need operator review |
| Windows could silently simulate physical printing | Simulation requires explicit MOCK_CUPS; physical agent startup requires pycups |
| Kiosk timer reported success without printer confirmation | Timer-based completion removed; failure/unknown states are displayed |
| Customer UI showed fixed hardware names and continued printing display after failure | Registered names and backend errors/terminal status now drive the view |
| QR ignored deployed website overrides and selected first online station | QR uses configured customer website and station query; upload honors selected station |
| Agent status data exposed wildcard CORS | Default agent binding is loopback; CORS is limited to station/configured origins |
| Refund errors could be simulated as success | Gateway result is required; pending refunds reconcile, ambiguous failures need review |
| Admin settings did not survive restart; pricing ignored configured rate | Database-backed platform settings; configured monochrome rate/base fee are used |
| Schema changes could fail silently while reporting migration success | Shared SQLite/MySQL-compatible additive migration fails visibly |
| Admin deletion referenced nonexistent PROCESSING job state | Active-job guard uses valid RELEASED/PRINTING states |
| Backend installation missed document preview/report dependencies | Component requirements include required preview/export packages; stale root locks removed |

## Verification and limits

Validation includes the backend and agent suites, 44 passing Flutter tests, clean Flutter analysis and a successful release web build. Python compilation and Git whitespace checks passed. The latest maintenance checks are recorded below. Dependency deprecation warnings remain in the Python test output.

Automated tests include checkout/OTP/status flow, wrong-station rejection, exclusive claims, customer isolation, real-printer code generation, retry event idempotency, heartbeat-based USB validation, refund failure behavior, persistent pricing, CUPS terminal states, missing document handling, and outbox persistence. Flutter tests exercise admin/customer screens and responsive widths from 320 to 1280 pixels.

Automated tests use SQLite and fake gateway/CUPS responses. They cannot certify your MySQL deployment, printer driver capabilities, physical page output, Raspberry Pi restart timing, browser permissions, SMTP delivery, native app builds or live Razorpay behavior. Follow the hardware acceptance run in DEPLOYMENT.md before declaring the installation production-ready.

An isolated backend/agent HTTP smoke run also passed using separate subprocesses and storage. It exercised authenticated OTP release, outbound document download, atomic claim, simulated CUPS completion, backend status propagation, duplicate release rejection and spool cleanup. Payment was a pre-captured fixture and printing was explicitly simulated.

Residual operational constraints: process-local OTP rate limiting (use the provided single backend worker until replaced with a shared limiter); a claim/submission crash gap requires operator inspection; CUPS history must retain submitted IDs; native builds and Wayland kiosk behavior require device testing. Existing historical anonymous records without ownership need administrator review. Color pricing remains the existing fixed INR 10/page policy.

## Deployment and maintenance follow-up

- Replaced the MySQL-only reset and sample-department seed. The reset recreates all tables and seeds one administrator, on SQLite or MySQL/MariaDB. Repeated non-destructive seeding updates the same admin. Invalid administrator credentials fail before deletion.
- Added explicit local-data reset with protected source/configuration paths and separate Pi-only mode. A recreated SQLite database remains intact even if it is stored inside the upload directory. Remote Pi state, browser sessions and CUPS system history are separate from server application data.
- Consolidated Ubuntu/Windows launchers into `run-local.py` and `run-server.py`. The server runner excludes the agent and its dependencies. Local website API proxying works for LAN phone browsers. Windows shutdown terminates only supervised child process trees, fixing leftover venv child processes.
- Removed obsolete launch/tunnel/packaging scripts, historical README, mock station initializer, duplicate database tools, scratch test and stale dependency locks. Runtime logs are removed from Git and ignored; an open local log may remain until its running process stops.
- Simplified environment templates and cleaned unused keys from the existing private environment files while preserving configured credentials. Backend production no longer requires an unused shared agent token. Physical stations use the admin-generated device token.
- Agent uses Waitress with four HTTP threads, one print worker by default, bounded caches/logs, a persistent journal, interruptible worker waits and effective polling backoff. Missing physical printers no longer report READY. JSON agent logs include UTC timestamps, station, PID and thread for restart diagnosis.
- Kiosk uses the explicitly configured website instead of scanning local tunnel files. It avoids identical QR image refreshes and overlapping health polling. Browser launch is locked to one loop per user; deployment installs one per-user autostart and exits unsuccessfully when health verification fails.
- The configured local database passed read-only missing-column, duplicate-unique-value and orphan-reference checks with zero detected conflicts. Existing data was preserved. Destructive tests used disposable SQLite databases; the configured database was not reset.
- The supplied Pi SSH endpoint was not reachable from this Windows machine. Actual service restart causes, memory pressure, CUPS/HP output and touchscreen behavior remain unverified. Use the runbook's journal, restart counter, memory and CUPS checks on the Pi.

The HTTP smoke now includes frontend API proxying and customer isolation, and starts the agent through its production entry point. Payment capture remains a fixture and printing remains explicitly simulated.

Latest security follow-up: 113 backend tests, 37 agent tests and 44 Flutter tests passed. Flutter analysis, release web build, LAN HTTP smoke, Python compilation and Git whitespace checks passed. See [the security audit](SECURITY_AUDIT.md) for corrected findings, local-network simulation commands and remaining deployment checks. Ubuntu/Pi systemd installation and MySQL execution require the actual deployment machines.
