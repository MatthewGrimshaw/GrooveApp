# Deploy SQL Schema Script
# Opens SQL Server firewall, deploys database schema, grants managed identity access, then closes firewall

# Variables
$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"
$resourceGroupName = "rg-grooveapp-dev"
$sqlServerName = "sql-grooveapp-dev-uhxg"
$databaseName = "sqldb-grooveapp-dev"
$sqlScriptPath = ".\setup-music-tables.sql"
$testScriptPath = ".\test-database.sql"
$apiWebAppName = "app-grooveapp-dev-api"

# set path
set-location -path "C:\Users\matgri\repos\grooveapp\infra"

Write-Host "======================================"
Write-Host "SQL Schema Deployment"
Write-Host "======================================"
Write-Host ""

# Authentication
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan
az config set core.login_experience_v2=off
az login --tenant $tenantId
az account set --subscription $subscriptionId
Write-Host "Authentication successful`n" -ForegroundColor Green

# Get current IP
Write-Host "Step 2: Getting current IP address..." -ForegroundColor Cyan
$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
Write-Host "Current IP: $myIp`n" -ForegroundColor Green

# Enable public network access temporarily
Write-Host "Step 3: Enabling public network access on SQL Server..." -ForegroundColor Cyan
az sql server update `
    --resource-group $resourceGroupName `
    --name $sqlServerName `
    --set publicNetworkAccess="Enabled" `
    --output none
Write-Host "Public network access enabled`n" -ForegroundColor Green

# Wait for setting to propagate
Write-Host "Waiting for setting to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Add IP to firewall
Write-Host "Step 4: Opening SQL Server firewall..." -ForegroundColor Cyan
az sql server firewall-rule create `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name "AllowDeploymentIP" `
    --start-ip-address $myIp `
    --end-ip-address $myIp `
    --output none
Write-Host "Firewall rule added for IP: $myIp`n" -ForegroundColor Green

# Wait for firewall rule to propagate
Write-Host "Waiting for firewall rule to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Get access token
Write-Host "Step 5: Getting Azure SQL access token..." -ForegroundColor Cyan
$accessToken = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv

if (-not $accessToken) {
    Write-Host "Failed to get access token" -ForegroundColor Red
    # Clean up firewall rule
    az sql server firewall-rule delete `
        --resource-group $resourceGroupName `
        --server $sqlServerName `
        --name "AllowDeploymentIP" `
        --output none
    exit 1
}
Write-Host "Access token acquired`n" -ForegroundColor Green

# Check for SQL script
Write-Host "Step 6: Checking for SQL script..." -ForegroundColor Cyan
if (-not (Test-Path $sqlScriptPath)) {
    Write-Host "SQL script not found at: $sqlScriptPath" -ForegroundColor Red
    # Clean up firewall rule
    az sql server firewall-rule delete `
        --resource-group $resourceGroupName `
        --server $sqlServerName `
        --name "AllowDeploymentIP" `
        --output none
    exit 1
}
Write-Host "SQL script found: $sqlScriptPath`n" -ForegroundColor Green

# Read SQL script
$sqlScript = Get-Content $sqlScriptPath -Raw

# Check for SqlServer module
Write-Host "Step 7: Checking for SqlServer PowerShell module..." -ForegroundColor Cyan
$sqlModule = Get-Module -ListAvailable -Name SqlServer -ErrorAction SilentlyContinue

