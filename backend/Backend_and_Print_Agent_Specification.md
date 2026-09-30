> Historical design document. The implemented security/payment contract is documented in [docs/SECURITY.md](../docs/SECURITY.md) and supersedes this specification.

# Smart Self-Service Printing Platform
## FastAPI Backend + Ubuntu Flask Print Agent
### Self-Hosted Single-Linux-Machine Architecture

---

# 1. Purpose

This document defines the complete backend and print-agent architecture for the Smart Self-Service Printing Platform.

The system uses:

- **React Native** as the mobile frontend.
- **FastAPI** as the central backend.
- **MySQL** as the relational database.
- **Local Linux filesystem/HDD** for storing original uploaded files.
- **Flask** as the local print agent.
- **CUPS** for communication with the physical printer.
- **Razorpay** for payment processing.

The system is intentionally self-hosted.

## Services NOT used

```text
Firebase                 ❌
Firestore                ❌
Firebase Authentication  ❌
Cloudinary               ❌
Amazon S3                ❌
Cloud Run                ❌
Firebase Hosting         ❌
Web frontend hosting     ❌
```

The React Native application runs on the user's mobile device. It is not hosted by this server.

---

# 2. High-Level Architecture

```text
                         USER MOBILE
                    ┌──────────────────┐
                    │  React Native    │
                    │      App         │
                    └────────┬─────────┘
                             │
                             │ HTTPS REST API
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    UBUNTU / LINUX SERVER                     │
│                                                              │
│  ┌───────────────┐                                           │
│  │    Nginx      │                                           │
│  │ Reverse Proxy │                                           │
│  └───────┬───────┘                                           │
│          │                                                   │
│          ▼                                                   │
│  ┌────────────────────┐                                     │
│  │      FastAPI       │                                     │
│  │   Main Backend     │                                     │
│  └──────┬───────┬─────┘                                     │
│         │       │                                           │
│         │       ├─────────────────────┐                     │
│         │       │                     │                     │
│         ▼       ▼                     ▼                     │
│   ┌─────────┐ ┌────────────────┐ ┌─────────────────┐        │
│   │  MySQL  │ │ Local Storage  │ │  Flask Agent    │        │
│   │ Database│ │ Linux HDD/SSD  │ │ Local Printer   │        │
│   └─────────┘ └────────────────┘ └────────┬────────┘        │
│                                           │                 │
│                                           ▼                 │
│                                         CUPS                │
│                                           │                 │
└───────────────────────────────────────────┼─────────────────┘
                                            │
                                            ▼
                                         PRINTER
```

---

# 3. Responsibility of Each Component

## 3.1 React Native App

The mobile app is responsible for:

```text
Scan station QR
Login
Select document
Upload document
Select print settings
Create order
Make payment
View order status
Display OTP
View order history
```

The mobile application communicates only with the FastAPI backend for application data.

It does NOT:

```text
Access MySQL
Access Linux filesystem
Access CUPS
Access Flask directly
Calculate final price
Mark payments as successful
Change print-job state
```

---

# 4. FastAPI Backend

FastAPI is the central source of truth.

It is responsible for:

```text
Authentication
Authorization
User management
Print-server management
Document upload
Document validation
Local file storage
Document metadata
Pricing
Orders
Payments
Razorpay webhook verification
OTP generation
OTP verification
Print-job lifecycle
Refund handling
Idempotency
Cleanup
Agent authentication
Agent coordination
```

FastAPI does NOT directly communicate with the physical printer.

The physical printer is controlled through:

```text
FastAPI
   ↓
Flask Agent
   ↓
CUPS
   ↓
Printer
```

---

# 5. MySQL Database

MySQL stores structured application data.

It does NOT store the uploaded PDF/image binary by default.

The database stores:

```text
Users
Authentication information
Documents metadata
Storage paths
Print servers
Printers
Orders
Payments
Print jobs
OTP records
Refunds
Idempotency records
Audit logs
```

---

# 6. Local File Storage

Uploaded files are stored directly on the Linux machine.

Recommended root:

```text
/var/lib/printplatform/storage/
```

Directory structure:

```text
/var/lib/printplatform/storage/
│
├── documents/
│   ├── 1/
│   │   ├── 8f4c...pdf
│   │   └── a912...jpg
│   │
│   ├── 2/
│   │   └── 7bc1...pdf
│   │
│   └── ...
│
├── temp/
│
└── quarantine/
```

## Important

MySQL stores the relative storage key:

```text
documents/1/8f4c1234.pdf
```

The application configuration contains:

```env
STORAGE_ROOT=/var/lib/printplatform/storage
```

The actual file therefore becomes:

```text
/var/lib/printplatform/storage/documents/1/8f4c1234.pdf
```

