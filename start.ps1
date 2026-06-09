param(
  [switch]$ResetDb,
  [switch]$Logs
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Stop-WithMessage {
  param([string]$Message)
  Write-Host ""
  Write-Host "ERROR: $Message" -ForegroundColor Red
  exit 1
}

function Get-DotEnvValue {
  param(
    [string]$Path,
    [string]$Name
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  foreach ($Line in Get-Content -Path $Path) {
    if ($Line -match "^\s*$([regex]::Escape($Name))=(.*)$") {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }

  return $null
}

function Set-DotEnvValue {
  param(
    [string]$Path,
    [string]$Name,
    [string]$Value
  )

  $Lines = @()
  if (Test-Path $Path) {
    $Lines = @(Get-Content -Path $Path)
  }

  $Found = $false
  $NextLines = foreach ($Line in $Lines) {
    if ($Line -match "^\s*$([regex]::Escape($Name))=") {
      $Found = $true
      "$Name=$Value"
    } else {
      $Line
    }
  }

  if (-not $Found) {
    $NextLines += "$Name=$Value"
  }

  Set-Content -Path $Path -Value $NextLines -Encoding UTF8
}

function Test-PlaceholderKey {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $true
  }

  $Lower = $Value.Trim().ToLowerInvariant()
  return (
    $Lower -eq "replace-with-your-key" -or
    $Lower -like "*replace*" -or
    $Lower -like "*xxxxx*" -or
    $Value -match "[^\x00-\x7F]"
  )
}

function Wait-Http {
  param(
    [string]$Name,
    [string]$Url
  )

  Write-Step "Waiting for $Name"
  for ($Index = 1; $Index -le 60; $Index++) {
    try {
      $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
      if ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 500) {
        Write-Host "$Name is ready: $Url" -ForegroundColor Green
        return
      }
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  Stop-WithMessage "$Name did not become ready. Run 'docker compose logs $Name' for details."
}

Write-Step "Checking Docker"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Stop-WithMessage "Docker was not found. Install Docker Desktop first."
}

try {
  docker info *> $null
} catch {
  Stop-WithMessage "Docker Desktop is not running. Start Docker Desktop and try again."
}

try {
  docker compose version *> $null
} catch {
  Stop-WithMessage "Docker Compose v2 is required. Update Docker Desktop and try again."
}

$EnvFile = Join-Path $RootDir ".env"
$EnvExample = Join-Path $RootDir ".env.example"

if (-not (Test-Path $EnvFile)) {
  Write-Step "Creating .env"
  if (-not (Test-Path $EnvExample)) {
    Stop-WithMessage ".env.example was not found."
  }
  Copy-Item -Path $EnvExample -Destination $EnvFile
}

$DeepSeekKey = Get-DotEnvValue -Path $EnvFile -Name "DEEPSEEK_API_KEY"
if (Test-PlaceholderKey $DeepSeekKey) {
  Write-Step "DeepSeek API key is required"
  Write-Host "Paste your DEEPSEEK_API_KEY. It usually starts with sk-."
  $DeepSeekKey = Read-Host "DEEPSEEK_API_KEY"

  if (Test-PlaceholderKey $DeepSeekKey) {
    Stop-WithMessage "A real DEEPSEEK_API_KEY is required because ai-service validates it on startup."
  }

  Set-DotEnvValue -Path $EnvFile -Name "DEEPSEEK_API_KEY" -Value $DeepSeekKey.Trim()
}

if ($ResetDb) {
  Write-Step "Resetting database volume"
  docker compose down -v
}

Write-Step "Starting MySQL, backend, and AI service"
docker compose up -d --build

Wait-Http -Name "backend" -Url "http://localhost:8081/api/health"
Wait-Http -Name "ai-service" -Url "http://localhost:8001/health"

Write-Step "Container status"
docker compose ps

Write-Host ""
Write-Host "Ready." -ForegroundColor Green
Write-Host "Backend API: http://localhost:8081/api"
Write-Host "AI service:  http://localhost:8001"
Write-Host "MySQL:       localhost:3306 / hongmeng_zhiyue"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  docker compose logs -f"
Write-Host "  docker compose down"
Write-Host "  .\start.ps1 -ResetDb"

if ($Logs) {
  docker compose logs -f
}
