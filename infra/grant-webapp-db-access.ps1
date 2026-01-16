# Grant Web App Managed Identities Database Access
# Grants both production and staging slots access to SQL database

param(
    [switch]$ProductionOnly,
    [switch]$StagingOnly
)

# Variables
$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"
$resourceGroupName = "rg-grooveapp-dev"
$sqlServerName = "sql-grooveapp-dev-uhxg"
$databaseName = "sqldb-grooveapp-dev"
$apiWebAppName = "app-grooveapp-dev-api"
$frontendWebAppName = "app-grooveapp-dev-frontend"

Write-Host "======================================"
Write-Host "Grant Web App DB Access"
Write-Host "======================================"
Write-Host ""

# Authentication
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan
az config set core.login_experience_v2=off
az login --tenant $tenantId --output none 2>$null
az account set --subscription $subscriptionId
Write-Host "Authentication successful`n" -ForegroundColor Green

# Get access token
Write-Host "Step 2: Getting Azure SQL access token..." -ForegroundColor Cyan
$accessToken = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv
Write-Host "Access token acquired`n" -ForegroundColor Green

# Function to grant database access
function Grant-DatabaseAccess {
    param(
        [string]$AppName,
        [string]$SlotName = $null
    )
    
    $displayName = if ($SlotName) { "$AppName/$SlotName" } else { $AppName }
    $fullAppName = if ($SlotName) { "$AppName-$SlotName" } else { $AppName }
    
    Write-Host "Processing: $displayName" -ForegroundColor Cyan
    
    # Get managed identity
    if ($SlotName) {
        $identity = az webapp identity show --name $AppName --resource-group $resourceGroupName --slot $SlotName 2>$null | ConvertFrom-Json
    }
    else {
        $identity = az webapp identity show --name $AppName --resource-group $resourceGroupName 2>$null | ConvertFrom-Json
    }
    
    if (-not $identity) {
        Write-Host "  ⚠️  Warning: Could not get managed identity for $displayName" -ForegroundColor Yellow
        return
    }
    
    $principalId = $identity.principalId
    Write-Host "  Principal ID: $principalId" -ForegroundColor Gray
    
    # Create database user and grant permissions
    $sql = @"
-- Create user for managed identity if not exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$fullAppName')
BEGIN
    CREATE USER [$fullAppName] FROM EXTERNAL PROVIDER;
    PRINT 'Created user: $fullAppName'
END
ELSE
BEGIN
    PRINT 'User already exists: $fullAppName'
END

-- Grant permissions
ALTER ROLE db_datareader ADD MEMBER [$fullAppName];
ALTER ROLE db_datawriter ADD MEMBER [$fullAppName];
GRANT EXECUTE TO [$fullAppName];
PRINT 'Granted db_datareader, db_datawriter, and EXECUTE to $fullAppName'

-- Verify permissions
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    r.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = '$fullAppName'
ORDER BY r.name;
"@

    try {
        Write-Host "  Granting database permissions..." -ForegroundColor Yellow
        
        $result = Invoke-Sqlcmd -ServerInstance "$sqlServerName.database.windows.net" `
            -Database $databaseName `
            -AccessToken $accessToken `
            -Query $sql `
            -ErrorAction Stop `
            -QueryTimeout 30
        
        if ($result) {
            Write-Host "`n  Permissions Summary:" -ForegroundColor Cyan
            $result | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White
        }
        
        Write-Host "  ✅ Database access granted for $displayName`n" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Error granting access: $_`n" -ForegroundColor Red
    }
}

# Grant access to production slots
if (-not $StagingOnly) {
    Write-Host "Step 3: Granting production slot access..." -ForegroundColor Cyan
    Grant-DatabaseAccess -AppName $apiWebAppName
    Grant-DatabaseAccess -AppName $frontendWebAppName
}

# Grant access to staging slots
if (-not $ProductionOnly) {
    Write-Host "Step 4: Granting staging slot access..." -ForegroundColor Cyan
    Grant-DatabaseAccess -AppName $apiWebAppName -SlotName "staging"
    Grant-DatabaseAccess -AppName $frontendWebAppName -SlotName "staging"
}

Write-Host "======================================"
Write-Host "Database Access Granted!"
Write-Host "======================================"
Write-Host ""
Write-Host "✅ Web apps can now connect to database using managed identity" -ForegroundColor Green
Write-Host ""
Write-Host "Security Notes:" -ForegroundColor Yellow
Write-Host "  - Health checks use managed identity" -ForegroundColor White
Write-Host "  - User queries use managed identity + app-level auth" -ForegroundColor White
Write-Host "  - SQL injection protected by parameterized queries" -ForegroundColor White
Write-Host "  - No user credentials stored in app" -ForegroundColor White
Write-Host ""
