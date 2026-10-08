# Pi deployment investigation — 8 October 2026

This continues the earlier source audit with SSH inspection of the actual Raspberry Pi. The central application runs on Ubuntu `172.17.3.5`; the Pi is `172.17.3.6`; the physical HP LaserJet 400 M401dn is `172.17.3.2`. Printer administration and IPP traffic were performed **on the Pi**, never configured on the server.

## Observed causes

| Symptom | Evidence before correction | Correction |
| --- | --- | --- |
| Detected printers produced no pages | Both Pi queues had `DeviceURI file:/dev/null` in `/etc/cups/printers.conf` | Replaced the E9A0F4 queue with `ipp://172.17.3.2/ipp/print` and an IPP Everywhere driver; removed the unused F36EC0 discard queue |
| Agent could not fetch jobs/heartbeat | Journal repeatedly showed connection refused to `172.17.3.5:8000`; backend listens on loopback | Set Pi backend to `http://172.17.3.5:3000/api`, the exposed same-origin proxy |
| Touchscreen appeared to restart | Two `kiosk-session.sh` processes (PIDs 1168 and 1169), duplicate global/user autostart, numerous Chromium renderers; 876 MiB of 884 MiB swap used | Stopped duplicate launcher/browser processes, removed duplicate startup entries, installed the locked launcher with a dedicated browser profile |
| Reported agent restart | Initial service PID 27648 had `NRestarts=0`, `Result=success` | No evidence of an agent crash in the inspected interval. Browser respawn is separate from service restart; corrected both launcher duplication and stale agent deployment |
| Admin offered no usable printer | Database contained one station but zero registered printers | Registered `PRN-EE14BC88` through authenticated admin API, waited for the Pi heartbeat, then successfully activated it through Test Connection |
| Production HTTP server missing | Both Pi and local Python environment lacked Waitress | Installed Waitress 3.0.2 from its wheel; ran the production agent entry point |
| Pi dependency installation failed | PyPI/piwheels TLS verification failed with a self-signed certificate chain | Downloaded the wheel over verified HTTPS on Ubuntu and transferred over SSH; TLS verification was not disabled |

The printer's own IPP attributes report `HP LaserJet 400 M401dn`, state 3/idle, reasons `none`, PDF support, duplex support, and `color-supported=False`. Its UUID ends in `8851fbe9a0f4`, confirming the queue identity. Registered capabilities are monochrome and duplex.

## Source corrections

- Physical jobs reject file sinks/missing device URIs. Discovery and station readiness no longer describe `/dev/null` as a usable printer.
- Physical mode cannot report completion solely because a job ID has the simulation prefix.
- Document preparation errors and empty page selections stop the job instead of printing the original/full document.
- Prepared spool files are cleaned when later submission checks fail.
- Outstanding CUPS submissions are revisited during polling after a temporary monitoring failure, without resubmission. Recovery exceptions retain their journal records and include stack traces.
- Outbox delivery runs outside the heartbeat loop so delayed status requests do not hold up heartbeats.
- Failure to write a recovery journal **after** CUPS accepted a document no longer becomes a submission failure/refund; monitoring continues and the error is logged.
- State-change logs carry job/order/queue/station identifiers, previous/current state, and execution duration. Unknown department values remain null rather than being fabricated.
- Backend refund exceptions are logged rather than silently swallowed.
- Kiosk no longer needs external Google Fonts; the launcher disables extensions and first-run setup, preserving browser sandboxing.
- Installer disables the historical SmartPrint launcher as well as the duplicate global Achuppori entry.
- Agent route tests isolate local hardware and background work; they previously failed on a real Linux host without an available printer.
- Database checker now checks order/job and captured-payment consistency, in addition to schema, uniqueness, and foreign keys.

## Actual deployment changes

Pi `.env` retains its existing unique device token and station ID `AGENT-CSE-3DD780`. Settings now include:

```dotenv
BACKEND_URL=http://172.17.3.5:3000/api
KIOSK_WEB_URL=http://172.17.3.5:3000
MOCK_CUPS=false
CUPS_SERVER=localhost
PRINTER_NAME=HP_LaserJet_400_M401dn_E9A0F4
HOST=127.0.0.1
PORT=5001
STORAGE_ROOT=./storage
LOG_DIR=./logs
```

The Pi service uses Waitress through `app/main.py`, `Restart=on-failure`, and the checked-in service hardening. CUPS history is preserved while completed job document files are not. The previous installation/configuration is backed up at `/home/achuppori/print-agent-before-20261008`; the previous CUPS configuration is `/etc/cups/printers.conf.before-smartprint`. Backups include private configuration and must remain private.

No database reset, commit, push, or rebase was performed. The existing reset/seed tools remain available; resetting this deployment would remove its current station registration and paid orders.

## Data findings requiring care

`ORD-20261008-840E85` is a historical `RELEASED` order whose job is `QUEUED`, with an already-used OTP. The checker now reports this mismatch. It is preserved for operator review; silently replaying a historical paid order could duplicate output. The historical completed order also predates correction of the discard queues, so its database completion is not proof of physical output.

The database otherwise passed schema/uniqueness/foreign-key checks. Payment keys currently select Razorpay **test** mode. Test-gateway capture must not be presented as live payment verification.

## Validation

- Backend suite: 113 tests passed before the additional exception-logging change.
- Agent suite: 43 tests passed, including new physical URI, invalid PDF, empty selection, simulation ID, recovery, and post-submission journal failure regressions.
- Flutter: clean analysis and 44 passing tests.
- Isolated LAN HTTP flow passed: frontend proxy, customer isolation, OTP release, outbound download, exclusive claim, simulated completion, status propagation, duplicate rejection, spool cleanup. This separate smoke uses fixtures and is not physical-print evidence.
- Actual Pi: authenticated heartbeat, outbound polling, local health, physical mode, real IPP queue discovery, and admin activation verified. At activation the new agent PID was 141289 with zero restarts.

Physical workflow results and timing are recorded below after the customer checkout/OTP acceptance run.

## Commands

For the current Ubuntu host, start central services only:

```bash
python3 run-server.py run
```

Do not start another runner if one already owns ports 8000/3000. From a phone on the LAN, use `http://172.17.3.5:3000/?station=AGENT-CSE-3DD780`.

On this Pi:

```bash
sudo systemctl restart print-agent
curl -f http://127.0.0.1:5001/health
systemctl show print-agent -p MainPID -p NRestarts -p Result
journalctl -u print-agent --since '-15 minutes' --no-pager
lpstat -p -d
lpstat -v
lpstat -W all -o
```

For public server setup use [DEPLOYMENT.md](DEPLOYMENT.md): production backend/worker systemd units, Nginx, HTTPS, actual DNS, SMTP, Razorpay keys and signed webhook. Then change **both** Pi URLs to that HTTPS hostname and restart the Pi agent. No public server hostname or live gateway credentials were supplied during this run, so the LAN installation is not evidence of public-production deployment.

## Remaining acceptance boundaries

Observe physical page output, stable touchscreen input, and matching customer/admin completion. Separately test paper exhaustion/jams, Pi power loss during printing, longer network outages, real gateway capture/refunds, SMTP delivery, and public HTTPS. CUPS completion is the device protocol's reported outcome, not visual confirmation of a sheet. Preserve ambiguous submissions and history for investigation; never automatically replay them. A full disk or power failure between CUPS acceptance and durable journal recording remains an operational ambiguity.