Do not expose this filesystem path directly to the mobile application.

---

# 7. Why Store a Relative Storage Key?

Do not store:

```text
/var/lib/printplatform/storage/documents/1/file.pdf
```

as the primary database value.

Prefer:

```text
documents/1/file.pdf
```

This allows the storage root to be changed later.

For example:

```env
STORAGE_ROOT=/mnt/print-storage
```

without modifying every database record.

---

# 8. File Storage Rules

The backend must:

1. Generate a unique internal filename.
2. Never trust the original filename as the physical filename.
3. Validate file size.
4. Validate MIME type.
5. Validate extension.
6. Validate actual file content.
7. Store the file outside the application source directory.
8. Store the file atomically.
9. Store the checksum.
10. Store the storage key in MySQL.
11. Prevent path traversal.
12. Never allow the client to choose an arbitrary filesystem path.

Example:

```text
Original filename:
Semester Project.pdf

Stored filename:
b7f4d9c1-8c1e-4e7f-a2c1.pdf

Storage key:
documents/42/b7f4d9c1-8c1e-4e7f-a2c1.pdf
```

---

# 9. Supported Files

Initial supported formats:

```text
PDF
JPG / JPEG
PNG
```

Recommended MIME validation:

```text
application/pdf
image/jpeg
image/png
```

The server must not trust only:

```text
file.extension
Content-Type header
frontend-provided file size
```

The actual file must be inspected.

---

# 10. Document Upload Workflow

```text
React Native
     │
     │ POST /api/documents/upload
     │ multipart/form-data
     ▼
FastAPI
     │
     ├── Authenticate user
     ├── Validate file size
     ├── Validate extension
     ├── Validate MIME
     ├── Validate actual file
     ├── Generate document ID
     ├── Generate safe filename
     │
     ▼
Temporary file
     │
     ├── Calculate SHA-256
     ├── Determine page count
     ├── Generate preview information if required
     │
     ▼
Final storage location
     │
     ▼
MySQL transaction
     │
     └── Insert document metadata
```

The API should return:

```json
{
  "documentId": "doc_01JXYZ",
  "originalFilename": "Semester Project.pdf",
  "pages": 10,
  "size": 5242880,
  "status": "ACTIVE"
}
```

---

# 11. Document Database Table

Recommended fields:

```text
documents
------------------------------------------------
id
user_id
original_filename
stored_filename
storage_key
mime_type
file_size
sha256
page_count
status
created_at
expires_at
deleted_at
```

Example:

```text
id:
doc_01JXYZ

user_id:
42

original_filename:
Semester Project.pdf

stored_filename:
b7f4d9c1.pdf

storage_key:
documents/42/b7f4d9c1.pdf

mime_type:
application/pdf

file_size:
5242880

sha256:
...

page_count:
10

status:
ACTIVE
```

---

# 12. Authentication

Firebase Authentication is not used.

Authentication is implemented by FastAPI.

Recommended architecture:

```text
React Native
      │
      │ Login
      ▼
FastAPI
      │
      ▼
MySQL
      │
      ├── Verify user
      └── Verify password
      │
      ▼
Access Token + Refresh Token
```

Passwords must never be stored in plaintext.

Use a password hashing algorithm such as:

```text
Argon2id
```

or another modern password hashing implementation.

---

# 13. JWT Authentication

Use:

```text
Access Token
Refresh Token
```

Recommended behavior:

```text
Access Token
short lifetime

Refresh Token
long lifetime
stored securely
revocable
```

The mobile application sends:

```http
Authorization: Bearer <ACCESS_TOKEN>
```

FastAPI validates the token before protected operations.

---

# 14. User Roles

Recommended roles:

```text
USER
ADMIN
```

Optionally:

```text
SUPER_ADMIN
```

Authorization must be performed server-side.

The mobile application must never decide whether a user is an administrator.

---

# 15. Print Server / Agent Identity

Even though the system currently uses one Linux machine, keep the print-server concept.

Example:

```text
print_servers
----------------------------
id
name
location
device_token_hash
status
last_heartbeat
created_at
updated_at
```

Example:

```text
PRINT-SERVER-001
Main Block Print Server
CSE Block
```

This allows multiple printers or future print servers to be supported later.

---

# 16. Agent Authentication

The Flask Agent authenticates to FastAPI using a device token.

Request:

```http
Authorization: Bearer <DEVICE_TOKEN>
```

FastAPI stores only a hash of the device token.

Reject:

```text
Missing token
Malformed token
Invalid token
Revoked token
Disabled print server
```

Return:

```http
401 Unauthorized
```

Never trust:

```json
{
  "printServerId": "PRINT-SERVER-001"
}
```

from the request body as the source of identity.

