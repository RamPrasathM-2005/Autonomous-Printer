# ==============================================================================
# Achuppori - Build and Package Mobile APK (PowerShell)
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$FrontendDir = Join-Path $ProjectRoot "frontend"
$DownloadsDir = Join-Path $ProjectRoot "downloads"
$StaticDir = Join-Path $ProjectRoot "print-agent\app\static"
$TunnelFile = Join-Path $ProjectRoot "storage\tunnel_url.txt"

# Ensure output target directories exist
if (-not (Test-Path $DownloadsDir)) { New-Item -ItemType Directory -Path $DownloadsDir -Force | Out-Null }
if (-not (Test-Path $StaticDir)) { New-Item -ItemType Directory -Path $StaticDir -Force | Out-Null }

$TunnelUrl = ''
if (Test-Path -LiteralPath $TunnelFile) {
    $TunnelUrl = (Get-Content -LiteralPath $TunnelFile -Raw).Trim()
}

Write-Host "[*] Building Android Release APK via Flutter..." -ForegroundColor Cyan
Push-Location $FrontendDir
try {
    flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw "Flutter dependency installation failed." }
    flutter build apk --split-per-abi --no-pub "--dart-define=ACTIVE_TUNNEL_URL=$TunnelUrl"
    if ($LASTEXITCODE -ne 0) { throw "Flutter APK build failed." }
} finally {
    Pop-Location
}

$Arm64Apk = Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
$UniversalApk = Join-Path $FrontendDir "build\app\outputs\flutter-apk\app-release.apk"

$SourceApk = if (Test-Path $Arm64Apk) { $Arm64Apk } elseif (Test-Path $UniversalApk) { $UniversalApk } else { $null }

if ($SourceApk) {
    Write-Host "[*] Deploying APK to distribution targets..." -ForegroundColor Green
    Copy-Item -Path $SourceApk -Destination (Join-Path $DownloadsDir "achuppori.apk") -Force
    Copy-Item -Path $SourceApk -Destination (Join-Path $StaticDir "achuppori.apk") -Force

    $FileSize = (Get-Item (Join-Path $DownloadsDir "achuppori.apk")).Length / 1MB
    $FormattedSize = "{0:N2} MB" -f $FileSize

    Write-Host "[OK] Release APK successfully built! ($FormattedSize)" -ForegroundColor Green
    Write-Host "    - $DownloadsDir\achuppori.apk"
    Write-Host "    - $StaticDir\achuppori.apk"
} else {
    Write-Host "[!] Build finished but output APK not found." -ForegroundColor Red
    exit 1
}
