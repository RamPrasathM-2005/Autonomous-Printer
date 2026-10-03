param(
    [switch]$Build,
    [switch]$NoBrowser,
    [Alias('dev', 'hotreload', 'hot_reload', 'd')][switch]$Hot
)
$ErrorActionPreference = 'Stop'
foreach ($argument in $args) {
    if ($argument -match '^--?(hot|dev|hotreload|hot_reload|d)$') { $Hot = $true }
    if ($argument -match '^--?build$') { $Build = $true }
    if ($argument -match '^--?nobrowser$') { $NoBrowser = $true }
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $projectRoot '.runtime'
$python = Join-Path $projectRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Create .venv and install requirements.txt first.' }
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$webRoot = Join-Path $projectRoot 'frontend\build\web'
$tunnelDart = Join-Path $projectRoot 'frontend\lib\config\active_tunnel.dart'
if (-not (Test-Path -LiteralPath $tunnelDart)) {
    Copy-Item -LiteralPath "$tunnelDart.example" -Destination $tunnelDart
}
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    $flutterCandidates = @(
        'D:\flutter_windows_3.47.5-stable\flutter\bin\flutter.bat',
        (Join-Path (Split-Path -Parent $projectRoot) '.tools\flutter\bin\flutter.bat')
    )
    $localFlutter = $flutterCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($localFlutter) {
        $env:Path = (Split-Path -Parent $localFlutter) + ';' + $env:Path
        $flutter = Get-Command flutter
    }
}
if ($Hot -or $Build -or -not (Test-Path -LiteralPath (Join-Path $webRoot 'main.dart.js'))) {
    if (-not $flutter) { throw 'Flutter is not installed or available on PATH.' }
    Push-Location (Join-Path $projectRoot 'frontend')
    try {
        & $flutter.Source packages pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
        if (-not $Hot) {
            & $flutter.Source build web --release --no-pub --no-web-resources-cdn --no-wasm-dry-run
            if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
        }
    } finally { Pop-Location }
}
function Start-LocalService($Name, $Directory, $Arguments, $Port, $HealthUrl, [int]$TimeoutSec = 45) {
    $stateFile = Join-Path $runtime "$Name.json"
    if (Test-Path -LiteralPath $stateFile) {
        $saved = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        $existing = Get-Process -Id $saved.Id -ErrorAction SilentlyContinue
        if ($existing -and $existing.StartTime.ToUniversalTime().Ticks.ToString() -eq $saved.StartTicks) {
            if ($HealthUrl) {
                try { $null = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5 }
                catch { throw "$Name is running but unhealthy. Check .runtime logs and run stop_all.bat." }
            }
            Write-Host "$Name already running."
            return
        }
    }
    if ($Port) {
        $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
        if ($listener) { throw "Port $Port is occupied. Stop its service before starting $Name." }
    }
    $proc = Start-Process -FilePath $python -ArgumentList $Arguments -WorkingDirectory $Directory `
        -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $runtime "$Name.out.log") `
        -RedirectStandardError (Join-Path $runtime "$Name.err.log")
    @{ Id = $proc.Id; StartTicks = $proc.StartTime.ToUniversalTime().Ticks.ToString() } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        $proc.Refresh()
        if ($proc.HasExited) { throw "$Name exited. Check .runtime\$Name.err.log." }
        if (-not $HealthUrl) { Write-Host "$Name started."; return }
        try {
            $null = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3
            Write-Host "$Name ready: $HealthUrl"
            return
        } catch { Start-Sleep -Milliseconds 500 }
    } while ((Get-Date) -lt $deadline)
    throw "$Name did not become ready. Check .runtime logs."
}
$backendArgs = '-u -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-proxy-headers'
if ($Hot) { $backendArgs += ' --reload' }
Start-LocalService 'backend' (Join-Path $projectRoot 'backend') $backendArgs 8000 'http://127.0.0.1:8000/health'
Start-LocalService 'reconciliation' (Join-Path $projectRoot 'backend') '-u -m app.worker' 0 $null
Push-Location $projectRoot
try {
    $agentPortOutput = & $python -c "from dotenv import dotenv_values; print(dotenv_values('print-agent/.env').get('PORT') or '5001')"
    if ($LASTEXITCODE -ne 0) { throw 'Could not read agent port.' }
} finally { Pop-Location }
$agentPort = [int]($agentPortOutput | Select-Object -Last 1)
Start-LocalService 'agent' (Join-Path $projectRoot 'print-agent') '-u -m app.main' $agentPort "http://127.0.0.1:$agentPort/health"
if ($Hot) {
    Start-LocalService 'frontend' $projectRoot '-u scripts/flutter_hot_watcher.py --serve --port 3000' 3000 'http://127.0.0.1:3000/' 180
} else {
    Start-LocalService 'frontend' $projectRoot '-u scripts/serve_frontend.py' 3000 'http://127.0.0.1:3000/'
}
Write-Host 'App: http://127.0.0.1:3000/'
Write-Host "Station keypad: http://127.0.0.1:$agentPort/kiosk"
Write-Host 'Logs: .runtime | Stop: stop_all.bat | Rebuild: start_all.bat -Build'
if (-not $NoBrowser) { Start-Process 'http://127.0.0.1:3000/' }
