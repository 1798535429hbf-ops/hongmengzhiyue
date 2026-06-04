# ============================================================
# WSL2 + Docker Environment Setup Script
# Run this as Administrator (right-click -> "Run as Administrator")
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WSL2 + Docker Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Enable Windows features
Write-Host "[1/3] Enabling WSL feature..." -ForegroundColor Yellow
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart -ErrorAction SilentlyContinue
Write-Host "  -> WSL feature enabled (or already was)" -ForegroundColor Green

Write-Host "[1/3] Enabling Virtual Machine Platform..." -ForegroundColor Yellow
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart -ErrorAction SilentlyContinue
Write-Host "  -> Virtual Machine Platform enabled (or already was)" -ForegroundColor Green

# 2. Install WSL2 kernel update
Write-Host "[2/3] Installing WSL2 kernel update..." -ForegroundColor Yellow
$msiPath = "$env:USERPROFILE\wsl_update_x64.msi"
if (Test-Path $msiPath) {
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msiPath`" /quiet /norestart"
    Write-Host "  -> WSL2 kernel installed" -ForegroundColor Green
} else {
    Write-Host "  -> ERROR: MSI not found at $msiPath" -ForegroundColor Red
}

# 3. Set WSL2 as default
Write-Host "[3/3] Setting WSL2 as default version..." -ForegroundColor Yellow
wsl --set-default-version 2 2>&1
Write-Host "  -> WSL2 set as default" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT - Next Steps:" -ForegroundColor White
Write-Host "  1. REBOOT your computer now!" -ForegroundColor Yellow
Write-Host "  2. After reboot, open Docker Desktop from Start Menu" -ForegroundColor Yellow
Write-Host "  3. Wait for Docker icon in system tray to turn green" -ForegroundColor Yellow
Write-Host "  4. Open a NEW terminal and run:" -ForegroundColor Yellow
Write-Host ""
Write-Host "cd $env:USERPROFILE\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" -ForegroundColor White
Write-Host "docker compose up -d" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"
