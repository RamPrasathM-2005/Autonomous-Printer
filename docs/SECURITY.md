# Security architecture and deployment

## Trust boundaries

The browser supplies document bytes and requested print options, never the authoritative amount, paid state, station credential, or file location. Customer bearer tokens are random; their hashes and expiries are stored in MySQL. Every customer read/write is scoped to the session. Guessing an order/document ID does not grant access. Tokens grant access to their session, so HTTPS, XSS prevention, and kiosk session clearing remain necessary.

The database stores server-priced orders, an immutable rendered PDF hash, provider identifiers and minimal proof metadata, encrypted OTPs with independent keyed digests, hashed agent/claim tokens, a webhook inbox, refund outbox, worker heartbeat, shared rate counters, and audit events. Card numbers, CVV, banking credentials, and raw provider payment/customer payloads are not stored. Decimal rupees are converted exactly to integer paise at the gateway boundary.

Callback verification checks HMAC using the **stored** Razorpay order ID, then fetches current payment/order records over authenticated HTTPS. Full captured amount/currency/order/receipt must match. Authorized, failed, mismatched, replayed-on-another-order, or refunded payments cannot authorize a new print. Duplicate capture cannot issue another OTP/job. Webhooks require raw-body HMAC in all environments, deduplicate event IDs and payload hashes, persist before acknowledging, and are retried by a separate worker. Out-of-order failure events never roll back a later successful capture.

A payment intent is committed before a provider order POST. An ambiguous result is recovered by its unique receipt instead of issuing another POST. Refund dispatch is committed before POST and never blindly resubmitted after an uncertain result. Provider-side confirmation is required for refund completion. Local payment reconciliation verifies capture/refund state; **it is not settlement-to-bank reconciliation or a complete accounting ledger**. Reconcile Razorpay settlement reports, fees, disputes, and your bank separately.

MySQL READ COMMITTED, explicit row locks, unique constraints, idempotency keys, and a singleton worker coordinate concurrent requests. No browser override can mark an order paid or completed. Agent compromise or administrator/database access is outside the browser trust boundary; protect those credentials and hosts accordingly.

## Document handling

The temporary unpaid print flow is explicitly enabled only by `ALLOW_UNPAID_TEST_PRINTING=true`, `ENVIRONMENT=development` or `test`, and a Razorpay test key. It is a separate authorization path, not a successful payment simulation. An authenticated customer may request a test print for their own new order; rate limits apply. The backend stores `unpaidTestPrint=true` in server-owned order JSON and writes an audit event, without any payment record. Order schemas reject client attempts to supply this marker. Payment creation and test authorization take the same order lock and are mutually exclusive. Release and claim recheck the feature gate; expiry and pre-submission failure create no refund for unpaid tests. Disable the flag and restart API/worker before deployment. This intentionally grants free test printing to customers who can access the development installation; keep that installation private. No new database table is required.

Uploads are bounded by actual streamed bytes, per-session quotas, magic/type checks, maximum pages/pixels, and processing deadlines. Rendering occurs in a separate process and creates a fresh raster PDF without original active content, attachments, or document links. Paths must stay under the configured storage root. The backend and agent verify hashes; the agent rechecks its spool copy. No missing file is replaced with a fabricated document.

Original uploads expire after the configured retention period; print-ready files are cleaned after confirmed completion. Active jobs retain necessary files, and unresolved jobs require operations review. Cleanup runs in the reconciliation worker and retries failed deletion. Old files from prior demo versions outside the current storage lifecycle need an explicit retention review; they are not silently removed by migration. MySQL metadata/audit and backups require a separately defined retention policy.

A subprocess is not a full security sandbox. Deploy PDF/image processing under an isolated low-privilege account/container with no network, read-only code, memory/CPU/process/disk limits, and access only to its document workspace. Linux workers have memory/CPU limits; Windows testing does not provide a hard memory sandbox. Keep PyMuPDF, Pillow, CUPS, Python and dependencies patched. Use encrypted volumes/backups, restrictive OS permissions and a least-privilege MySQL account; encryption-at-rest is an infrastructure setting, not provided by the local launcher.

## Public deployment and live mode