The authenticated server identity must come from the token.

---

# 17. Flask Print Agent

The Flask application is a local service running on Ubuntu.

Its responsibilities are limited to printer operations:

```text
Heartbeat
Poll print jobs
Release jobs
Read local document
Validate local document
Send document to CUPS
Monitor CUPS
Report status
Report failures
```

The Flask agent does NOT:

```text
Calculate price
Process payment
Create refunds
Modify user accounts
Directly modify MySQL
Decide business state
```

FastAPI remains the source of truth.

---

# 18. Flask Agent Architecture

```text
Flask Agent
│
├── /health
├── /local/status
├── job polling logic
├── document access
├── CUPS service
├── printer monitoring
├── heartbeat worker
└── status reporting client
```

The Flask agent communicates with FastAPI through REST APIs.

---

# 19. CUPS

CUPS controls the actual printer.

```text
Flask
  ↓
CUPS
  ↓
Printer
```

Flask should not directly implement printer-driver communication.

CUPS handles:

```text
Printer discovery
Printer queues
Print commands
Printer state
CUPS job IDs
Driver communication
```

---

# 20. Complete Printing Workflow

The complete workflow is:

```text
1. User scans station QR
        ↓
2. Mobile app asks FastAPI for station status
        ↓
3. User logs in
        ↓
4. User selects PDF/image
        ↓
5. FastAPI receives file
        ↓
6. FastAPI validates file
        ↓
7. File stored on Linux HDD
        ↓
8. File metadata stored in MySQL
        ↓
9. User selects print settings
        ↓
10. FastAPI validates settings
        ↓
11. FastAPI calculates price
        ↓
12. FastAPI creates order
        ↓
13. Mobile app starts Razorpay payment
        ↓
14. Razorpay processes payment
        ↓
15. Razorpay calls FastAPI webhook
        ↓
16. FastAPI verifies webhook
        ↓
17. FastAPI marks payment successful
        ↓
18. FastAPI creates exactly one print job
        ↓
19. FastAPI generates OTP
        ↓
20. Order = WAITING_FOR_OTP
        ↓
21. Flask Agent polls FastAPI
        ↓
22. Agent sees job
        ↓
23. User enters OTP at print station
        ↓
24. Flask sends OTP to FastAPI
        ↓
25. FastAPI verifies OTP
        ↓
26. Job = RELEASED
        ↓
27. Flask receives permission
        ↓
28. Flask reads the local file
        ↓
29. Flask validates the file
        ↓
30. Flask submits file to CUPS
        ↓
31. CUPS sends job to printer
        ↓
32. Flask reports PRINTING
        ↓
33. Printer completes
        ↓
34. Flask reports COMPLETED
        ↓
35. FastAPI marks order COMPLETED
        ↓
36. Cleanup policy executes
```

---

# 21. Order State Machine

```text
CREATED
   │
   ▼
PAID
   │
   ▼
JOB_QUEUED
   │
   ▼
WAITING_FOR_OTP
   │
   ▼
RELEASED
   │
   ▼
PRINTING
   │
   ├──────────────► COMPLETED
   │
   └──────────────► FAILED
                         │
                         ▼
                       REFUND
```

OTP expiration:

```text
WAITING_FOR_OTP
       │
       ▼
    EXPIRED
       │
       ▼
    REFUND
```

Only explicitly allowed state transitions are permitted.

---

# 22. Print Job State Machine

```text
QUEUED
  │
  ▼
RELEASED
  │
  ▼
PRINTING
  │
  ├──────────► COMPLETED
  │
  └──────────► FAILED
```

For retry:

```text
FAILED
  │
  ├── retry available ──► QUEUED
  │
  └── retry exhausted ──► FINAL FAILED
                              │
                              ▼
                           REFUND
```

---

# 23. Order Creation

Endpoint:

```http
POST /api/orders
```

FastAPI must:

```text
1. Authenticate user
2. Validate document ownership
3. Verify document exists
4. Verify document is ACTIVE
5. Verify document has not expired
6. Verify print server is available
7. Validate print settings
8. Validate page range
9. Calculate price
10. Create order
11. Return order details
```

The client-provided price is never trusted.

---

# 24. Pricing

The backend is the only authority for price.

Example:

```text
pages × copies × rate + fee
```

Example:

```text
5 pages
2 copies
₹2.50/page
₹1 fee

5 × 2 × ₹2.50 + ₹1
= ₹26
```

The React Native application only displays the backend result.

---

# 25. Page Range Validation

Supported:

```text
1-5
1-3,7-9
1,3,5-7
```

Duplicate pages should be removed.

Example:

```text
1-3,3-5
```

becomes:

```text
1,2,3,4,5
```

Invalid:

