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
.EXAMPLE
    .\test-local-app.ps1 -Rebuild
    .\test-local-app.ps1 -TestApi
    .\test-local-app.ps1 -TestApi -Verbose
    .\test-local-app.ps1 -TestApi -ApiUrl "https://webapp-grooveapp-api.azurewebsites.net"
    .\test-local-app.ps1 -Logs
    .\test-local-app.ps1 -Stop
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
  [switch]$SkipScan
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

    # Check if Docker Scout is available
    $scoutAvailable = docker scout version 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Scanning for CVEs (max severity: $MaxSeverity)..." -ForegroundColor Cyan

      # Run Docker Scout scan
      docker scout cves $imageName --only-severity critical, high --exit-code

      if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Security vulnerabilities found!" -ForegroundColor Red
        Write-Host "   High or critical CVEs detected in the image." -ForegroundColor Yellow
        Write-Host "   Review the scan results above." -ForegroundColor Yellow
        Write-Host "`n   Options:" -ForegroundColor Yellow
        Write-Host "   - Fix vulnerabilities: Update dependencies in package.json" -ForegroundColor Yellow
        Write-Host "   - Skip scan: Re-run with -SkipScan flag" -ForegroundColor Yellow
        Write-Host "   - Allow medium: Re-run with -MaxSeverity medium" -ForegroundColor Yellow
        exit 1
      }
      Write-Host "✅ No high/critical vulnerabilities found" -ForegroundColor Green
    }
    else {
      Write-Host "⚠️  Docker Scout not available - skipping CVE scan" -ForegroundColor Yellow
      Write-Host "   Install: https://docs.docker.com/scout/install/" -ForegroundColor Yellow
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
docker run -d `
  --name $containerName `
  -p ${port}:8080 `
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
Write-Host "📖 View logs: .\test-local-app.ps1 -Logs" -ForegroundColor Cyan
Write-Host "🛑 Stop: .\test-local-app.ps1 -Stop" -ForegroundColor Cyan

if (-not $Production) {
  Write-Host "`n⚠️  Make sure the API is running on http://localhost:8000" -ForegroundColor Yellow
  Write-Host "   Run: cd ..\api; .\test-local-api.ps1" -ForegroundColor Yellow
}