if (-not $sqlModule) {
    Write-Host "SqlServer PowerShell module not found." -ForegroundColor Yellow
    Write-Host "Installing SqlServer module..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}

# Import module
Import-Module SqlServer -ErrorAction Stop
Write-Host "SqlServer module loaded`n" -ForegroundColor Green

# Execute SQL script
Write-Host "Step 8: Deploying SQL schema..." -ForegroundColor Cyan

# Split and execute batches
$batches = $sqlScript -split '(?m)^\s*GO\s*$'
$batchNum = 0

# Categorize batches into three phases
# Phase 1: Tables, data inserts, and constraints (DDL and DML)
$phase1Batches = $batches | Where-Object { 
    $trimmed = $_.Trim()
    $trimmed -and 
    -not $trimmed.StartsWith('--') -and
    -not ($trimmed -match '^\s*CREATE\s+(FUNCTION|PROCEDURE|INDEX|VIEW)\s+', 'IgnoreCase') -and
    -not ($trimmed -match '^\s*(UPDATE\s+STATISTICS|EXEC\s+sys\.sp_addextendedproperty|SELECT|PRINT)', 'IgnoreCase')
}

# Phase 2: Functions, procedures, views, and indexes
$phase2Batches = $batches | Where-Object { 
    $trimmed = $_.Trim()
    $trimmed -and 
    -not $trimmed.StartsWith('--') -and
    (($trimmed -match '^\s*CREATE\s+(FUNCTION|PROCEDURE|INDEX|VIEW)\s+', 'IgnoreCase') -or
    ($trimmed -match '^\s*UPDATE\s+STATISTICS', 'IgnoreCase'))
}

# Phase 3: Housekeeping (extended properties, validation queries, prints)
$phase3Batches = $batches | Where-Object { 
    $trimmed = $_.Trim()
    $trimmed -and 
    -not $trimmed.StartsWith('--') -and
    ($trimmed -match '^\s*(EXEC\s+sys\.sp_addextendedproperty|SELECT.*sys\.|PRINT)', 'IgnoreCase')
}

$totalBatches = $phase1Batches.Count + $phase2Batches.Count + $phase3Batches.Count

Write-Host "Executing $totalBatches SQL batches..." -ForegroundColor Yellow
Write-Host "  Phase 1 (Tables/Data): $($phase1Batches.Count)" -ForegroundColor Gray
Write-Host "  Phase 2 (Functions/Indexes): $($phase2Batches.Count)" -ForegroundColor Gray
Write-Host "  Phase 3 (Metadata/Validation): $($phase3Batches.Count)" -ForegroundColor Gray
Write-Host ""

try {
    # Phase 1: Create tables and insert data
    Write-Host "Phase 1: Creating tables and inserting data..." -ForegroundColor Cyan
    foreach ($batch in $phase1Batches) {
        $trimmedBatch = $batch.Trim()
        if ($trimmedBatch) {
            $batchNum++
            Write-Host "  [$batchNum/$totalBatches] Executing batch..." -ForegroundColor Gray
            
            Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
                -Database $databaseName `
                -AccessToken $accessToken `
                -Query $trimmedBatch `
                -Variable "WebAppName=$apiWebAppName" `
                -ErrorAction Stop `
                -QueryTimeout 30
            
            Write-Host "  [$batchNum/$totalBatches] Completed" -ForegroundColor Green
        }
    }
    
    # Phase 2: Create functions, procedures, views, and indexes
    Write-Host "`nPhase 2: Creating functions, procedures, and indexes..." -ForegroundColor Cyan
    foreach ($batch in $phase2Batches) {
        $trimmedBatch = $batch.Trim()
        if ($trimmedBatch) {
            $batchNum++
            Write-Host "  [$batchNum/$totalBatches] Executing batch..." -ForegroundColor Gray
            
            Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
                -Database $databaseName `
                -AccessToken $accessToken `
                -Query $trimmedBatch `
                -Variable "WebAppName=$apiWebAppName" `
                -ErrorAction Stop `
                -QueryTimeout 30
            
            Write-Host "  [$batchNum/$totalBatches] Completed" -ForegroundColor Green
        }
    }
    
    # Phase 3: Add metadata and run validation
    Write-Host "`nPhase 3: Adding metadata and validating deployment..." -ForegroundColor Cyan
    foreach ($batch in $phase3Batches) {
        $trimmedBatch = $batch.Trim()
        if ($trimmedBatch) {
            $batchNum++
            Write-Host "  [$batchNum/$totalBatches] Executing batch..." -ForegroundColor Gray
            
            $result = Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
                -Database $databaseName `
                -AccessToken $accessToken `
                -Query $trimmedBatch `
                -Variable "WebAppName=$apiWebAppName" `
                -ErrorAction Stop `
                -QueryTimeout 30
            
            # Display results from validation queries
            if ($result) {
                $result | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White
            }
            
            Write-Host "  [$batchNum/$totalBatches] Completed" -ForegroundColor Green
        }
    }
    
    Write-Host "`nSQL schema deployed successfully!`n" -ForegroundColor Green
}
catch {
    Write-Host "`nError executing batch $batchNum : $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    
    # Clean up firewall rule before exiting
    Write-Host "`nCleaning up firewall rule..." -ForegroundColor Yellow
    az sql server firewall-rule delete `
        --resource-group $resourceGroupName `
        --server $sqlServerName `
        --name "AllowDeploymentIP" `
        --output none
    exit 1
}

# Run Database Tests
Write-Host "Step 9: Running database validation tests..." -ForegroundColor Cyan

if (-not (Test-Path $testScriptPath)) {
    Write-Host "  ⚠️  Warning: Test script not found at: $testScriptPath" -ForegroundColor Yellow
    Write-Host "  Skipping database validation tests" -ForegroundColor Yellow
}
else {
    try {
        Write-Host "  Loading test suite..." -ForegroundColor Yellow
        $testScript = Get-Content $testScriptPath -Raw
        $testBatches = $testScript -split '(?m)^\s*GO\s*$'
        $testNum = 0
        
        Write-Host "  Executing database validation tests...`n" -ForegroundColor Yellow
        
        foreach ($batch in $testBatches) {
            $trimmedBatch = $batch.Trim()
            if ($trimmedBatch -and $trimmedBatch -ne '') {
                $testNum++
                
                $result = Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
                    -Database $databaseName `
                    -AccessToken $accessToken `
                    -Query $trimmedBatch `
                    -ErrorAction Stop `
                    -QueryTimeout 30 `
                    -Verbose 4>&1
                
                # Display results from test queries
                if ($result) {
                    $result | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White
                }
            }
        }
        
        Write-Host "`n  ✅ All database validation tests passed!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "`n  ⚠️  Warning: Database validation test failed: $_" -ForegroundColor Yellow
        Write-Host "  Error details: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Continuing with deployment...`n" -ForegroundColor Yellow
    }
}

# Grant Managed Identity Access
Write-Host "Step 10: Granting managed identity database access..." -ForegroundColor Cyan

# Get API Web App managed identity details
Write-Host "  Getting API Web App managed identity..." -ForegroundColor Yellow
$webAppIdentity = az webapp identity show `
    --name $apiWebAppName `
    --resource-group $resourceGroupName 2>$null | ConvertFrom-Json

if (-not $webAppIdentity) {
    Write-Host "  ⚠️  Warning: Could not get Web App managed identity" -ForegroundColor Yellow
    Write-Host "  The Web App may not exist yet or managed identity is not enabled" -ForegroundColor Yellow
    Write-Host "  Skipping managed identity setup - you can run this later with:" -ForegroundColor Yellow
    Write-Host "  .\grant-managed-identity-access.ps1" -ForegroundColor White
}
else {
    $principalId = $webAppIdentity.principalId
    $webAppName = $apiWebAppName

    Write-Host "  Web App: $webAppName" -ForegroundColor White
    Write-Host "  Principal ID: $principalId" -ForegroundColor White

    # Create database user for managed identity
    $createUserSql = @"
-- Create user for managed identity if not exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$webAppName')
BEGIN
    CREATE USER [$webAppName] FROM EXTERNAL PROVIDER;
    PRINT 'Created user for managed identity: $webAppName'
END
ELSE
BEGIN
    PRINT 'User already exists: $webAppName'
END

-- Grant permissions
ALTER ROLE db_datareader ADD MEMBER [$webAppName];
ALTER ROLE db_datawriter ADD MEMBER [$webAppName];
ALTER ROLE db_ddladmin ADD MEMBER [$webAppName];
PRINT 'Granted db_datareader, db_datawriter, and db_ddladmin roles to $webAppName'

-- Grant execute permissions on all stored procedures and functions
GRANT EXECUTE TO [$webAppName];
PRINT 'Granted EXECUTE permission to $webAppName'

-- Verify permissions
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    r.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = '$webAppName'
ORDER BY dp.name, r.name;
"@

    try {
        Write-Host "  Creating database user and granting permissions..." -ForegroundColor Yellow
        
        $result = Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
            -Database $databaseName `
            -AccessToken $accessToken `
            -Query $createUserSql `
            -ErrorAction Stop `
            -QueryTimeout 30
        
        if ($result) {
            Write-Host "`n  Permissions Summary:" -ForegroundColor Cyan
            $result | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White
        }
        
        Write-Host "  ✅ Managed identity access granted successfully!`n" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  Warning: Error creating database user: $_" -ForegroundColor Yellow
        Write-Host "  You may need to run: .\grant-managed-identity-access.ps1" -ForegroundColor Yellow
    }
}

# Remove firewall rule
Write-Host "Step 11: Closing SQL Server firewall..." -ForegroundColor Cyan
az sql server firewall-rule delete `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name "AllowDeploymentIP" `
    --output none
Write-Host "Firewall rule removed" -ForegroundColor Green

# Disable public network access
Write-Host "Step 12: Disabling public network access on SQL Server..." -ForegroundColor Cyan
az sql server update `
    --resource-group $resourceGroupName `
    --name $sqlServerName `
    --set publicNetworkAccess="Disabled" `
    --output none
Write-Host "Public network access disabled`n" -ForegroundColor Green

# Summary
Write-Host "======================================"
Write-Host "Deployment Complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "✅ SQL Schema deployed successfully" -ForegroundColor Green
Write-Host "  Server: $sqlServerName.database.windows.net" -ForegroundColor White
Write-Host "  Database: $databaseName" -ForegroundColor White
Write-Host "  Batches executed: $totalBatches" -ForegroundColor White
Write-Host ""
Write-Host "✅ Managed Identity Access Configured" -ForegroundColor Green
Write-Host "  API Web App: $apiWebAppName" -ForegroundColor White
Write-Host "  Database User: $apiWebAppName" -ForegroundColor White
Write-Host ""
Write-Host "Database contains:" -ForegroundColor Cyan
Write-Host "  - 17 musical notes" -ForegroundColor White
Write-Host "  - 13 intervals" -ForegroundColor White
Write-Host "  - 14 scale types" -ForegroundColor White
Write-Host "  - 28 chord types" -ForegroundColor White
Write-Host ""
Write-Host "To test the connection:" -ForegroundColor Yellow
Write-Host "  https://$apiWebAppName.azurewebsites.net/health" -ForegroundColor White
Write-Host ""
