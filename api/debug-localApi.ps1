#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Debug the GrooveApp API container
    
.DESCRIPTION
    Comprehensive debugging script to troubleshoot container and database connection issues
    
.EXAMPLE
    .\debug-localApi.ps1
#>

param(
    [switch]$Interactive
)

$containerName = "grooveapp-api-local"

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

# Check if container is running
Write-Section "Container Status"
$containerStatus = docker ps -a --filter "name=$containerName" --format "{{.Status}}"
if (-not $containerStatus) {
    Write-ColorOutput Red "❌ Container '$containerName' not found!"
    Write-ColorOutput Yellow "Run: .\build-localApi.ps1 -Rebuild"
    exit 1
}

if ($containerStatus -notlike "Up*") {
    Write-ColorOutput Red "❌ Container is not running: $containerStatus"
    Write-ColorOutput Yellow "Start with: docker start $containerName"
    exit 1
}

Write-ColorOutput Green "✓ Container is running"

# Check environment variables
Write-Section "Environment Variables"
Write-ColorOutput Yellow "Checking SQL_SERVER, SQL_DATABASE, AZURE_ACCESS_TOKEN..."
$env_vars = docker exec $containerName env | Select-String -Pattern "SQL_|AZURE_ACCESS_TOKEN"

if ($env_vars) {
    foreach ($var in $env_vars) {
        $varStr = $var.ToString()
        if ($varStr -like "*AZURE_ACCESS_TOKEN*") {
            # Don't display the full token
            if ($varStr -match "AZURE_ACCESS_TOKEN=(.+)") {
                $tokenLength = $matches[1].Length
                Write-ColorOutput Green "AZURE_ACCESS_TOKEN=<set, $tokenLength chars>"
            }
        }
        else {
            Write-ColorOutput Green $varStr
        }
    }
}
else {
    Write-ColorOutput Red "❌ No SQL environment variables found!"
}

# Check ODBC drivers
Write-Section "ODBC Drivers"
Write-ColorOutput Yellow "Checking installed ODBC drivers..."

# 1. Check odbcinst -q -d output
$drivers = docker exec $containerName odbcinst -q -d 2>&1

if ($LASTEXITCODE -eq 0) {
    if ($drivers) {
        Write-ColorOutput Cyan "Registered drivers:"
        Write-ColorOutput Green $drivers
        
        # Check for required drivers
        if ($drivers -like "*ODBC Driver 18 for SQL Server*") {
            Write-ColorOutput Green "✓ ODBC Driver 18 for SQL Server registered"
        }
        elseif ($drivers -like "*ODBC Driver 17 for SQL Server*") {
            Write-ColorOutput Yellow "⚠ Only ODBC Driver 17 registered (Driver 18 recommended)"
        }
        else {
            Write-ColorOutput Red "❌ No SQL Server ODBC drivers registered!"
        }
    }
    else {
        Write-ColorOutput Red "❌ No ODBC drivers registered!"
    }
}
else {
    Write-ColorOutput Red "❌ Failed to query ODBC drivers: $drivers"
}

# 2. Check unixODBC configuration files
Write-ColorOutput Yellow "`nChecking unixODBC configuration..."
$odbciniFiles = docker exec $containerName sh -c "ls -la /etc/odbc* 2>/dev/null || echo 'No ODBC config files'"
Write-ColorOutput White $odbciniFiles

# 3. Check for actual driver library files
Write-ColorOutput Yellow "`nChecking driver library files..."
$driverLibs = docker exec $containerName sh -c @"
echo '=== Checking /opt/microsoft/msodbcsql* ===' &&
ls -la /opt/microsoft/msodbcsql* 2>/dev/null || echo 'Directory not found' &&
echo '' &&
echo '=== Checking for .so files ===' &&
find /opt/microsoft -name '*.so*' 2>/dev/null || echo 'No .so files found'
"@ 2>&1
Write-ColorOutput White $driverLibs