```text
0
-1
5-2
1-100 when document has 10 pages
```

Return:

```text
400 INVALID_PAGE_RANGE
```

---

# 26. Payment Workflow

Payment provider:

```text
Razorpay
```

Flow:

```text
React Native
      │
      │ POST /api/payments/create
      ▼
FastAPI
      │
      ▼
Razorpay
      │
      ▼
Razorpay Checkout
```

The mobile app must never mark the order as paid.

---

# 27. Razorpay Webhook

Endpoint:

```http
POST /api/payments/webhook
```

The backend must:

```text
1. Read raw request body
2. Verify Razorpay signature
3. Identify payment
4. Verify payment amount
5. Verify associated order
6. Check idempotency
7. Mark payment captured
8. Create exactly one print job
9. Generate OTP
10. Move order to WAITING_FOR_OTP
```

The frontend callback is NOT the final payment authority.

The webhook is authoritative.

---

# 28. Payment Idempotency

Webhooks can be delivered more than once.

Example:

```text
Webhook #1
    ↓
Payment processed
    ↓
Job created

Webhook #2
    ↓
Already processed
    ↓
Do nothing
```

Database constraints and transactions must guarantee:

```text
One successful payment
One successful payment transition
One print job
```

---

# 29. OTP

Generate a cryptographically secure six-digit OTP.

Example:

```text
483921
```

Never use predictable random generation.

Store a secure representation:

```text
otp_hash
expires_at
attempt_count
used_at
active
```

The plaintext OTP should not be logged.

---

# 30. OTP Lifecycle

```text
Payment successful
       ↓
Generate OTP
       ↓
WAITING_FOR_OTP
       ↓
User sees OTP in mobile app
       ↓
User enters OTP at station
       ↓
Flask Agent → FastAPI
       ↓
Verify OTP
       ↓
Mark OTP consumed
       ↓
Job = RELEASED
```

---

# 31. OTP Verification Endpoint

```http
POST /api/agent/release
```

Request:

```json
{
  "otp": "483921"
}
```

FastAPI must verify:

```text
1. Agent authentication
2. Authenticated print server identity
3. Active job
4. Correct print server
5. Order status
6. OTP expiry
7. OTP active state
8. OTP used state
9. Attempt count
10. OTP hash
```

All state changes must happen transactionally.

---

# 32. OTP Race Condition Protection

Inside the database transaction, re-check:

```text
order.status == WAITING_FOR_OTP
otp.active == true
otp.used_at IS NULL
otp.expires_at > NOW()
attempt_count < MAX_OTP_ATTEMPTS
```

Then:

```text
otp.used_at = NOW()
otp.active = false
job.status = RELEASED
order.status = RELEASED
```

This prevents two simultaneous requests from releasing the same job.

---

# 33. OTP Lockout

Example:

```text
Wrong OTP
   ↓
attempt_count + 1
   ↓
5 attempts
   ↓
Temporarily locked
   ↓
429 TOO_MANY_ATTEMPTS
```

A successful verification consumes the OTP.

It cannot be reused.

---

# 34. Agent Job Polling

Endpoint:

```http
GET /api/agent/jobs
```

Response:

```json
[
  {
    "jobId": "job_001",
    "orderId": "ORD-20260929-0001",
    "storageKey": "documents/42/b7f4d9c1.pdf",
    "settings": {
      "copies": 2,
      "pageRange": "1-5",
      "colour": false,
      "sides": "two-sided-long-edge",
      "paperSize": "A4",
      "orientation": "portrait"
    }
  }
]
```

Do NOT return:

```text
User password
Access token
Agent device token
Razorpay secret
OTP
Database password
```

The storage key is an internal reference and must only be returned to an authenticated agent.

---

# 35. Agent File Access

The agent receives:

```text
storageKey:
documents/42/b7f4d9c1.pdf
```

It resolves:

```text
STORAGE_ROOT
+
storageKey
```

into:

```text
/var/lib/printplatform/storage/documents/42/b7f4d9c1.pdf
```

The agent must verify that the resolved path remains inside `STORAGE_ROOT`.

This prevents path traversal.

---

# 36. Do Not Send the File Through the Network

Because FastAPI and Flask run on the same Linux machine, the preferred flow is:

```text
FastAPI
   ↓
Database job metadata
   ↓
Flask Agent
   ↓
Local filesystem
   ↓
PDF
   ↓
CUPS
```

Do NOT unnecessarily do:

```text
HDD
 ↓
FastAPI
 ↓
HTTP download
 ↓
Flask
 ↓
HDD
```

The local filesystem is already shared.

---

# 37. Printing With CUPS

Flask uses CUPS to submit the print job.

Conceptually:

