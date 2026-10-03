$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $projectRoot '.runtime'
foreach ($name in @('frontend', 'agent', 'reconciliation', 'backend')) {
    $stateFile = Join-Path $runtime "$name.json"
    if (-not (Test-Path -LiteralPath $stateFile)) { continue }
    $saved = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $proc = Get-Process -Id $saved.Id -ErrorAction SilentlyContinue
    $isSameProcess = $false
    if ($proc) {
        try {
            if ($proc.StartTime -and $proc.StartTime.ToUniversalTime().Ticks.ToString() -eq $saved.StartTicks) {
                $isSameProcess = $true
            }
        } catch {
            $isSameProcess = $false
        }
    }
    if ($isSameProcess) {
        # Include the child interpreter created by Windows Python virtual environments.
        & taskkill.exe /PID $proc.Id /T /F | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not stop $name." }
        Write-Host "Stopped $name."
    }
    Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
}
foreach ($extra in @('flutter_web.pid', 'hot_reload_trigger')) {
    $extraFile = Join-Path $runtime $extra
    if (Test-Path -LiteralPath $extraFile) { Remove-Item -LiteralPath $extraFile -Force }
}
