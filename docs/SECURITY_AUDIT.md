# Security audit and LAN simulation

Audit date: 8 October 2026. Reviewed the FastAPI routes, authentication/session services, ownership checks, payment/refund state changes, uploads/storage, Pi controls, frontend authentication, launchers and deployment configuration. This is a source review with automated adversarial tests and a LAN smoke run; it is not a penetration-test certification of the deployed machines.

## Findings corrected

| Area | Finding and correction |
| --- | --- |
| Password authentication | Added bounded IP/account throttling to authentication requests. New access tokens default to one hour. Customer refresh remains supported; admin API calls now refresh expiring tokens before use. |
| Email authentication | Removed the fixed test OTP bypass. Codes are tied to signup/login purpose and serialized against concurrent verification/consumption. Expired records are pruned and the store is bounded. Student OTP login cannot issue admin tokens. |
| Account changes | Legacy password signup now requires a verified signup code and a 12-character password. Changing the account email also requires a code sent to the new email. Existing name/department editing remains supported. |
| Guest capabilities | Reject short/malformed session identifiers. Ending a customer session stores a hash in the database and prevents reuse; no longer claims revocation without enforcing it. Guest capabilities otherwise remain valid for paid-order recovery. |
| JWT parsing | Require expiry, subject and token type. Malformed user subjects return unauthorized responses rather than server errors. Refresh tokens cannot be used as access credentials. |
| Agent local API | Keypad/control endpoints require loopback clients, loopback Host, same-origin browser requests and JSON mutations. Blocks remote LAN operation, cross-site requests and DNS-rebinding Host values. Local throttling stays active in test mode and uses a lock. |
| Station identity | Reported station ID must match its device token. Supplied custom device tokens require at least 32 characters; generated tokens already use secure randomness. |
| Simulation isolation | Agent requests identify simulation mode. Production rejects simulated-agent requests. The kiosk and health response disclose simulation. The full local launcher rejects mock printing with production configuration or live Razorpay keys. |
| Error/privacy controls | Validation responses omit submitted inputs and exception context. Unexpected errors return generic responses in development as well. API responses use no-store, no-sniff and anti-framing headers. |
| Untrusted files | Keep MIME/magic validation, random filenames and path containment. Limit PDF pages, image/preview pixel counts, order item count and pages including copies. Preview failures do not return internal error details. |
| Storage configuration | Use the configured storage root rather than silently selecting/falling back to another installation's files. This checkout's existing private configuration was updated to preserve its existing upload location. |
| Hosting | Local website remains LAN-accessible on port 3000; the API binds loopback. The proxy rejects invalid lengths/chunked request framing, caps requests and disables directory listings. Public Nginx adds CSP, HTTPS transport and browser security headers. |

Earlier fixes remain: scoped customer documents/orders/payments, admin-only management, authenticated station release/claims/downloads, signed and amount-checked payment verification, real gateway refund confirmation, durable print status, and no arbitrary/default printer routing. The security regression tests exercise these boundaries along with the new controls.

Startup no longer silently promotes a customer whose email matches the configured admin email. Admin endpoints and privileged ownership overrides require an admin claim as well as the current database role, so an older customer token cannot gain admin access after promotion. Upload inspection runs outside the API event loop with two processing slots, keeping malformed-file work from blocking heartbeat handling.

The installed Python environment was scanned with `pip-audit`; the scan reported **no known vulnerabilities**. That result describes the installed versions and advisory database at scan time, not every possible future installation or vendored JavaScript/native dependency. Flutter web uses its locked package graph. Re-run dependency scans when upgrading.