```text
Flask
   ↓
Read local document
   ↓
Build print options
   ↓
Submit to CUPS
   ↓
Receive cupsJobId
   ↓
Report PRINTING
```

Print options are derived from the validated order settings.

Example:

```text
copies
page range
colour
duplex
paper size
orientation
```

The Flask agent must not modify business-level order pricing.

---

# 38. CUPS Job Monitoring

Flask records:

```text
cups_job_id
```

Then monitors the CUPS job.

Possible local states:

```text
QUEUED
PROCESSING
COMPLETED
CANCELED
ABORTED
```

Map those states to the backend job state where appropriate.

---

# 39. Status Reporting

Endpoint:

```http
POST /api/agent/jobs/{jobId}/status
```

Example:

```json
{
  "status": "PRINTING",
  "cupsJobId": "123"
}
```

Completion:

```json
{
  "status": "COMPLETED"
}
```

Failure:

```json
{
  "status": "FAILED",
  "errorCode": "PRINTER_UNAVAILABLE",
  "message": "Printer unavailable"
}
```

FastAPI validates whether the requested transition is legal.

The agent cannot arbitrarily set:

```text
REFUNDED
PAID
```

---

# 40. Duplicate Polling Protection

The same job may appear repeatedly:

```text
Poll 1 → job_001
Poll 2 → job_001
Poll 3 → job_001
```

The Flask agent maintains an in-memory processing set.

The backend also protects the job state with MySQL transactions and constraints.

Only one physical print submission should occur.

---

# 41. Heartbeat

Endpoint:

```http
POST /api/agent/heartbeat
```

Example:

```json
{
  "printerState": "READY",
  "paperState": "AVAILABLE"
}
```

FastAPI records:

```text
last_heartbeat
printer_state
paper_state
server_status
```

---

# 42. Offline Detection

If:

```text
last_heartbeat < current_time - configured_timeout
```

then:

```text
print_server.status = OFFLINE
```

Orders should not be created for an unavailable print server.

---

# 43. Refund State Machine

Refund handling must be idempotent.

```text
NOT_REQUIRED
     │
     ▼
PENDING
     │
     ▼
PROCESSING
     │
     ▼
COMPLETED
```

Failure:

```text
PROCESSING
     │
     ▼
FAILED
     │
     ▼
Recovery
```

Store:

```text
razorpay_refund_id
refund_status
refund_requested_at
refund_completed_at
```

Never blindly create a second refund.

---

# 44. Refund Recovery

Example:

```text
Print failed
    ↓
Refund PENDING
    ↓
Refund request sent
    ↓
Razorpay creates refund
    ↓
Server crashes
    ↓
Server restarts
    ↓
Recovery checks existing refund
    ↓
Do not create duplicate refund
```

---

# 45. File Cleanup

A document should not be deleted while it is still needed by an active print job.

Recommended lifecycle:

```text
UPLOADED
   ↓
ACTIVE
   ↓
PRINTING
   ↓
COMPLETED
   ↓
CLEANUP_PENDING
   ↓
DELETED
```

For failed/expired jobs:

```text
EXPIRED
   ↓
CLEANUP_PENDING
   ↓
DELETED
```

Before physical deletion, verify:

```text
No active order references the document
No active print job references the document
```

Then:

```text
Delete physical file
Update MySQL
```

---

# 46. Storage Cleanup Worker

The backend should periodically find:

```text
CLEANUP_PENDING
```

documents.

For each document:

```text
1. Verify no active reference
2. Verify file exists
3. Delete physical file
4. Mark document deleted
5. Record cleanup time
```

If deletion fails:

```text
Keep the record
Retry later
Log the failure
```

Never claim deletion succeeded if it did not.

---

# 47. Database Transactions

Use MySQL transactions for critical operations:

```text
Payment success
Order state changes
OTP release
Print job creation
Refund state changes
Cleanup state changes
```

Use row locking where concurrent requests could modify the same order/job.

---

# 48. Idempotency

The backend must assume:

```text
Every request can be repeated.
Every webhook can be repeated.
Every network request can fail.
The server can restart.
The agent can restart.
The printer can fail.
Two requests can arrive simultaneously.
```

Critical operations therefore require idempotency.

Recommended table:

```text
idempotency_keys
----------------------------
id
key
operation
user_id
request_hash
response_code
response_body
created_at
expires_at
```

---

# 49. API Error Format

All API errors should follow:

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable message"
}
```

Examples:

```text
UNAUTHENTICATED
INVALID_TOKEN
FORBIDDEN
NOT_FOUND
FILE_TOO_LARGE
UNSUPPORTED_TYPE
INVALID_FILE
INVALID_PAGE_RANGE
INVALID_STATE
INVALID_OTP
OTP_EXPIRED
TOO_MANY_ATTEMPTS
PRINT_SERVER_OFFLINE
INVALID_SIGNATURE
PAYMENT_AMOUNT_MISMATCH
REFUND_FAILED
```

---

# 50. API Endpoint Summary

## Authentication

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
```

