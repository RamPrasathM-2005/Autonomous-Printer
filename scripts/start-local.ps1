param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $projectRoot '.runtime'
$frontendBuild = Join-Path $projectRoot 'frontend\build\web'
$pythonVenv = Join-Path $projectRoot '.venv\Scripts\python.exe'
$pythonExe = if (Test-Path -LiteralPath $pythonVenv) { $pythonVenv } else { 'python' }
$flutterInstall = 'D:\flutter_windows_3.47.5-stable\flutter\bin\flutter.bat'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExe = if (Test-Path -LiteralPath $flutterInstall) {
    $flutterInstall
} elseif ($flutterCommand) {
    $flutterCommand.Source
} else {
    $null
}

if (-not (Test-Path -LiteralPath $runtime)) {
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
}

# Refuse to start a second managed set of services over a still-running one.
foreach ($name in @('frontend', 'agent', 'reconciliation', 'backend')) {
    $stateFile = Join-Path $runtime "$name.json"
    if (-not (Test-Path -LiteralPath $stateFile)) { continue }
    try {
        $saved = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        $existing = Get-Process -Id $saved.Id -ErrorAction SilentlyContinue
        if ($existing -and $existing.StartTime.ToUniversalTime().Ticks.ToString() -eq $saved.StartTicks) {
            throw "Achuppori services are already running ($name, PID $($saved.Id)). Run stop_all.bat first."
        }
    } catch {
        if ($_.Exception.Message -like 'Achuppori services are already running*') { throw }
    }
    Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
}

if ($Build -or -not (Test-Path -LiteralPath $frontendBuild)) {
    if (-not $flutterExe) {
        throw 'Flutter was not found. Install Flutter or add it to PATH, then retry.'
    }
    Write-Host 'Building Flutter web release...' -ForegroundColor Cyan
    Push-Location (Join-Path $projectRoot 'frontend')
    try {
        & $flutterExe build web --release --no-wasm-dry-run
        if ($LASTEXITCODE -ne 0) { throw "Flutter web build failed with exit code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $frontendBuild)) {
    throw "Flutter web output was not found at $frontendBuild."
}

$started = [System.Collections.Generic.List[object]]::new()

function Start-LocalService {
    param(
        [string]$Name,
        [string]$WorkingDirectory,
        [string[]]$Arguments
    )

    $stdout = Join-Path $runtime "$Name.out.log"
    $stderr = Join-Path $runtime "$Name.err.log"
    $stateFile = Join-Path $runtime "$Name.json"
    $process = Start-Process -FilePath $pythonExe -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr -PassThru
    Start-Sleep -Milliseconds 700
    $process.Refresh()
    if ($process.HasExited) {
        $details = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw } else { '' }
        throw "$Name failed to start. $details"
    }

    $record = [pscustomobject]@{
        Id = $process.Id
        StartTicks = $process.StartTime.ToUniversalTime().Ticks.ToString()
    }
    $record | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding utf8
    $started.Add([pscustomobject]@{ Name = $Name; Id = $process.Id; StateFile = $stateFile })
    Write-Host "Started $Name (PID $($process.Id))." -ForegroundColor Green
}

try {
    $backend = Join-Path $projectRoot 'backend'
    $agent = Join-Path $projectRoot 'print-agent'
    Start-LocalService -Name 'backend' -WorkingDirectory $backend -Arguments @('-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', '8000')
    Start-LocalService -Name 'reconciliation' -WorkingDirectory $backend -Arguments @('-m', 'app.worker')
    Start-LocalService -Name 'agent' -WorkingDirectory $agent -Arguments @('app/main.py')
    Start-LocalService -Name 'frontend' -WorkingDirectory $projectRoot -Arguments @('scripts/serve_frontend.py')
} catch {
    foreach ($service in $started) {
        & taskkill.exe /PID $service.Id /T /F 2>$null | Out-Null
        Remove-Item -LiteralPath $service.StateFile -Force -ErrorAction SilentlyContinue
    }
    throw
}

Write-Host ''
Write-Host 'Achuppori services are running:' -ForegroundColor Cyan
Write-Host '  Website:       http://127.0.0.1:3000/'
Write-Host '  Backend docs:  http://127.0.0.1:8000/docs'
Write-Host '  Print agent:   http://127.0.0.1:5000/health'
Write-Host 'Stop services with stop_all.bat.'
