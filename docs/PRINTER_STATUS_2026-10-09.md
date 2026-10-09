# Printer discovery and availability correction — 9 October 2026

## Root causes observed on the actual Pi

- Discovery previously enumerated installed CUPS queues only. `ippfind` on the Pi found the missing HP F36EC0 at `172.17.3.7`, advertised through DNS-SD.
- The mapped HP E9A0F4 at `172.17.3.2` was unreachable, but its local CUPS queue remained in processing state. CUPS job 6 explicitly reported that the printer might not exist or was unavailable. The application translated this into BUSY and displayed printing progress.
- Order creation/release checked registration and station heartbeat but did not consistently check printer activation, freshness and physical availability.
- Kiosk progress advanced without a new printer observation. Customer progress did not display nonterminal printer errors.
- The first manual mapping from an older browser supplied only a queue name, omitting its discovered URI. Backend now obtains missing URI/IP from the authenticated station's inventory.
- Unattended `lpadmin` over localhost TCP was unauthorized. Using `/run/cups/cups.sock` permits existing local CUPS administrator authentication. No password is stored and CUPS network authorization was not relaxed.
- Pi wall time was approximately sixteen hours behind the host. Its clock was corrected; NTP was enabled but not synchronized. Campus NTP connectivity still needs checking for long-term clock synchronization.

## Resulting behavior

The Pi scans advertised IPP/IPPS printers every 30 seconds and reports installed queues plus unmapped devices. Admin chooses Add Printer; only an advertised, admin-mapped device is provisioned on that Pi. Queue names are validated, subprocess arguments are separate, and commands have timeouts. Actual ready observations activate the registration and update reported monochrome/duplex capabilities. Existing devices are not automatically reassigned or substituted.

This discovers printers advertising DNS-SD on the Pi's network. It does not scan every IP, cross VLAN discovery boundaries, or install arbitrary legacy USB drivers. Legacy printers require a CUPS queue configured on the Pi. References: [CUPS network printing](https://www.cups.org/doc/network), [ippfind](https://openprinting.github.io/cups/doc/man-ippfind.html), [lpadmin](https://www.cups.org/doc/man-lpadmin.html).

Network queue health now includes a cached TCP reachability probe (1.5 second connect timeout), CUPS status reasons, queue pause/acceptance, and device messages. A processing queue is no longer automatically evidence of an available printer. TCP reachability alone does not prove physical page output. USB health remains based on CUPS observations.

The backend uses a common freshness/availability policy for admin/public printer responses, checkout, payment initialization, printer selection and OTP release. Local release forces a fresh inventory heartbeat before backend verification. An offline rejection leaves the OTP usable. Heartbeats default to ten seconds; admin and open discovery dialogs refresh every ten seconds. Station-loss freshness remains the configured heartbeat timeout, normally 120 seconds.

Accepted CUPS jobs stay with CUPS during temporary outages. Monitoring reports offline, paper empty, held, paused, error, or delayed confirmation without resubmission. Recovery monitoring has the same callbacks. Customer and kiosk screens display the condition; kiosk fabricated progress increments were removed. Only a CUPS terminal completion produces application completion. Completion clears obsolete local error messages. Unknown outcomes require inspection rather than automatic replay/refund.

## Live verification

- Both queues exist on the Pi with physical IPP URIs, and the authenticated admin API reports READY, active and SUCCESS:
  - `PRN-EE14BC88`: E9A0F4, `ipp://172.17.3.2/ipp/print`.
  - `PRN-F92906BC`: F36EC0, `ipp://172.17.3.7/ipp/printer`.
- F36EC0 was first visible as DISCOVERED/unmapped, then manually mapped during testing, provisioned and activated following heartbeat confirmation.
- E9A0F4 became reachable again during investigation. CUPS job 6 reported terminal state 9; its saved completion event was delivered when the server restarted. No new print submission was created to recover that job. Physical paper collection was not independently observed.
- Agent has zero automatic restarts in the inspected service interval.
- No central-server printer queue was created. Source changes were deployed to `/home/achuppori/print-agent`; prior source/config was backed up in `/home/achuppori/print-agent-before-20261009`.
- Backend/frontend are running using `python3 run-server.py run`; frontend release bundle rebuilt. Refresh existing browser tabs to load it.

## Validation

119 backend tests, 52 agent tests, and 45 Flutter tests passed. Flutter analysis is clean; web release build, Python compilation, shell syntax and Git whitespace checks passed. Isolated LAN HTTP smoke passed with explicit simulated CUPS. Added regression coverage includes offline release preserving OTP, blocking payment/checkout, stale heartbeats, discovered-to-ready activation, customer offline messaging, bounded probes, mapping only advertised devices, monitoring without resubmission, and UI recovery from paused to completed.

The database checker still flags historical order `ORD-20261008-840E85`: order RELEASED, job QUEUED, OTP already consumed. This predates these changes and remains preserved for operator review; no silent reprint or payment rewrite was performed. Other schema/uniqueness/foreign-key checks found no conflicts. No reset, commit or push was performed.

## Operation

On Ubuntu:

```bash
cd /home/smartprint/Documents/SmartPrint
python3 run-server.py run
```

Use the existing running instance; do not launch a second copy on occupied ports. On the Pi:

```bash
sudo systemctl status print-agent --no-pager
journalctl -u print-agent -f
lpstat -p -v
```

Open Admin → Printers → Print Agents → Find Printers, then map an advertised device. It becomes available after the Pi configures its queue and confirms readiness. Public deployment still uses the HTTPS/server service instructions in DEPLOYMENT.md. Live payment credentials and physical paper-output acceptance remain separate from these discovery/status checks.