## Print Servers

```text
GET /api/print-servers
GET /api/print-servers/{id}
```

## Documents

```text
POST   /api/documents/upload
GET    /api/documents/{id}
DELETE /api/documents/{id}
```

## Orders

```text
POST /api/orders
GET  /api/orders
GET  /api/orders/{id}
GET  /api/orders/{id}/otp
```

## Payments

```text
POST /api/payments/create
POST /api/payments/webhook
```

## Agent

```text
POST /api/agent/heartbeat
GET  /api/agent/jobs
POST /api/agent/release
POST /api/agent/jobs/{id}/status
```

## Health

```text
GET /health
```

## Maintenance

```text
POST /api/maintenance/cleanup
```

Maintenance endpoints must be strongly authenticated.

---

# 51. Recommended FastAPI Project Structure

```text
backend/
│
├── app/
│   ├── main.py
│   │
│   ├── config/
│   │   ├── settings.py
│   │   ├── database.py
│   │   └── security.py
│   │
│   ├── db/
│   │   ├── base.py
│   │   ├── session.py
│   │   └── models/
│   │       ├── user.py
│   │       ├── refresh_token.py
│   │       ├── document.py
│   │       ├── print_server.py
│   │       ├── printer.py
│   │       ├── order.py
│   │       ├── payment.py
│   │       ├── print_job.py
│   │       ├── otp.py
│   │       ├── refund.py
│   │       ├── idempotency.py
│   │       └── audit_log.py
│   │
│   ├── api/
│   │   ├── dependencies.py
│   │   └── routes/
│   │       ├── auth.py
│   │       ├── documents.py
│   │       ├── print_servers.py
│   │       ├── orders.py
│   │       ├── payments.py
│   │       ├── agent.py
│   │       └── maintenance.py
│   │
│   ├── schemas/
│   │   ├── auth.py
│   │   ├── document.py
│   │   ├── print_server.py
│   │   ├── order.py
│   │   ├── payment.py
│   │   ├── agent.py
│   │   └── common.py
│   │
│   ├── services/
│   │   ├── auth_service.py
│   │   ├── storage_service.py
│   │   ├── document_service.py
│   │   ├── pricing_service.py
│   │   ├── order_service.py
│   │   ├── payment_service.py
│   │   ├── otp_service.py
│   │   ├── job_service.py
│   │   ├── refund_service.py
│   │   └── cleanup_service.py
│   │
│   ├── middleware/
│   │   ├── auth.py
│   │   ├── agent_auth.py
│   │   └── admin_auth.py
│   │
│   ├── utils/
│   │   ├── state_machine.py
│   │   ├── crypto.py
│   │   ├── file_security.py
│   │   ├── errors.py
│   │   └── time.py
│   │
│   └── workers/
│       └── maintenance.py
│
├── migrations/
├── tests/
├── requirements.txt
├── .env.example
├── .gitignore
└── README.md
```

---

# 52. Recommended Flask Print Agent Structure

```text
print-agent/
│
├── app/
│   ├── __init__.py
│   ├── main.py
│   │
│   ├── config.py
│   │
│   ├── routes/
│   │   ├── health.py
│   │   └── local.py
│   │
│   ├── services/
│   │   ├── backend_client.py
│   │   ├── job_poller.py
│   │   ├── file_service.py
│   │   ├── print_service.py
│   │   ├── cups_service.py
│   │   └── printer_monitor.py
│   │
│   ├── security/
│   │   └── agent_auth.py
│   │
│   └── utils/
│       ├── logging.py
│       └── errors.py
│
├── tests/
├── requirements.txt
├── .env.example
└── README.md
```

---

# 53. FastAPI Environment Variables

```env
APP_NAME=PrintPlatform
ENVIRONMENT=production
HOST=127.0.0.1
PORT=8000

DATABASE_URL=mysql+pymysql://print_user:CHANGE_ME@127.0.0.1:3306/print_platform

JWT_SECRET_KEY=CHANGE_ME
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=15
JWT_REFRESH_TOKEN_EXPIRE_DAYS=30

STORAGE_ROOT=/var/lib/printplatform/storage

MAX_UPLOAD_MB=50

OTP_TTL_MINUTES=30
MAX_OTP_ATTEMPTS=5

MAX_PRINT_RETRIES=2

RAZORPAY_KEY_ID=CHANGE_ME
RAZORPAY_KEY_SECRET=CHANGE_ME
RAZORPAY_WEBHOOK_SECRET=CHANGE_ME

AGENT_REQUEST_TIMEOUT_SECONDS=10
HEARTBEAT_TIMEOUT_SECONDS=60
```

