param(
    [switch]$Build,
    [switch]$NoBrowser,
    [Alias('dev', 'hotreload', 'hot_reload', 'd')]
    [switch]$Hot
)

# Support double-dash and legacy flags passed in $args
foreach ($a in $args) {
    if ($a -match '^--?(hot|dev|hotreload|hot_reload|d)$') { $Hot = $true }
    if ($a -match '^--?build$') { $Build = $true }
    if ($a -match '^--?nobrowser$') { $NoBrowser = $true }
}

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $projectRoot '.runtime'
$python = Join-Path $projectRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Install dependencies first: python -m venv .venv, then .venv\Scripts\python.exe -m pip install -r requirements.txt'
}
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$webRoot = Join-Path $projectRoot 'frontend\build\web'

if ($Hot) {
    Write-Host "[*] Windows Hot-Reload mode enabled."
} elseif ($Build -or -not (Test-Path -LiteralPath (Join-Path $webRoot 'main.dart.js'))) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:Path
    $flutter = Get-Command flutter -ErrorAction Stop
    Push-Location (Join-Path $projectRoot 'frontend')
    try {
        # Resolve in Flutter's SDK context without generating desktop symlinks.
        # The web build below generates its own platform-specific plugin registry.
        & $flutter.Source packages pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed. See the output above.' }
        & $flutter.Source build web --release --no-pub --no-web-resources-cdn --no-wasm-dry-run
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed.' }
    } finally { Pop-Location }
}

function Start-LocalService($Name, $Directory, $Arguments, $Port, $HealthUrl, [int]$TimeoutSec = 45) {
    $stateFile = Join-Path $runtime "$Name.json"
    if (Test-Path -LiteralPath $stateFile) {
        $saved = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        $existing = Get-Process -Id $saved.Id -ErrorAction SilentlyContinue
        if ($existing -and $existing.StartTime.ToUniversalTime().Ticks.ToString() -eq $saved.StartTicks) {
            try {
                if (-not $HealthUrl) { Write-Host "$Name already running."; return }
                $null = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
                Write-Host "$Name already running: $HealthUrl"
                return
            } catch { throw "$Name is running but unhealthy. Check .runtime logs, then run stop_all.bat." }
        }
    }
    $listener = $null
    if ($Port) { $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue }
    if ($listener) { throw "Port $Port is occupied by another process. Stop it before starting $Name." }
    $proc = Start-Process -FilePath $python -ArgumentList $Arguments -WorkingDirectory $Directory `
        -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $runtime "$Name.out.log") `
        -RedirectStandardError (Join-Path $runtime "$Name.err.log")
    @{ Id = $proc.Id; StartTicks = $proc.StartTime.ToUniversalTime().Ticks.ToString() } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        $proc.Refresh()
        if ($proc.HasExited) { throw "$Name exited. Check .runtime\$Name.err.log and .runtime\$Name.out.log." }
        try {
            if (-not $HealthUrl) { Start-Sleep -Seconds 2; $proc.Refresh(); if ($proc.HasExited) { throw "$Name exited." }; Write-Host "$Name started."; return }
            $null = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
            Write-Host "$Name ready: $HealthUrl"
            return
        } catch { Start-Sleep -Milliseconds 500 }
    } while ((Get-Date) -lt $deadline)
    throw "$Name did not become ready. Check .runtime logs."
}

$backendArgs = '-u -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-proxy-headers'
if ($Hot) {
    $backendArgs += ' --reload'
    Write-Host "[*] Backend live auto-reload enabled (uvicorn --reload)."
}
Start-LocalService 'backend' (Join-Path $projectRoot 'backend') $backendArgs 8000 'http://127.0.0.1:8000/health'
Start-LocalService 'reconciliation' (Join-Path $projectRoot 'backend') '-u -m app.worker' 0 $null
Push-Location (Join-Path $projectRoot 'print-agent')
try {
    $agentPort = & $python -c 'from app.config import config; print(config.PORT)'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read the print-agent port.' }
    $agentPort = [int]$agentPort
} finally { Pop-Location }
Start-LocalService 'agent' (Join-Path $projectRoot 'print-agent') '-u -m app.main' $agentPort "http://127.0.0.1:$agentPort/health"

if ($Hot) {
    Write-Host "[*] Starting Flutter Web in LIVE HOT-RELOAD mode on http://127.0.0.1:3000 ..."
    Start-LocalService 'frontend' $projectRoot '-u scripts/flutter_hot_watcher.py --serve --port 3000 --host 127.0.0.1' 3000 'http://127.0.0.1:3000/' 90
} else {
    Start-LocalService 'frontend' $projectRoot '-u scripts/serve_frontend.py' 3000 'http://127.0.0.1:3000/'
}

if ($Hot) {
    Write-Host "`nApp: http://127.0.0.1:3000/ [HOT-RELOAD ACTIVE]"
    Write-Host 'Live watching frontend/lib/*.dart and backend/*.py for changes.'
} else {
    Write-Host "`nApp: http://127.0.0.1:3000/ (Pass -Hot for live hot-reload mode)"
}
Write-Host 'API docs: http://127.0.0.1:8000/docs'
Write-Host 'Printing progress is shown inside the authenticated frontend.'
Write-Host "Station keypad: http://127.0.0.1:$agentPort/kiosk"
Write-Host 'Logs: .runtime | Stop: stop_all.bat | Rebuild frontend: start_all.bat -Build'
if (-not $NoBrowser) { Start-Process 'http://127.0.0.1:3000/' }
