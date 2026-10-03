@echo off
set "LAUNCHER=%~dp0scripts\start-local.ps1"
if not exist "%LAUNCHER%" (
    echo [ERROR] Windows launcher not found: "%LAUNCHER%"
    echo Make sure scripts\start-local.ps1 is present in this project folder.
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%" %*
if errorlevel 1 pause