---

# 54. Flask Agent Environment Variables

```env
AGENT_ID=PRINT-SERVER-001

BACKEND_URL=http://127.0.0.1:8000/api

AGENT_TOKEN=CHANGE_ME

STORAGE_ROOT=/var/lib/printplatform/storage

POLL_INTERVAL_SECONDS=3

HEARTBEAT_INTERVAL_SECONDS=15

CUPS_SERVER=localhost

PRINTER_NAME=YOUR_PRINTER_NAME
```

If Nginx/HTTPS is used for external access, the backend can still use localhost communication for the local agent.

---

# 55. Linux Directory Layout

Recommended:

```text
/var/lib/printplatform/
│
├── storage/
│   ├── documents/
│   ├── temp/
│   └── quarantine/
│
└── agent/
```

Application code:

```text
/opt/printplatform/
│
├── backend/
└── print-agent/
```

Logs:

```text
/var/log/printplatform/
```

Configuration/secrets:

```text
/etc/printplatform/
```

Example:

```text
/etc/printplatform/backend.env
/etc/printplatform/agent.env
```

Do not store production secrets inside Git.

---

# 56. Linux Services

Use systemd so the services automatically restart.

Recommended services:

```text
printplatform-backend.service
printplatform-agent.service
```

Flow:

```text
systemd
  │
  ├── FastAPI
  │
  └── Flask Agent
```

MySQL and CUPS can also run as their standard Linux services.

---

# 57. Production Process Architecture

```text
systemd
   │
   ├── nginx
   │
   ├── mysql
   │
   ├── cups
   │
   ├── printplatform-backend
   │
   └── printplatform-agent
```

FastAPI:

```text
Uvicorn / Gunicorn-compatible ASGI deployment
```

Flask:

```text
Production WSGI server
```

Do not use Flask's development server in production.

---

# 58. Nginx Role

Nginx is used only for backend API access.

Example:

```text
https://print.example.com/api/*
              │
              ▼
            Nginx
              │
              ▼
         FastAPI :8000
```

The React Native application itself is not hosted by Nginx.

---

# 59. Security Rules

Never expose:

```text
MySQL port 3306
CUPS port 631
Flask Agent port
Storage directory
.env files
```

to the public internet unless there is a specific secured requirement.

Public access should normally be:

```text
HTTPS → Nginx → FastAPI
```

Local communication:

```text
FastAPI → MySQL
FastAPI → Flask
Flask → CUPS
```

should stay on localhost/private interfaces.

---

# 60. File Security

The storage directory must not be directly browsable from the internet.

Do NOT configure:

```text
Nginx → /var/lib/printplatform/storage
```

as a public static directory.

Files are accessed internally by the backend/agent.

---

# 61. CORS

Because the frontend is React Native, browser CORS requirements are different from a web frontend.

The mobile application does not require browser CORS in the same way.

Still configure the backend carefully if administrative browser clients are introduced later.

Do not blindly use:

```text
Access-Control-Allow-Origin: *
```

for authenticated browser applications.

---

# 62. Logging

Log:

```text
Request ID
User ID where appropriate
Order ID
Document ID
Job ID
Agent ID
CUPS Job ID
State transitions
Errors
```

Never log:

```text
Password
JWT
Refresh token
Agent token
OTP
Razorpay secret
Database password
Webhook secret
```

---

# 63. Audit Logging

Important operations should create audit records:

```text
LOGIN
DOCUMENT_UPLOAD
DOCUMENT_DELETE
ORDER_CREATED
PAYMENT_CREATED
PAYMENT_CAPTURED
OTP_GENERATED
OTP_VERIFIED
PRINT_STARTED
PRINT_COMPLETED
PRINT_FAILED
REFUND_CREATED
REFUND_COMPLETED
```

Recommended fields:

```text
id
user_id
actor_type
action
entity_type
entity_id
metadata
created_at
```

---

# 64. Backup Strategy

Because files are stored on the Linux machine, backups must cover both:

```text
MySQL
+
/var/lib/printplatform/storage/
```

A MySQL backup alone does not restore the original PDFs/images.

Recommended backup categories:

```text
Database backup
File storage backup
Configuration backup
```

Do not treat a single HDD as a backup.

---

# 65. Testing Requirements

## Authentication

```text
[ ] Register
[ ] Login
[ ] Wrong password
[ ] Expired access token
[ ] Refresh token
[ ] Logout
[ ] Revoked refresh token
[ ] Unauthorized endpoint
```

## Documents

