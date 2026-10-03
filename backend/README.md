# 🖨️ Achuppori - Backend Service (FastAPI)

Central REST API backend built with **FastAPI (Python 3.12+)**, **SQLAlchemy ORM**, **MySQL**, and **Pydantic v2**. It handles document upload validation, multi-document order management, exact pricing calculation, Razorpay payment processing, and secure OTP release verification.

---

## 📋 Prerequisites

Before running the backend, ensure you have the following installed:

- **Python 3.12+** ([python.org](https://www.python.org/downloads/))
- **MySQL Server 8.0+** ([mysql.com](https://dev.mysql.com/downloads/installer/))
- **Git** ([git-scm.com](https://git-scm.com/))

---

## ⚙️ Environment Configuration

1. In the `backend/` directory, copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
   *(On Windows PowerShell: `Copy-Item .env.example .env`)*

2. Configure your `.env` variables:
   ```env
   # Application Configuration
   APP_NAME="PrintPlatform"
   ENVIRONMENT="development"
   HOST="127.0.0.1"
   PORT=8000

   # MySQL Database Connection
   DATABASE_URL="mysql+pymysql://<user>:<password>@127.0.0.1:3306/print_platform"

   # Security & Auth
   JWT_SECRET_KEY="CHANGE_ME_SUPER_SECRET_KEY_AT_LEAST_32_CHARS"
   JWT_ALGORITHM="HS256"
   JWT_ACCESS_TOKEN_EXPIRE_MINUTES=15
   JWT_REFRESH_TOKEN_EXPIRE_DAYS=30

   # Storage & Upload Limits
   STORAGE_ROOT="./storage"
   MAX_UPLOAD_MB=50

   # Pricing Configuration
   PER_PAGE_RATE=2.00
   COLOR_PAGE_RATE=5.00
   BASE_FEE=0.00

   # OTP & Retries
   OTP_TTL_MINUTES=30
   MAX_OTP_ATTEMPTS=5
   MAX_PRINT_RETRIES=2

   # Razorpay Payment Gateway (Test Mode)
   RAZORPAY_KEY_ID="rzp_test_RFxhjAiTxwrpAJ"
   RAZORPAY_KEY_SECRET="f7jSae5XJ4V6EfZIYTUpWB7q"
   ```

---

## 🗄️ Database Setup

Ensure MySQL is running and create the `print_platform` database:

```sql
CREATE DATABASE IF NOT EXISTS print_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

> **Note**: Database tables are automatically created on startup by SQLAlchemy via `Base.metadata.create_all(bind=engine)` in `app/main.py`.

---

## 🚀 Step-by-Step: How to Run

### Step 1: Navigate to the Backend Directory
```bash
cd backend
```

### Step 2: Create and Activate a Python Virtual Environment

- **On Windows (PowerShell)**:
  ```powershell
  python -m venv venv
  .\venv\Scripts\Activate.ps1
  ```
  *(If you get an execution policy error, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first)*

- **On Linux / macOS**:
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  ```

### Step 3: Install Required Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 4: Run the Development Server
```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

When started successfully, you will see:
```text
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
INFO:     Started reloader process using WatchFiles
INFO:     Application startup complete.
```

---

## 🔍 Verification & Interactive API Documentation

- **Health Check**: Open [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)
- **Interactive Swagger Docs**: Open [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Redoc Documentation**: Open [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

---

## 🧪 Running Automated Tests

Run the full pytest suite (all 10 automated test suites):

```bash
pytest -v
```

To run a specific test file:
```bash
pytest tests/test_multi_doc_orders.py -v
```

---

## 🛠️ Common Troubleshooting

| Issue | Resolution |
| :--- | :--- |
| **`python` not found on Windows** | Add Python to your Windows System PATH or use full path: `& "C:\Users\<user>\AppData\Local\Programs\Python\Python312\python.exe"` |
| **Port 8000 already in use** | Find and terminate the process using port 8000: `netstat -ano \| findstr :8000` followed by `taskkill /PID <PID> /F` (Windows) or `kill -9 $(lsof -t -i:8000)` (Linux). |
| **MySQL Connection Refused** | Verify MySQL service is running (`Get-Service MySQL*` on Windows or `sudo systemctl status mysql` on Linux). Ensure username and password in `DATABASE_URL` are correct. |