The vendored PDF.js is 4.10.38. Its direct canvas renderer already disabled eval; it now explicitly disables scripting and bounds browser canvas dimensions/pixel counts. The [2026 upstream scripting advisory](https://github.com/mozilla/pdf.js/security/advisories/GHSA-hq66-cqwq-w95j) identifies affected versions starting at 5.6.83, so this vendored version is outside that stated range. Future upgrades must re-check the advisory and scripting policy.

Validation: **113 backend tests, 37 agent tests and 44 Flutter tests passed**. Flutter analysis and the release web build passed. The final LAN smoke verified the complete simulated release/status flow; the configured database check found zero schema/reference conflicts. Python compilation and Git whitespace checks passed.

## Run the automatic LAN simulation

From the repository root on Windows:

```powershell
.\.venv\Scripts\python.exe scripts/verify_station_flow.py --lan
```

On Ubuntu:

```bash
.venv/bin/python scripts/verify_station_flow.py --lan
```

The script starts isolated API, frontend proxy and mock agent processes using temporary storage/database and random ports. It uses this PC's LAN address for customer/proxy and agent-to-server traffic. The keypad remains loopback. It checks station QR routing, ownership, paid-fixture OTP release, download, exclusive claim, simulated completion, status propagation, duplicate rejection and cleanup. It stops the processes afterward and does not alter the configured database or print physical pages. Payment is a pre-captured test fixture; no gateway is called.

The LAN run passed through `192.168.1.94` on this development PC. This verifies traffic through the PC's LAN interface; it does not prove another device's firewall/Wi-Fi access. To verify a phone, use the persistent setup below. If the automatic test times out at frontend startup, check the machine's firewall; `--lan` exposes only the temporary frontend port, not the keypad or repository source.

## Persistent manual local-network testing

1. Run `python run-local.py setup`. Configure backend administrator/JWT credentials and **Razorpay test** keys. Use real SMTP for student email verification, or explicitly choose development `EMAIL_PROVIDER=mock` for console-delivered test codes. Never use mock email in production.
2. Seed the administrator as described in README. Start `python run-local.py run`, then create the department/station in admin. Put the station's generated ID/token into `print-agent/.env`.
3. Set agent `MOCK_CUPS=true`, `BACKEND_URL=http://127.0.0.1:8000/api`, `KIOSK_WEB_URL=http://YOUR_PC_IP:3000`, `HOST=127.0.0.1`. Restart the runner and register its discovered mock queue. That queue simulates printing and does not produce physical output.
4. Allow inbound TCP 3000 on your private LAN firewall. Open `http://YOUR_PC_IP:3000` from the phone. Scan the station QR, upload, check options/prices and complete Razorpay **test** checkout.
5. Enter the release code at `http://127.0.0.1:5001/kiosk` on the station PC. Confirm status on phone/admin and confirm that the kiosk explicitly says simulation. Another LAN device cannot use the keypad endpoints.

For a real Pi, run `run-server.py` on the PC and the agent on the Pi. Pi `BACKEND_URL=http://PC_IP:3000/api`, `KIOSK_WEB_URL=http://PC_IP:3000`, `MOCK_CUPS=false`. The Pi keypad stays loopback. The server/Pi production commands remain in DEPLOYMENT.md.

## Upgrade and operational limits

Run `python -m app.db.migrate` from the backend virtual environment before starting the updated services. It adds the `revoked_sessions` table without resetting existing records. If a previous installation used the old implicit root `storage/` fallback, set its absolute storage path explicitly before upgrading; do not move/delete existing uploads unintentionally. Profile email changes now require the `email_otp` field. Administrator-created customer accounts remain supported.

Use the supplied single API worker: email verification and request/OTP throttles are process-local. Logout revokes refresh tokens and guest sessions; an already issued account access token remains valid until its expiry, unless the account is disabled. Old tokens keep their original expiry. Do not rotate the JWT secret casually because it also protects stored print release codes.

Local HTTP simulation is for a trusted private network. Public deployment requires HTTPS, exact allowed origins, real SMTP/payment credentials and the Nginx proxy. The application limits files but does not claim to provide antivirus scanning or full parser isolation. A compromised trusted Pi can lie about printer status; device credentials, OS access and CUPS must be protected. Physical output, live refunds, MySQL, TLS/Nginx behavior and Pi OS hardening require checks on those machines. The previously supplied Pi SSH address was unreachable from this workstation.

References used for the review: [OWASP authentication guidance](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html), [OWASP origin/CSRF guidance](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).