1. Keep test mode until real end-to-end staging checks pass. Configure the real public HTTPS origin in backend `ALLOWED_ORIGINS` and hostname in `ALLOWED_HOSTS`. Set `ENVIRONMENT=production`, `ALLOW_UNPAID_TEST_PRINTING=false`, `ALLOW_MOCK_PRINTING=false`, agent `MOCK_CUPS=false`, independent strong secrets, and private shared storage. The local Windows launcher is not a production service supervisor.
2. Terminate TLS at a reverse proxy. Serve Flutter `build/web` and proxy `/api/` to loopback/private backend port 8000. Do not expose MySQL, storage directories, `.env`, the journal, agent port 5000, or local diagnostic files. Bound request sizes (51 MB upload maximum), connections, read timeouts and request rates at the proxy. Use HTTPS-only CSP and HSTS. Local security-header server in `scripts/serve_frontend.py` is a development reference, not a public host.
3. Supervise API, worker, and agent independently with restart-on-failure and protected environment files. Keep one reconciliation worker per database. Alert when `python -m app.ops` reports `workerHealthy=false`, pending webhook backlog, payment/refund review or stalled jobs. API health alone does not prove the worker or printer is healthy.
4. In the Razorpay dashboard configure **automatic capture**, register `https://YOUR_DOMAIN/api/payments/webhook`, and use a unique webhook secret matching `RAZORPAY_WEBHOOK_SECRET`. Subscribe to `payment.captured`, `payment.authorized`, `payment.failed`, `order.paid`, `payment.refunded`, `refund.created`, `refund.processed`, and `refund.failed` where available. Localhost cannot receive public delivery. Configure test and live separately and test real delivery/retries with the public HTTPS endpoint.
5. Complete the merchant dashboard/account/domain setup. Replace test credentials with live credentials only during a controlled cutover after outstanding test orders are reconciled. Payment records retain their gateway key ID; changing keys does not silently trust or process older-key payments. Use a separate staging database/storage for test mode. Key rotation with unsettled orders requires operator reconciliation using the appropriate old credentials.
6. Validate capture, cancellation, failed attempts, lost callbacks, webhook duplication/reordering, refund pending/processed/failure, worker/API restart, CUPS interruption and physical page output. Confirm the final price/tax/refund policy with the business. This implementation has no general accounting, tax invoice or dispute-management subsystem.

Rate limiting intentionally ignores untrusted forwarded IP headers. The included launcher disables Uvicorn proxy-header trust. A reverse proxy therefore shares the direct-peer session-creation limit unless you explicitly configure a trusted proxy and trusted real-client addressing, or enforce customer rate limits at the edge. Never trust arbitrary X-Forwarded-For from the public internet. Configure restrictive CSP for the actual Razorpay checkout domains and test all enabled payment methods; do not relax it globally to mask failures.

## Recovery and operator review

Run `python -m app.ops` from `backend` for a credential-free report. Reproduce the tested Windows Python versions with `pip install -r requirements.txt -c constraints-tested.txt` from the repository root; resolve and audit Linux-specific dependencies on the deployment host. Review the reported order IDs against Razorpay and CUPS, preserving audit evidence.

- `ORDER_CREATION_REQUIRES_REVIEW`: a create response was lost and no unique receipt match was found. Keep the same order; do not create another charge to guess what happened.
- `SUBMISSION_UNKNOWN_OPERATOR_REVIEW`: refund may or may not have reached Razorpay. Check the payment's refund list and local refund receipt before any manual refund. Never reset its state to PENDING casually.
- Partial/external refund: fulfilment is blocked; review provider history and actual output before deciding next steps.
- Stalled PRINTING / PREPARED journal: check CUPS and physical output. A crash may occur after submission but before recording its ID. Do not clear the journal or requeue automatically. If uncertain, hold for a human decision.
- Late captured payment after expiry is queued for refund rather than issuing a fresh code. Provider outages leave uncertain operations pending.

Legacy demo records are preserved with no verified capture proof and cannot release a job. Existing default demo accounts were disabled in this installation. Remove historical credentials from published repositories and rotate any secret that was ever committed; editing the current file does not erase Git history. Keep environment, logs, backups and screenshots private.

## Scope of verification

Automated tests cover hostile settings/prices, session ownership, callback proof and provider mismatches, webhook verification/deduplication, release replay/station restrictions, file tampering/traversal, lost responses, refunds, and agent crash recovery. Isolated MySQL tests exercise real concurrent transitions. Browser and genuine Razorpay test-mode checks are separate from these fake-gateway unit tests. No test suite proves perfect security. External HTTPS webhook delivery, physical printer behavior, native mobile checkout, live charges, settlements and infrastructure isolation must be validated in their actual deployment environments.

## Provider references

- [Mandatory server-side signature verification](https://razorpay.com/docs/payments/payment-gateway/react-native-integration/standard/integration-steps-android/)
- [Webhook signature verification and event deduplication](https://razorpay.com/docs/webhooks/validate-test/)
- [Fetch payment details](https://razorpay.com/docs/api/payments/fetch-with-id/)
- [Refund creation](https://razorpay.com/docs/api/refunds/create-normal/)

## Local validation recorded 2026-09-30

- Backend suite: 54 passed; isolated MySQL concurrency suite: 4 passed; agent suite: 16 passed; Flutter widget test: passed.
- Genuine Razorpay test checkout: upload, server-priced INR 2 order, mock-bank success, provider capture verification, OTP, browser refresh recovery, one release/claim, and one simulated completion. No physical printing or live charge occurred.
- Flutter static analysis: no issues; release web build succeeded.
- Signed local webhook injection against the real MySQL-backed API: accepted and processed by the worker, duplicate acknowledged, forged signature rejected. This does not test external Razorpay delivery to public HTTPS.
- Python installed-dependency audit after replacing python-jose/ecdsa with PyJWT and upgrading pip: no known vulnerabilities reported. Audits are time-specific, not a security guarantee.

Web checkout is implemented; native mobile checkout and bank settlement reconciliation remain outside this verified path. See the deployment steps above before using live credentials.
