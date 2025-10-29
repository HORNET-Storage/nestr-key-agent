# Nestr Key Agent Installation Script for Windows
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$PRODUCT_NAME = "keyagent"
$REPO_OWNER = "HORNET-Storage"
$REPO_NAME = "nestr-key-agent"

Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host "   Nestr Key Agent Installation" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠ This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Check if already installed
$existingService = Get-Service -Name "NestrKeyAgent" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "⚠ Nestr Key Agent service is already installed." -ForegroundColor Yellow
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Stopping existing service..." -ForegroundColor Yellow
    Stop-Service -Name "NestrKeyAgent" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Get latest version
Write-Host "Fetching latest version..." -ForegroundColor Yellow
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    $version = $release.tag_name
    Write-Host "✓ Latest version: $version" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to fetch latest version" -ForegroundColor Red
    exit 1
}

# Download installer
$installerUrl = "https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/NestrKeyAgent-Setup.exe"
$installerPath = "$env:TEMP\NestrKeyAgent-Setup.exe"

Write-Host "Downloading installer..." -ForegroundColor Yellow
Write-Host "  From: $installerUrl" -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "✓ Download complete" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to download installer" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

# Run installer
Write-Host ""
Write-Host "Running installer..." -ForegroundColor Yellow
Write-Host "  The installer will set up the Key Agent as a Windows service" -ForegroundColor Gray

$process = Start-Process -FilePath $installerPath -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "✓ Installation complete!" -ForegroundColor Green
} else {
    Write-Host "✗ Installation failed (Exit code: $($process.ExitCode))" -ForegroundColor Red
    exit 1
}

# Clean up
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Check service
$service = Get-Service -Name "NestrKeyAgent" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "✓ Service installed: $($service.DisplayName)" -ForegroundColor Green
    Write-Host "  Status: $($service.Status)" -ForegroundColor Gray
    Write-Host "  Startup Type: $($service.StartType)" -ForegroundColor Gray
} else {
    Write-Host "⚠ Service not found" -ForegroundColor Yellow
}

# Check CLI tool
$cliPath = Get-Command keyagent-cli.exe -ErrorAction SilentlyContinue
if ($cliPath) {
    Write-Host "✓ CLI tool is installed and in PATH" -ForegroundColor Green
} else {
    Write-Host "⚠ CLI tool installed but not in PATH" -ForegroundColor Yellow
    Write-Host "  You may need to restart your terminal" -ForegroundColor Yellow
}

# Show management info
Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "The Nestr Key Agent is now running as a Windows service." -ForegroundColor White
Write-Host ""
Write-Host "Manage the service:" -ForegroundColor Yellow
Write-Host "  Start:   Start-Service NestrKeyAgent" -ForegroundColor White
Write-Host "  Stop:    Stop-Service NestrKeyAgent" -ForegroundColor White
Write-Host "  Restart: Restart-Service NestrKeyAgent" -ForegroundColor White
Write-Host "  Status:  Get-Service NestrKeyAgent" -ForegroundColor White
Write-Host ""
Write-Host "Or use the Start Menu shortcuts:" -ForegroundColor Yellow
Write-Host "  • Start Menu > Nestr Key Agent > Start/Stop Service" -ForegroundColor White
Write-Host "  • Start Menu > Nestr Key Agent > Key Agent CLI" -ForegroundColor White
Write-Host ""
Write-Host "Use the CLI tool:" -ForegroundColor Yellow
Write-Host "  keyagent-cli --help" -ForegroundColor White
Write-Host ""
Write-Host "For more information: https://github.com/HORNET-Storage/nestr-key-agent" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "⚠ You may need to restart your terminal for PATH changes to take effect" -ForegroundColor Yellow