```text
[ ] Valid PDF
[ ] Valid JPG
[ ] Valid PNG
[ ] Unsupported file
[ ] Oversized file
[ ] Corrupt PDF
[ ] Invalid MIME
[ ] Path traversal attempt
[ ] Duplicate upload
[ ] Storage failure
[ ] Database failure
```

## Orders

```text
[ ] Correct price
[ ] Invalid page range
[ ] Expired document
[ ] Wrong document owner
[ ] Offline print server
[ ] Duplicate order request
```

## Payments

```text
[ ] Razorpay order creation
[ ] Payment success
[ ] Payment failure
[ ] Invalid webhook
[ ] Duplicate webhook
[ ] Wrong amount
[ ] Refund
[ ] Duplicate refund protection
```

## OTP

```text
[ ] Correct OTP
[ ] Wrong OTP
[ ] Expired OTP
[ ] Used OTP
[ ] Maximum attempts
[ ] Duplicate release
[ ] Concurrent release
```

## Printing

```text
[ ] Agent heartbeat
[ ] Agent authentication
[ ] Job polling
[ ] Duplicate polling
[ ] Job release
[ ] Local file lookup
[ ] File missing
[ ] CUPS submission
[ ] Printing
[ ] Completion
[ ] Printer failure
[ ] Retry
[ ] Final failure
[ ] Refund
```

---

# 66. Complete End-to-End Example

User selects:

```text
project.pdf
```

The mobile app sends:

```text
POST /api/documents/upload
```

FastAPI:

```text
Authenticate
    ↓
Validate
    ↓
Store file
    ↓
Save MySQL metadata
```

Storage:

```text
/var/lib/printplatform/storage/documents/42/a83d91.pdf
```

MySQL:

```text
document_id = doc_001
storage_key = documents/42/a83d91.pdf
```

User selects:

```text
Copies = 2
Pages = 1-5
Colour = B/W
Sides = Duplex
Paper = A4
```

FastAPI creates:

```text
ORDER_CREATED
```

Razorpay payment succeeds.

Razorpay webhook reaches:

```text
POST /api/payments/webhook
```

FastAPI:

```text
Verify signature
    ↓
Verify amount
    ↓
Mark PAID
    ↓
Create job
    ↓
Generate OTP
    ↓
WAITING_FOR_OTP
```

Flask polls:

```text
GET /api/agent/jobs
```

Agent sees:

```text
job_001
storageKey = documents/42/a83d91.pdf
```

User enters OTP at the station.

Flask sends:

```text
POST /api/agent/release
```

FastAPI verifies OTP.

Then:

```text
JOB = RELEASED
```

Flask reads:

```text
/var/lib/printplatform/storage/documents/42/a83d91.pdf
```

Flask sends it to:

```text
CUPS
```

CUPS sends it to:

```text
Printer
```

Flask reports:

```text
PRINTING
```

Then:

```text
COMPLETED
```

FastAPI updates MySQL.

Finally, cleanup can remove the physical file according to the configured retention policy.

---

# 67. Final Architecture

```text
                     ┌─────────────────────┐
                     │   React Native App  │
                     │      Android/iOS    │
                     └──────────┬──────────┘
                                │
                              HTTPS
                                │
                                ▼
                     ┌─────────────────────┐
                     │       Nginx         │
                     └──────────┬──────────┘
                                │
                                ▼
                     ┌─────────────────────┐
                     │      FastAPI        │
                     │   Source of Truth   │
                     └──────┬─────┬────────┘
                            │     │
              ┌─────────────┘     └──────────────┐
              ▼                                  ▼
       ┌─────────────┐                  ┌─────────────────┐
       │    MySQL    │                  │  Linux Storage  │
       │             │                  │                 │
       │ Metadata    │                  │ Original Files  │
       │ Users       │                  │ PDF/JPG/PNG     │
       │ Orders      │                  └─────────────────┘
       │ Payments    │
       │ Jobs        │
       │ OTP         │
       └─────────────┘
                            │
                            │ Local REST
                            ▼
                     ┌─────────────────┐
                     │   Flask Agent   │
                     │ Print Executor  │
                     └────────┬────────┘
                              │
                              ▼
                           ┌──────┐
                           │ CUPS │
                           └──┬───┘
                              │
                              ▼
                           Printer
```

---

# 68. Core Design Principle

The entire system follows one important rule:

```text
React Native
     ↓
FastAPI
     ↓
MySQL + Linux Storage
     ↓
Flask Agent
     ↓
CUPS
     ↓
Printer
```

FastAPI is the **business and data source of truth**.

MySQL is the **structured-data source of truth**.

Linux storage is the **original-file source of truth**.

Flask is the **local print execution agent**.

CUPS is the **printer communication system**.

The React Native application is the **client**.

There is no Firebase or Cloudinary dependency.
