#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test GrooveApp Angular frontend locally with Docker and API endpoints
.DESCRIPTION
    Builds and runs the Angular frontend in Docker for local testing.
    The frontend will connect to the API at http://localhost:8000
    Can also run comprehensive API endpoint testing for all combinations.
.PARAMETER Rebuild
    Rebuild the Docker image before running (includes security scan)
.PARAMETER NoBuild
    Run without building (uses existing image)
.PARAMETER Stop
    Stop and remove the running container
.PARAMETER Logs
    Show container logs
.PARAMETER Production
    Build for production (connects to Azure API)
.PARAMETER TestApi
    Run comprehensive API endpoint tests (all notes × scales × arpeggios)
.PARAMETER ApiUrl
    API URL for testing (default: http://localhost:8000)
.PARAMETER StopOnError
    Stop API testing on first error
.PARAMETER MaxSeverity
    Maximum allowed vulnerability severity: critical, high, medium, low
    Default: high (blocks critical and high)
.PARAMETER SkipScan
    Skip vulnerability scanning during build (not recommended)
.PARAMETER LogLevel
    Log level for the application (OFF, ERROR, WARNING, INFO, DEBUG)
    Default: DEBUG for local, INFO for production
.EXAMPLE
    .\build-localFrontEnd.ps1 -Rebuild
    .\build-localFrontEnd.ps1 -Rebuild -LogLevel INFO
    .\build-localFrontEnd.ps1 -Production
    .\build-localFrontEnd.ps1 -Logs
    .\build-localFrontEnd.ps1 -Stop
#>

param(
  [switch]$Rebuild,
  [switch]$NoBuild,
  [switch]$Stop,
  [switch]$Logs,
  [switch]$Production,
  [switch]$TestApi,
  [string]$ApiUrl = "http://localhost:8000",
  [switch]$StopOnError,
  [ValidateSet("critical", "high", "medium", "low")]
  [string]$MaxSeverity = "high",
  [switch]$SkipScan,
  [ValidateSet("OFF", "ERROR", "WARNING", "INFO", "DEBUG")]
  [string]$LogLevel = ""
)

$ErrorActionPreference = "Stop"

$containerName = "grooveapp-ui-local"
$imageName = "grooveapp-ui"
$port = 8080

# Stop container
if ($Stop) {
  Write-Host "`n🛑 Stopping container..." -ForegroundColor Yellow
  docker stop $containerName 2>$null
  docker rm $containerName 2>$null
  Write-Host "✅ Container stopped and removed" -ForegroundColor Green
  exit 0
}

# Show logs
if ($Logs) {
  Write-Host "`n📋 Showing logs..." -ForegroundColor Cyan
  docker logs -f $containerName
  exit 0
}

# Build image
if ($Rebuild) {
  Write-Host "`n================================================" -ForegroundColor Cyan
  Write-Host "Building Docker Image: $imageName" -ForegroundColor Cyan
  Write-Host "================================================`n" -ForegroundColor Cyan

  # Determine build arguments
  $buildArgs = @()
  if ($Production) {
    Write-Host "Building for PRODUCTION (connects to Azure API)" -ForegroundColor Yellow
    $buildArgs += "--build-arg", "ENVIRONMENT=production"
  }
  else {
    Write-Host "Building for DEVELOPMENT (connects to localhost:8000)" -ForegroundColor Yellow
  }

  # Local testing uses console logging only (no Application Insights)
  Write-Host "Application Insights: Disabled (console logging only for local testing)" -ForegroundColor Cyan

  # Set log level (default: DEBUG for dev, INFO for prod)
  $effectiveLogLevel = $LogLevel
  if (-not $effectiveLogLevel) {
    $effectiveLogLevel = if ($Production) { "INFO" } else { "DEBUG" }
  }
  Write-Host "Log Level: $effectiveLogLevel" -ForegroundColor Cyan

  # Skip npm audit during build if requested
  if ($SkipScan) {
    Write-Host "⚠️  Skipping npm audit during build" -ForegroundColor Yellow
    $buildArgs += "--build-arg", "SKIP_AUDIT=true"
  }

  # Build the image
  $buildCmd = "docker build -t $imageName $($buildArgs -join ' ') ."
  Invoke-Expression $buildCmd

  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed" -ForegroundColor Red
    exit 1
  }
  Write-Host "✅ Docker image built successfully" -ForegroundColor Green

  # Run security scan unless skipped
  if (-not $SkipScan) {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "Security Scan (Docker Scout)" -ForegroundColor Cyan
    Write-Host "================================================`n" -ForegroundColor Cyan

    # Get scan output and parse vulnerability counts (consistent with API script)
    $scanOutput = docker scout cves $imageName 2>&1 | Out-String

    # Parse vulnerability counts
    $criticalCount = 0
    $highCount = 0
    $mediumCount = 0
    $lowCount = 0

    if ($scanOutput -match "(\d+)C\s+(\d+)H\s+(\d+)M\s+(\d+)L") {
      $criticalCount = [int]$matches[1]
      $highCount = [int]$matches[2]
      $mediumCount = [int]$matches[3]
      $lowCount = [int]$matches[4]
    }

    Write-Host "Vulnerability Summary:" -ForegroundColor Cyan
    Write-Host "  Critical: $criticalCount" -ForegroundColor $(if ($criticalCount -gt 0) { "Red" } else { "Green" })
    Write-Host "  High:     $highCount" -ForegroundColor $(if ($highCount -gt 0) { "Red" } else { "Green" })
    Write-Host "  Medium:   $mediumCount" -ForegroundColor $(if ($mediumCount -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Low:      $lowCount" -ForegroundColor Green

    # Check threshold based on MaxSeverity parameter
    $shouldFail = $false
    $failReason = ""

    switch ($MaxSeverity) {
      "critical" {
        if ($criticalCount -gt 0) {
          $shouldFail = $true
          $failReason = "Found $criticalCount CRITICAL vulnerabilities"
        }
      }
      "high" {
        if ($criticalCount -gt 0 -or $highCount -gt 0) {
          $shouldFail = $true
          $failReason = "Found $criticalCount CRITICAL and $highCount HIGH vulnerabilities"
        }
      }
      "medium" {
        if ($criticalCount -gt 0 -or $highCount -gt 0 -or $mediumCount -gt 0) {
          $shouldFail = $true
          $failReason = "Found vulnerabilities exceeding medium threshold"
        }
      }
    }

    if ($shouldFail) {
      Write-Host "`n❌ SECURITY SCAN FAILED: $failReason" -ForegroundColor Red
      Write-Host "To fix: docker scout recommendations $imageName" -ForegroundColor Yellow
      Write-Host "To override: .\build-localFrontEnd.ps1 -Rebuild -MaxSeverity medium" -ForegroundColor Yellow
      exit 1
    }
    else {
      Write-Host "✅ Security scan passed (max severity: $MaxSeverity)" -ForegroundColor Green
    }
  }
  else {
    Write-Host "⚠️  Security scan skipped" -ForegroundColor Yellow
  }
}

# Check if image exists
if (-not $NoBuild -and -not $Rebuild) {
  $imageExists = docker images -q $imageName 2>$null
  if (-not $imageExists) {
    Write-Host "⚠️  Image not found. Building..." -ForegroundColor Yellow
    docker build -t $imageName .
    if ($LASTEXITCODE -ne 0) {
      Write-Host "❌ Docker build failed" -ForegroundColor Red
      exit 1
    }
  }
}

# Stop existing container
docker stop $containerName 2>$null | Out-Null
docker rm $containerName 2>$null | Out-Null

# Run container
Write-Host "`n🚀 Starting container..." -ForegroundColor Cyan

# Build environment variable array for log level and API URL
$envVars = @()
$effectiveLogLevel = if ($LogLevel) { $LogLevel } elseif ($Production) { "INFO" } else { "DEBUG" }
$envVars += "-e", "LOG_LEVEL=$effectiveLogLevel"

# Set API_URL based on environment
# For local dev: use localhost since the browser (not the container) makes API calls
# Angular runs in the browser, so it accesses the API from the host machine perspective
if (-not $Production) {
  $envVars += "-e", "API_URL=http://localhost:8000"
}

docker run -d `
  --name $containerName `
  -p ${port}:8080 `
  $envVars `
  $imageName

if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Failed to start container" -ForegroundColor Red
  exit 1
}

Write-Host "✅ Container started successfully" -ForegroundColor Green

# Wait for container to be ready
Write-Host "`n⏳ Waiting for application to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Test health endpoint
try {
  $response = Invoke-WebRequest -Uri "http://localhost:${port}/health" -UseBasicParsing -TimeoutSec 5
  if ($response.StatusCode -eq 200) {
    Write-Host "✅ Application is healthy" -ForegroundColor Green
  }
}
catch {
  Write-Host "⚠️  Health check failed, but container is running" -ForegroundColor Yellow
}

Write-Host "`n📱 Frontend URL: http://localhost:${port}" -ForegroundColor Green
Write-Host "📖 View logs: .\build-localFrontEnd.ps1 -Logs" -ForegroundColor Cyan
Write-Host "🛑 Stop: .\build-localFrontEnd.ps1 -Stop" -ForegroundColor Cyan
Write-Host "`n📊 Logging: Console only (Application Insights only enabled in Azure deployments)" -ForegroundColor Cyan
Write-Host "   Open browser console (F12) to see logs" -ForegroundColor Gray

if (-not $Production) {
  Write-Host "`n⚠️  Make sure the API is running on http://localhost:8000" -ForegroundColor Yellow
  Write-Host "   Run: cd ..\api; .\build-localApi.ps1" -ForegroundColor Yellow
}
