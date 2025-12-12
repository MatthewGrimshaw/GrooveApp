#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build, scan, and test the Groove App API locally in Docker
    
.DESCRIPTION
    Comprehensive script for local Docker development:
    1. Build Docker image
    2. Scan for security vulnerabilities (optional)
    3. Run container with Azure authentication
    4. Test API endpoints
    
.PARAMETER Rebuild
    Build the Docker image (includes security scan)
    
.PARAMETER MaxSeverity
    Maximum allowed vulnerability severity: critical, high, medium, low
    Default: high (blocks critical and high)
    
.PARAMETER SkipScan
    Skip vulnerability scanning during build (not recommended)
    
.PARAMETER Logs
    Show container logs
    
.PARAMETER Stop
    Stop and remove the container
    
.PARAMETER NoBuild
    Start container without rebuilding (uses existing image)
    
.EXAMPLE
    .\test-local-api.ps1 -Rebuild
    .\test-local-api.ps1 -Rebuild -MaxSeverity critical
    .\test-local-api.ps1 -Rebuild -SkipScan
    .\test-local-api.ps1 -NoBuild
    .\test-local-api.ps1 -Logs
    .\test-local-api.ps1 -Stop
#>

param(
    [switch]$Rebuild,
    [ValidateSet("critical", "high", "medium", "low")]
    [string]$MaxSeverity = "high",
    [switch]$SkipScan,
    [switch]$Logs,
    [switch]$Stop,
    [switch]$NoBuild
)

$containerName = "grooveapp-api-local"
$imageName = "grooveapp-api"
$port = 8000

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($Message) {
        Write-Output $Message
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Section($Title) {
    Write-ColorOutput Cyan "`n================================================"
    Write-ColorOutput Cyan $Title
    Write-ColorOutput Cyan "================================================`n"
}

# Handle utility commands
if ($Stop) {
    Write-ColorOutput Yellow "Stopping container..."
    docker stop $containerName 2>$null
    docker rm $containerName 2>$null
    Write-ColorOutput Green "✅ Container stopped and removed"
    exit 0
}

if ($Logs) {
    Write-ColorOutput Yellow "Showing logs (Ctrl+C to exit)..."
    docker logs -f $containerName
    exit 0
}

# Build image if requested
if ($Rebuild) {
    Write-Section "Building Docker Image: $imageName"
    
    docker build -t $imageName .
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "❌ Docker build failed"
        exit 1
    }
    
    Write-ColorOutput Green "✅ Docker image built successfully"
    
    # Security scan
    if (-not $SkipScan) {
        Write-Section "Scanning for Security Vulnerabilities (Max: $MaxSeverity)"
        
        # Get summary
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
        
        Write-ColorOutput Cyan "Vulnerability Summary:"
        Write-ColorOutput $(if ($criticalCount -gt 0) { "Red" } else { "Green" }) "  Critical: $criticalCount"
        Write-ColorOutput $(if ($highCount -gt 0) { "Red" } else { "Green" }) "  High:     $highCount"
        Write-ColorOutput $(if ($mediumCount -gt 0) { "Yellow" } else { "Green" }) "  Medium:   $mediumCount"
        Write-ColorOutput Green "  Low:      $lowCount"
        
        # Check threshold
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
            Write-ColorOutput Red "`n❌ SECURITY SCAN FAILED: $failReason"
            Write-ColorOutput Yellow "To fix: docker scout recommendations $imageName"
            Write-ColorOutput Yellow "To override: .\test-local-api.ps1 -Rebuild -MaxSeverity medium"
            exit 1
        } else {
            Write-ColorOutput Green "✅ Security scan passed (max severity: $MaxSeverity)"
        }
    } else {
        Write-ColorOutput Yellow "⚠️  Security scan skipped"
    }
}

# Check if we should start container
if ($NoBuild -or $Rebuild) {
    # Check if container is already running
    $existing = docker ps -q -f name=$containerName
    if ($existing) {
        Write-ColorOutput Yellow "Container already running. Stopping first..."
        docker stop $containerName 2>$null
        docker rm $containerName 2>$null
    }
    
    Write-Section "Starting Container"
    
    # Get access token from Azure CLI
    Write-ColorOutput Yellow "Getting Azure access token..."
    try {
        $tokenJson = az account get-access-token --resource https://database.windows.net/ --query accessToken -o json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Red "❌ Failed to get access token. Please run 'az login' first."
            exit 1
        }
        $token = $tokenJson | ConvertFrom-Json
        Write-ColorOutput Green "✅ Access token obtained"
    } catch {
        Write-ColorOutput Red "❌ Error getting access token: $_"
        exit 1
    }
    
    # Start container with token
    Write-ColorOutput Yellow "Starting container..."
    docker run -d `
        --name $containerName `
        -p ${port}:8000 `
        -e SQL_SERVER="sql-grooveapp.database.windows.net" `
        -e SQL_DATABASE="db-grooveapp" `
        -e AZURE_ACCESS_TOKEN="$token" `
        $imageName
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "❌ Failed to start container"
        exit 1
    }
    
    Write-ColorOutput Green "✅ Container started successfully"
    
    # Wait for API to be ready
    Write-Section "Testing API"
    Write-ColorOutput Yellow "Waiting for API to be ready..."
    Start-Sleep -Seconds 3
    
    $maxRetries = 10
    $retryCount = 0
    $healthy = $false
    
    while ($retryCount -lt $maxRetries -and -not $healthy) {
        try {
            # Test the root endpoint
            $response = Invoke-WebRequest -Uri "http://localhost:$port/" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $healthy = $true
                Write-ColorOutput Green "✅ API is responding!"
                Write-Output $response.Content
                
                # Also test health endpoint
                try {
                    $healthResponse = Invoke-WebRequest -Uri "http://localhost:$port/health" -TimeoutSec 2 -ErrorAction Stop
                    Write-ColorOutput Green "✅ Database connection: Healthy"
                } catch {
                    Write-ColorOutput Yellow "⚠️  Database connection: Not configured (expected for local testing)"
                }
            }
        } catch {
            $retryCount++
            Write-ColorOutput Yellow "Waiting... (attempt $retryCount/$maxRetries)"
            Start-Sleep -Seconds 2
        }
    }
    
    if (-not $healthy) {
        Write-ColorOutput Red "❌ API failed to start. Check logs with: .\test-local-api.ps1 -Logs"
        exit 1
    }
    
    Write-Section "Local API Ready"
    Write-ColorOutput Green @"
API is running at: http://localhost:$port

Test endpoints:
  http://localhost:$port/          - Service info
  http://localhost:$port/health    - Health check
  http://localhost:$port/notes     - All notes
  http://localhost:$port/intervals - All intervals
  http://localhost:$port/scales    - All scales

Management:
  .\test-local-api.ps1 -Logs       - View logs
  .\test-local-api.ps1 -Stop       - Stop container
  .\test-local-api.ps1 -Rebuild    - Rebuild and restart
"@
} else {
    Write-ColorOutput Red "❌ No action specified. Use -Rebuild, -NoBuild, -Logs, or -Stop"
    Write-ColorOutput Yellow @"

Usage:
  .\test-local-api.ps1 -Rebuild              # Build, scan, and run
  .\test-local-api.ps1 -Rebuild -SkipScan    # Build and run (skip scan)
  .\test-local-api.ps1 -NoBuild              # Run existing image
  .\test-local-api.ps1 -Logs                 # View logs
  .\test-local-api.ps1 -Stop                 # Stop container
"@
    exit 1
}