# 4. Verify libmsodbcsql is loadable
Write-ColorOutput Yellow "`nTesting if driver libraries can be loaded..."
$ldconfig = docker exec $containerName sh -c "ldconfig -p | grep -i odbc || echo 'No ODBC libraries in ld cache'"
Write-ColorOutput White $ldconfig

# 5. Check pyodbc's view of drivers
Write-ColorOutput Yellow "`nChecking drivers from pyodbc..."
$pyodbcDrivers = docker exec $containerName python3 -c @"
import pyodbc
print('Available drivers from pyodbc:')
for driver in pyodbc.drivers():
    print(f'  - {driver}')
"@ 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput Green $pyodbcDrivers
}
else {
    Write-ColorOutput Red "❌ Failed to query pyodbc drivers: $pyodbcDrivers"
}

# Check Python packages
Write-Section "Python Dependencies"
Write-ColorOutput Yellow "Checking pyodbc installation..."
$pyodbc = docker exec $containerName python3 -c "import pyodbc; print(f'pyodbc {pyodbc.version}')" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput Green "✓ $pyodbc"
}
else {
    Write-ColorOutput Red "❌ pyodbc not found or error: $pyodbc"
}

# Test database connection
Write-Section "Database Connection Test"
Write-ColorOutput Yellow "Testing database connection..."

$connectionTest = docker exec $containerName python3 -c @"
import os
import sys

sql_server = os.environ.get('SQL_SERVER')
sql_database = os.environ.get('SQL_DATABASE')

print(f'Target: {sql_server}/{sql_database}')
print(f'Token present: {"Yes" if os.environ.get("AZURE_ACCESS_TOKEN") else "No"}')

try:
    import pyodbc
    
    # Show what drivers pyodbc can see
    print(f'\nDrivers available to pyodbc: {pyodbc.drivers()}')
    
    from main import get_db_connection
    
    print('\nAttempting connection...')
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT @@VERSION')
    version = cursor.fetchone()[0]
    print('\nSUCCESS: Connected to database')
    print(f'SQL Server Version: {version[:60]}...')
    cursor.close()
    conn.close()
except Exception as e:
    print(f'\nFAILED: {str(e)}')
    print(f'Error type: {type(e).__name__}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"@ 2>&1

Write-Output $connectionTest

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput Green "`n✓ Database connection successful!"
}
else {
    Write-ColorOutput Red "`n❌ Database connection failed!"
    Write-ColorOutput Yellow "`nCommon causes:"
    Write-ColorOutput White "  1. ODBC driver not properly installed/registered"
    Write-ColorOutput White "  2. Driver library files not found by unixODBC"
    Write-ColorOutput White "  3. Firewall blocking connection"
    Write-ColorOutput White "  4. Database user permissions not configured"
    Write-ColorOutput White "  5. Token expired or invalid"
}

# Check API health endpoint
Write-Section "API Health Check"
Write-ColorOutput Yellow "Testing /health endpoint..."

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction Stop
    $health = $response.Content | ConvertFrom-Json
    
    Write-ColorOutput Green "Status Code: $($response.StatusCode)"
    Write-Output ($health | ConvertTo-Json -Depth 10)
    
    if ($health.status -eq "healthy") {
        Write-ColorOutput Green "`n✓ API is healthy!"
    }
    else {
        Write-ColorOutput Red "`n❌ API is unhealthy: $($health.status)"
    }
}
catch {
    Write-ColorOutput Red "❌ Failed to reach health endpoint: $_"
}

# View recent logs
Write-Section "Recent Container Logs (last 50 lines)"
docker logs --tail 50 $containerName

# Interactive shell option
if ($Interactive) {
    Write-Section "Interactive Shell"
    Write-ColorOutput Yellow "Opening interactive shell in container (type 'exit' to quit)..."
    docker exec -it $containerName /bin/bash
}
else {
    Write-ColorOutput Cyan "`nFor interactive debugging, run:"
    Write-ColorOutput White "  .\debug-localApi.ps1 -Interactive"
    Write-ColorOutput Cyan "`nOr manually:"
    Write-ColorOutput White "  docker exec -it $containerName /bin/bash"
}
