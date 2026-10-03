@echo off
:: Autonomous-Printer - Fix Windows Excluded Port Range (WinError 10013)
:: Releases port 8000 hijacked by Windows NAT (winnat) / Hyper-V / WSL.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges to reset port exclusion ranges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo [*] Stopping Windows NAT driver (winnat)...
net stop winnat

echo [*] Resetting TCP dynamic port range to standard IANA range (start=49152, num=16384)...
netsh int ipv4 set dynamicport tcp start=49152 num=16384

echo [*] Restarting Windows NAT driver (winnat)...
net start winnat

echo.
echo ======================================================================
echo  [OK] Windows port exclusion range reset successfully.
echo       Port 8000 is now free for FastAPI and Autonomous-Printer.
echo ======================================================================
echo.
pause
