@echo off
title Autonomous Print Hub - All Services Launcher
echo ========================================================
echo Starting Autonomous Print Hub Services (Frontend, Backend, Agent)
echo ========================================================

REM Find Python executable
set PYTHON_EXE=C:\Users\a.muthuramalingam\AppData\Local\Programs\Python\Python312\python.exe
if not exist "%PYTHON_EXE%" (
    set PYTHON_EXE=python
)

echo [1/3] Launching FastAPI Backend on http://127.0.0.1:8000 ...
start "Print Backend (FastAPI)" cmd /k "cd /d %~dp0backend && %PYTHON_EXE% -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload"

timeout /t 2 /nobreak >nul

echo [2/3] Launching Print Agent on http://127.0.0.1:5000 ...
start "Print Agent (Flask)" cmd /k "cd /d %~dp0print-agent && %PYTHON_EXE% app/main.py"

timeout /t 2 /nobreak >nul

echo [3/3] Launching Flutter Web Frontend on http://127.0.0.1:3000 ...
start "Print Frontend (Flutter)" cmd /k "cd /d %~dp0frontend && flutter run -d web-server --web-port 3000 --web-hostname 127.0.0.1"

echo.
echo ========================================================
echo All 3 services launched successfully!
echo   * Backend:     http://127.0.0.1:8000/docs
echo   * Print Agent: http://127.0.0.1:5000 (Station ONLINE)
echo   * Frontend:    http://127.0.0.1:3000
echo ========================================================
pause
