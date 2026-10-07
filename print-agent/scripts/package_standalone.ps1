# ==============================================================================
# Autonomous Printer - Standalone Package Bundler (PowerShell)
# Creates a clean, minimal zip archive with zero test/dev/backend dependencies.
# ==============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AgentDir = Split-Path -Parent $ScriptDir
$DistDir = Join-Path $AgentDir "dist"
$StagingDir = Join-Path $DistDir "print-agent"
$ZipPath = Join-Path $DistDir "print-agent-pi-standalone.zip"

Write-Host "Creating clean standalone package for Raspberry Pi 3 Model B..."

if (Test-Path $DistDir) {
    Remove-Item -Path $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Copy only production directories and files
Copy-Item -Path (Join-Path $AgentDir "app") -Destination $StagingDir -Recurse
Copy-Item -Path (Join-Path $AgentDir "deploy") -Destination $StagingDir -Recurse
Copy-Item -Path (Join-Path $AgentDir "scripts") -Destination $StagingDir -Recurse
Copy-Item -Path (Join-Path $AgentDir ".env.example") -Destination $StagingDir
Copy-Item -Path (Join-Path $AgentDir "requirements.txt") -Destination $StagingDir
Copy-Item -Path (Join-Path $AgentDir "DEPLOYMENT.md") -Destination $StagingDir
Copy-Item -Path (Join-Path $AgentDir "README.md") -Destination $StagingDir

# Clean cache directories from staging
Get-ChildItem -Path $StagingDir -Include "__pycache__", "*.pyc", "*.pyo" -Recurse -Force | Remove-Item -Recurse -Force

# Create directories required at runtime
New-Item -ItemType Directory -Path (Join-Path $StagingDir "storage/processed_jobs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $StagingDir "logs") -Force | Out-Null

# Compress staging directory
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipPath -Force

Write-Host "Standalone deployment package successfully created at: $ZipPath"
Get-Item $ZipPath | Select-Object Name, Length, LastWriteTime
