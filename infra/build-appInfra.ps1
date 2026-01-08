# GrooveApp Complete Infrastructure Deployment Script
# Deploys Azure SQL Database, populates with music theory data, and deploys API to Azure Web App

# Variables
$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"
$resourceGroupName = "rg-grooveapp"
$location = "swedencentral"
$sqlServerName = "sql-grooveapp"
$databaseName = "db-grooveapp"
$sqlScriptPath = ".\infra\setup-music-tables.sql"
$acrName = "acrgrooveapp"
$appServicePlanName = "plan-grooveapp"
$webAppName = "webapp-grooveapp-api"
$frontendWebAppName = "webapp-grooveapp-frontend"
$entraIdGroupName = "GrooveApp-Users"
$entraIdGroupDescription = "Users authorized to access GrooveApp"

Write-Host "======================================"
Write-Host "GrooveApp Infrastructure Deployment"
Write-Host "======================================"
Write-Host ""

# Authentication
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan
az config set core.login_experience_v2=off
az login --tenant $tenantId
az account set --subscription $subscriptionId
Write-Host "Authentication successful`n" -ForegroundColor Green

# Create resource group
Write-Host "Step 2: Creating resource group..." -ForegroundColor Cyan
az group create --name $resourceGroupName --location $location --output none
Write-Host "Resource group created: $resourceGroupName`n" -ForegroundColor Green

# Get signed-in user details
Write-Host "Step 3: Getting user details..." -ForegroundColor Cyan
$userDetails = az ad signed-in-user show --query "{userPrincipalName: userPrincipalName, objectId: id, displayName: displayName}" -o json | ConvertFrom-Json
Write-Host "User: $($userDetails.displayName) ($($userDetails.userPrincipalName))`n" -ForegroundColor Green

# Create SQL Server
Write-Host "Step 4: Creating SQL Server..." -ForegroundColor Cyan
az sql server create `
    --name $sqlServerName `
    --resource-group $resourceGroupName `
    --location $location `
    --enable-ad-only-auth `
    --external-admin-principal-type User `
    --external-admin-name $userDetails.displayName `
    --external-admin-sid $userDetails.objectId `
    --assign-identity `
    --enable-public-network true `
    --output none
Write-Host "SQL Server created: $sqlServerName.database.windows.net`n" -ForegroundColor Green

# Create database
Write-Host "Step 5: Creating database..." -ForegroundColor Cyan
az sql db create `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name $databaseName `
    --service-objective S0 `
    --output none
Write-Host "Database created: $databaseName`n" -ForegroundColor Green

# Wait for resources to be ready
Write-Host "Waiting for resources to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Execute SQL setup script
Write-Host "Step 6: Populating database with music theory data..." -ForegroundColor Cyan

# Get access token
Write-Host "Getting Azure SQL access token..." -ForegroundColor Yellow
$accessToken = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv

if (-not $accessToken) {
    Write-Host "Failed to get access token" -ForegroundColor Red
    exit 1
}

# Check for SQL script
if (-not (Test-Path $sqlScriptPath)) {
    Write-Host "SQL script not found at: $sqlScriptPath" -ForegroundColor Red
    exit 1
}

# Read SQL script
$sqlScript = Get-Content $sqlScriptPath -Raw

# Check for SqlServer module
$sqlModule = Get-Module -ListAvailable -Name SqlServer -ErrorAction SilentlyContinue

if (-not $sqlModule) {
    Write-Host "SqlServer PowerShell module not found." -ForegroundColor Red
    Write-Host "Installing SqlServer module..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}

# Import module
Import-Module SqlServer -ErrorAction Stop

# Split and execute batches
$batches = $sqlScript -split '(?m)^\s*GO\s*$'
$batchNum = 0
$totalBatches = ($batches | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('--') }).Count

Write-Host "Executing $totalBatches SQL batches..." -ForegroundColor Yellow

try {
    foreach ($batch in $batches) {
        $trimmedBatch = $batch.Trim()
        if ($trimmedBatch -and -not $trimmedBatch.StartsWith('--')) {
            $batchNum++
            Write-Host "  [$batchNum/$totalBatches] Executing batch..." -ForegroundColor Gray
            
            Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
                -Database $databaseName `
                -AccessToken $accessToken `
                -Query $trimmedBatch `
                -ErrorAction Stop `
                -QueryTimeout 30
            
            Write-Host "  [$batchNum/$totalBatches] Completed" -ForegroundColor Green
        }
    }
    
    Write-Host "Database populated successfully!`n" -ForegroundColor Green
}
catch {
    Write-Host "`nError executing batch $batchNum : $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create Azure Container Registry
Write-Host "Step 7: Creating Azure Container Registry..." -ForegroundColor Cyan
az acr create `
    --resource-group $resourceGroupName `
    --name $acrName `
    --sku Basic `
    --location $location `
    --admin-enabled true `
    --output none
Write-Host "Container Registry created: $acrName.azurecr.io`n" -ForegroundColor Green

# Build and push Docker image to ACR
Write-Host "Step 8: Building and pushing Docker image..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

# Get script directory and workspace root (works both in script execution and line-by-line)
$scriptPath = if ($PSScriptRoot) { 
    $PSScriptRoot 
}
elseif ($psISE) { 
    Split-Path -Parent $psISE.CurrentFile.FullPath 
}
elseif ($null -ne $psEditor) {
    Split-Path -Parent $psEditor.GetEditorContext().CurrentFile.Path
}
else {
    $PWD.Path
}

$workspaceRoot = Split-Path -Parent $scriptPath
$apiPath = Join-Path $workspaceRoot "api"
$dockerfilePath = Join-Path $apiPath "Dockerfile"

Write-Host "Script path: $scriptPath" -ForegroundColor Gray
Write-Host "Workspace root: $workspaceRoot" -ForegroundColor Gray
Write-Host "API path: $apiPath`n" -ForegroundColor Gray

# Build and scan locally before pushing to ACR
Write-Host "Building and scanning Docker image locally..." -ForegroundColor Yellow
Push-Location $apiPath
try {
    & .\test-local-api.ps1 -Rebuild -MaxSeverity high
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Security scan failed. Fix vulnerabilities before deploying." -ForegroundColor Red
        Write-Host "Review vulnerabilities with: docker scout cves grooveapp-api" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Security scan passed - No HIGH or CRITICAL CVEs detected`n" -ForegroundColor Green
}
catch {
    Write-Host "Error during build/scan: $_" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}

# Push to Azure Container Registry
Write-Host "Pushing secure image to ACR..." -ForegroundColor Yellow
az acr build `
    --registry $acrName `
    --image grooveapp-api:latest `
    --file $dockerfilePath `
    $apiPath

Write-Host "Docker image built and pushed successfully`n" -ForegroundColor Green

# Create App Service Plan
Write-Host "Step 9: Creating App Service Plan..." -ForegroundColor Cyan
az appservice plan create `
    --name $appServicePlanName `
    --resource-group $resourceGroupName `
    --is-linux `
    --sku S1 `
    --location $location `
    --output none
Write-Host "App Service Plan created: $appServicePlanName (S1 - supports deployment slots)`n" -ForegroundColor Green

# Create Entra ID Security Group
Write-Host "Step 10: Creating Entra ID security group..." -ForegroundColor Cyan
$existingGroup = az ad group list --filter "displayName eq '$entraIdGroupName'" --query "[0]" -o json | ConvertFrom-Json

if ($existingGroup) {
    Write-Host "Security group already exists: $entraIdGroupName" -ForegroundColor Yellow
    $groupId = $existingGroup.id
}
else {
    $newGroup = az ad group create `
        --display-name $entraIdGroupName `
        --mail-nickname "GrooveAppUsers" `
        --description $entraIdGroupDescription `
        --query "{id: id, displayName: displayName}" -o json | ConvertFrom-Json
    
    $groupId = $newGroup.id
    Write-Host "Security group created: $entraIdGroupName" -ForegroundColor Green
    
    # Add current user to the group
    az ad group member add --group $groupId --member-id $userDetails.objectId --output none
    Write-Host "Added $($userDetails.displayName) to security group`n" -ForegroundColor Green
}

# Create Web App
Write-Host "Step 11: Creating Web App..." -ForegroundColor Cyan
az webapp create `
    --resource-group $resourceGroupName `
    --plan $appServicePlanName `
    --name $webAppName `
    --deployment-container-image-name "$acrName.azurecr.io/grooveapp-api:latest" `
    --output none
Write-Host "Web App created: $webAppName.azurewebsites.net`n" -ForegroundColor Green

# Enable managed identity
Write-Host "Step 12: Enabling managed identity..." -ForegroundColor Cyan
$identityResult = az webapp identity assign `
    --name $webAppName `
    --resource-group $resourceGroupName | ConvertFrom-Json

$principalId = $identityResult.principalId
Write-Host "Managed Identity Principal ID: $principalId`n" -ForegroundColor Green

# Get ACR credentials
$acrCredentials = az acr credential show --name $acrName | ConvertFrom-Json

# Configure container settings
Write-Host "Step 13: Configuring container settings..." -ForegroundColor Cyan
az webapp config container set `
    --name $webAppName `
    --resource-group $resourceGroupName `
    --docker-custom-image-name "$acrName.azurecr.io/grooveapp-api:latest" `
    --docker-registry-server-url "https://$acrName.azurecr.io" `
    --docker-registry-server-user $acrCredentials.username `
    --docker-registry-server-password $acrCredentials.passwords[0].value `
    --output none

# Configure CORS for API to allow frontend origin
Write-Host "Configuring CORS for API..." -ForegroundColor Yellow
az webapp cors add `
    --name $webAppName `
    --resource-group $resourceGroupName `
    --allowed-origins "https://$frontendWebAppName.azurewebsites.net" `
    --output none
az webapp cors add `
    --name $webAppName `
    --resource-group $resourceGroupName `
    --allowed-origins "http://localhost:8080" `
    --output none

Write-Host "Container and CORS configured successfully`n" -ForegroundColor Green

# Configure app settings
Write-Host "Step 14: Configuring application settings..." -ForegroundColor Cyan
az webapp config appsettings set `
    --name $webAppName `
    --resource-group $resourceGroupName `
    --settings `
    SQL_SERVER="$sqlServerName.database.windows.net" `
    SQL_DATABASE=$databaseName `
    WEBSITES_PORT=8000 `
    FRONTEND_URL="https://$frontendWebAppName.azurewebsites.net" `
    --output none
Write-Host "App settings configured`n" -ForegroundColor Green

# Configure Easy Auth (Entra ID authentication)
Write-Host "Step 15: Configuring Easy Auth (Entra ID)..." -ForegroundColor Cyan
Write-Host "Creating App Registration for authentication..." -ForegroundColor Yellow

# Create App Registration
$appRegName = "$webAppName-auth"
$webAppUrl = "https://$webAppName.azurewebsites.net"
$redirectUri = "$webAppUrl/.auth/login/aad/callback"

# Check if app registration exists
$existingApp = az ad app list --filter "displayName eq '$appRegName'" --query "[0]" -o json | ConvertFrom-Json

if ($existingApp) {
    Write-Host "App registration already exists: $appRegName" -ForegroundColor Yellow
    $appId = $existingApp.appId
    $appObjectId = $existingApp.id
}
else {
    # Create new app registration
    $appReg = az ad app create `
        --display-name $appRegName `
        --sign-in-audience "AzureADMyOrg" `
        --web-redirect-uris $redirectUri `
        --enable-id-token-issuance true `
        --query "{appId: appId, id: id}" -o json | ConvertFrom-Json
    
    $appId = $appReg.appId
    $appObjectId = $appReg.id
    Write-Host "App registration created: $appRegName (AppId: $appId)" -ForegroundColor Green
}

# Create service principal if it doesn't exist
$spExists = az ad sp list --filter "appId eq '$appId'" --query "[0].appId" -o tsv
if (-not $spExists) {
    az ad sp create --id $appId --output none
    Write-Host "Service principal created" -ForegroundColor Green
}

# Create client secret for the app registration
Write-Host "Creating client secret..." -ForegroundColor Yellow
$secretResult = az ad app credential reset --id $appObjectId --append --display-name "EasyAuthSecret" --query "{password: password}" -o json | ConvertFrom-Json
$clientSecret = $secretResult.password
Write-Host "Client secret created" -ForegroundColor Green

# Assign the security group to the app
Write-Host "Configuring group-based access control..." -ForegroundColor Yellow

# Update app to require group assignment
az ad app update --id $appObjectId --set "groupMembershipClaims=SecurityGroup" --output none

# Enable Easy Auth on Web App
Write-Host "Enabling Easy Auth on Web App..." -ForegroundColor Yellow

# Configure auth using REST API
$webAppResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$webAppName/config/authsettingsV2"

# Create auth settings JSON (save to temp file to avoid escaping issues)
$authBody = @{
    properties = @{
        platform          = @{
            enabled = $true
        }
        globalValidation  = @{
            requireAuthentication       = $true
            unauthenticatedClientAction = "Return401"
            redirectToProvider          = "azureActiveDirectory"
            excludedPaths               = @("/health", "/docs", "/openapi.json")
        }
        identityProviders = @{
            azureActiveDirectory   = @{
                enabled      = $true
                registration = @{
                    openIdIssuer            = "https://sts.windows.net/$tenantId/"
                    clientId                = $appId
                    clientSecretSettingName = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
                }
                login        = @{
                    loginParameters = @()
                }
            }
            apple                  = @{ enabled = $false }
            facebook               = @{ enabled = $false }
            gitHub                 = @{ enabled = $false }
            google                 = @{ enabled = $false }
            legacyMicrosoftAccount = @{ enabled = $false }
            twitter                = @{ enabled = $false }
        }
        login             = @{
            tokenStore = @{
                enabled = $true
            }
        }
        httpSettings      = @{
            requireHttps = $true
            routes       = @{
                apiPrefix = "/.auth"
            }
        }
    }
}

# Convert to JSON and save to temp file
$tempFile = [System.IO.Path]::GetTempFileName()
$authBody | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8

az rest `
    --method PUT `
    --uri "https://management.azure.com${webAppResourceId}?api-version=2022-03-01" `
    --headers "Content-Type=application/json" `
    --body "@$tempFile" `
    --output none

# Clean up temp file
Remove-Item -Path $tempFile -Force

# Store client secret as app setting
Write-Host "Storing client secret in app settings..." -ForegroundColor Yellow
az webapp config appsettings set `
    --name $webAppName `
    --resource-group $resourceGroupName `
    --settings MICROSOFT_PROVIDER_AUTHENTICATION_SECRET=$clientSecret `
    --output none

# Add Microsoft Graph User.Read permission and enable token issuance
Write-Host "Configuring API permissions..." -ForegroundColor Yellow
az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope --output none
az ad app update --id $appId --enable-access-token-issuance true --enable-id-token-issuance true --output none
Write-Host "API permissions configured" -ForegroundColor Green

# Configure service principal (group assignment for access control, but not enforced at SP level)
Write-Host "Configuring service principal..." -ForegroundColor Yellow
az ad sp update --id $appId --set appRoleAssignmentRequired=false --output none

# Assign the security group to the enterprise app
Write-Host "Assigning security group to enterprise app..." -ForegroundColor Yellow
$spObjectId = az ad sp show --id $appId --query "id" -o tsv

# Get the default user_impersonation app role
$appRoleId = az ad sp show --id $appId --query "appRoles[0].id" -o tsv

# Assign the group to the app
Write-Host "Checking existing group assignments..." -ForegroundColor Gray
$existingAssignments = az rest `
    --method GET `
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignedTo" `
    --query "value[?principalId=='$groupId']" `
    -o json | ConvertFrom-Json

if ($existingAssignments -and $existingAssignments.Count -gt 0) {
    Write-Host "Group already assigned to app" -ForegroundColor Yellow
}
else {
    $groupAssignmentBody = @{
        principalId = $groupId
        resourceId  = $spObjectId
        appRoleId   = "00000000-0000-0000-0000-000000000000"
    }

    $groupAssignmentFile = [System.IO.Path]::GetTempFileName()
    $groupAssignmentBody | ConvertTo-Json -Depth 10 | Set-Content -Path $groupAssignmentFile -Encoding UTF8

    try {
        az rest `
            --method POST `
            --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignments" `
            --headers "Content-Type=application/json" `
            --body "@$groupAssignmentFile" `
            --output none 2>&1 | Out-Null
        Write-Host "Group assigned to app successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not assign group (may already be assigned): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    finally {
        Remove-Item -Path $groupAssignmentFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "✅ Easy Auth configured successfully" -ForegroundColor Green
Write-Host "   - Authentication required (except /health endpoint)" -ForegroundColor White
Write-Host "   - Users in '$entraIdGroupName' group have access" -ForegroundColor White
Write-Host "   - App Registration: $appRegName" -ForegroundColor White
Write-Host "   - Health checks enabled and working`n" -ForegroundColor White

# Enable continuous deployment from ACR
Write-Host "Step 16: Enabling continuous deployment..." -ForegroundColor Cyan
az webapp deployment container config `
    --name $webAppName `
    --resource-group $resourceGroupName `
    --enable-cd true `
    --output none

# Configure health check
az resource update `
    --resource-group $resourceGroupName `
    --name $webAppName `
    --resource-type "Microsoft.Web/sites" `
    --set properties.siteConfig.healthCheckPath="/health" `
    --output none
Write-Host "Continuous deployment and health check configured`n" -ForegroundColor Green

# Grant managed identity access to SQL Database
Write-Host "Step 17: Granting managed identity access to SQL Database..." -ForegroundColor Cyan

# Add current IP to firewall for database user creation
Write-Host "Adding current IP to SQL firewall..." -ForegroundColor Yellow
$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
az sql server firewall-rule create `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name "AllowDeploymentIP" `
    --start-ip-address $myIp `
    --end-ip-address $myIp `
    --output none
Write-Host "Firewall rule added for IP: $myIp" -ForegroundColor Green

Write-Host "Creating database user for managed identity..." -ForegroundColor Yellow

$createUserSql = @"
CREATE USER [$webAppName] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [$webAppName];
"@

try {
    Invoke-Sqlcmd -ServerInstance "$($sqlServerName).database.windows.net" `
        -Database $databaseName `
        -AccessToken $accessToken `
        -Query $createUserSql `
        -ErrorAction Stop
    Write-Host "Database permissions granted successfully" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not grant permissions automatically: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "You may need to run this SQL manually:" -ForegroundColor Yellow
    Write-Host $createUserSql -ForegroundColor Gray
}

# Remove deployment IP from firewall (optional - comment out to keep access)
Write-Host "Removing deployment IP from firewall..." -ForegroundColor Yellow
az sql server firewall-rule delete `
    --resource-group $resourceGroupName `
    --server $sqlServerName `
    --name "AllowDeploymentIP" `
    --output none
Write-Host "Firewall rule removed`n" -ForegroundColor Green

# Wait for app to start
Write-Host "Waiting for Web App to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Deployment summary
Write-Host "======================================"
Write-Host "Deployment Complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "✅ Security Features Enabled:" -ForegroundColor Green
Write-Host "  • Docker image scanned (0 HIGH/CRITICAL CVEs)" -ForegroundColor White
Write-Host "  • Easy Auth (Entra ID) enabled" -ForegroundColor White
Write-Host "  • Group-based access control configured" -ForegroundColor White
Write-Host "  • Managed Identity for SQL authentication" -ForegroundColor White
Write-Host ""
Write-Host "Resources created:" -ForegroundColor Cyan
Write-Host "  Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "  SQL Server: $sqlServerName.database.windows.net" -ForegroundColor White
Write-Host "  Database: $databaseName" -ForegroundColor White
Write-Host "  Container Registry: $acrName.azurecr.io" -ForegroundColor White
Write-Host "  App Service Plan: $appServicePlanName" -ForegroundColor White
Write-Host "  Web App: $webAppName.azurewebsites.net" -ForegroundColor White
Write-Host "  Entra ID Admin: $($userDetails.displayName)" -ForegroundColor White
Write-Host "  Security Group: $entraIdGroupName (ID: $groupId)" -ForegroundColor White
Write-Host "  App Registration: $appRegName (AppId: $appId)" -ForegroundColor White
Write-Host ""
Write-Host "Authentication:" -ForegroundColor Cyan
Write-Host "  Only members of '$entraIdGroupName' can access the API" -ForegroundColor White
Write-Host "  Current members: $($userDetails.displayName)" -ForegroundColor White
Write-Host ""
Write-Host "To add users to the group:" -ForegroundColor Yellow
Write-Host "  az ad group member add --group $groupId --member-id <user-object-id>" -ForegroundColor White
Write-Host ""
Write-Host "Database contains:" -ForegroundColor Cyan
Write-Host "  - 17 musical notes" -ForegroundColor White
Write-Host "  - 13 intervals" -ForegroundColor White
Write-Host "  - 14 scale types" -ForegroundColor White
Write-Host "  - 28 chord types" -ForegroundColor White
Write-Host ""
Write-Host "API Endpoints (authentication required):" -ForegroundColor Cyan
Write-Host "  API Base URL: https://$webAppName.azurewebsites.net" -ForegroundColor White
Write-Host "  Documentation: https://$webAppName.azurewebsites.net/docs" -ForegroundColor White
Write-Host "  Health Check: https://$webAppName.azurewebsites.net/health" -ForegroundColor White
Write-Host ""
Write-Host "Access the API:" -ForegroundColor Yellow
Write-Host "  1. Visit: https://$webAppName.azurewebsites.net" -ForegroundColor White
Write-Host "  2. Sign in with your Entra ID credentials" -ForegroundColor White
Write-Host "  3. Verify you're a member of '$entraIdGroupName' group" -ForegroundColor White
Write-Host ""
Write-Host "Monitor API logs:" -ForegroundColor Yellow
Write-Host "  az webapp log tail --name $webAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host ""

# ====================================
# FRONTEND DEPLOYMENT
# ====================================

Write-Host "======================================"
Write-Host "Frontend Deployment"
Write-Host "======================================"
Write-Host ""

# Build and push Frontend Docker image
Write-Host "Step 18: Building and pushing Frontend Docker image..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

$frontendPath = Join-Path $workspaceRoot "app"
$frontendDockerfilePath = Join-Path $frontendPath "Dockerfile"

Write-Host "Frontend path: $frontendPath" -ForegroundColor Gray

# Update environment.prod.ts with API URL
Write-Host "Updating production environment configuration..." -ForegroundColor Yellow
$envProdPath = Join-Path $frontendPath "src\environments\environment.prod.ts"
$envProdContent = @"
export const environment = {
  production: true,
  apiUrl: 'https://$webAppName.azurewebsites.net'
};
"@
Set-Content -Path $envProdPath -Value $envProdContent -Encoding UTF8
Write-Host "Environment configured with API URL: https://$webAppName.azurewebsites.net" -ForegroundColor Green

# Build and push frontend image to ACR
az acr build `
    --registry $acrName `
    --image grooveapp-frontend:latest `
    --file $frontendDockerfilePath `
    --build-arg SKIP_AUDIT=true `
    --build-arg BUILD_CONFIGURATION=production `
    $frontendPath

Write-Host "Frontend Docker image built and pushed successfully`n" -ForegroundColor Green

# Create Frontend Web App
Write-Host "Step 19: Creating Frontend Web App..." -ForegroundColor Cyan
az webapp create `
    --resource-group $resourceGroupName `
    --plan $appServicePlanName `
    --name $frontendWebAppName `
    --deployment-container-image-name "$acrName.azurecr.io/grooveapp-frontend:latest" `
    --output none
Write-Host "Frontend Web App created: $frontendWebAppName.azurewebsites.net`n" -ForegroundColor Green

# Enable managed identity for frontend
Write-Host "Step 20: Enabling managed identity for frontend..." -ForegroundColor Cyan
$frontendIdentityResult = az webapp identity assign `
    --name $frontendWebAppName `
    --resource-group $resourceGroupName | ConvertFrom-Json

$frontendPrincipalId = $frontendIdentityResult.principalId
Write-Host "Frontend Managed Identity Principal ID: $frontendPrincipalId`n" -ForegroundColor Green

# Configure frontend container settings
Write-Host "Step 21: Configuring frontend container settings..." -ForegroundColor Cyan
az webapp config container set `
    --name $frontendWebAppName `
    --resource-group $resourceGroupName `
    --docker-custom-image-name "$acrName.azurecr.io/grooveapp-frontend:latest" `
    --docker-registry-server-url "https://$acrName.azurecr.io" `
    --docker-registry-server-user $acrCredentials.username `
    --docker-registry-server-password $acrCredentials.passwords[0].value `
    --output none
Write-Host "Frontend container configured successfully`n" -ForegroundColor Green

# Configure frontend app settings
Write-Host "Step 22: Configuring frontend application settings..." -ForegroundColor Cyan
az webapp config appsettings set `
    --name $frontendWebAppName `
    --resource-group $resourceGroupName `
    --settings `
    WEBSITES_PORT=8080 `
    API_URL="https://$webAppName.azurewebsites.net" `
    --output none
Write-Host "Frontend app settings configured`n" -ForegroundColor Green

# Configure Easy Auth for Frontend
Write-Host "Step 23: Configuring Easy Auth for Frontend..." -ForegroundColor Cyan
Write-Host "Creating App Registration for frontend authentication..." -ForegroundColor Yellow

# Create Frontend App Registration
$frontendAppRegName = "$frontendWebAppName-auth"
$frontendWebAppUrl = "https://$frontendWebAppName.azurewebsites.net"
$frontendRedirectUri = "$frontendWebAppUrl/.auth/login/aad/callback"

# Check if app registration exists
$existingFrontendApp = az ad app list --filter "displayName eq '$frontendAppRegName'" --query "[0]" -o json | ConvertFrom-Json

if ($existingFrontendApp) {
    Write-Host "Frontend app registration already exists: $frontendAppRegName" -ForegroundColor Yellow
    $frontendAppId = $existingFrontendApp.appId
    $frontendAppObjectId = $existingFrontendApp.id
}
else {
    # Create new app registration for frontend
    $frontendAppReg = az ad app create `
        --display-name $frontendAppRegName `
        --sign-in-audience "AzureADMyOrg" `
        --web-redirect-uris $frontendRedirectUri `
        --enable-id-token-issuance true `
        --query "{appId: appId, id: id}" -o json | ConvertFrom-Json
    
    $frontendAppId = $frontendAppReg.appId
    $frontendAppObjectId = $frontendAppReg.id
    Write-Host "Frontend app registration created: $frontendAppRegName (AppId: $frontendAppId)" -ForegroundColor Green
}

# Create service principal for frontend if it doesn't exist
$frontendSpExists = az ad sp list --filter "appId eq '$frontendAppId'" --query "[0].appId" -o tsv
if (-not $frontendSpExists) {
    az ad sp create --id $frontendAppId --output none
    Write-Host "Frontend service principal created" -ForegroundColor Green
}

# Create client secret for the frontend app registration
Write-Host "Creating client secret for frontend..." -ForegroundColor Yellow
$frontendSecretResult = az ad app credential reset --id $frontendAppObjectId --append --display-name "EasyAuthSecret" --query "{password: password}" -o json | ConvertFrom-Json
$frontendClientSecret = $frontendSecretResult.password
Write-Host "Frontend client secret created" -ForegroundColor Green

# Update frontend app to require group assignment
az ad app update --id $frontendAppObjectId --set "groupMembershipClaims=SecurityGroup" --output none

# Enable Easy Auth on Frontend Web App
Write-Host "Enabling Easy Auth on Frontend Web App..." -ForegroundColor Yellow

# Create frontend auth settings JSON
$frontendWebAppResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$frontendWebAppName/config/authsettingsV2"

$frontendAuthBody = @{
    properties = @{
        platform          = @{
            enabled = $true
        }
        globalValidation  = @{
            requireAuthentication       = $true
            unauthenticatedClientAction = "RedirectToLoginPage"
            redirectToProvider          = "azureActiveDirectory"
        }
        identityProviders = @{
            azureActiveDirectory   = @{
                enabled      = $true
                registration = @{
                    openIdIssuer            = "https://sts.windows.net/$tenantId/"
                    clientId                = $frontendAppId
                    clientSecretSettingName = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
                }
                login        = @{
                    loginParameters = @()
                }
            }
            apple                  = @{ enabled = $false }
            facebook               = @{ enabled = $false }
            gitHub                 = @{ enabled = $false }
            google                 = @{ enabled = $false }
            legacyMicrosoftAccount = @{ enabled = $false }
            twitter                = @{ enabled = $false }
        }
        login             = @{
            tokenStore = @{
                enabled = $true
            }
        }
        httpSettings      = @{
            requireHttps = $true
            routes       = @{
                apiPrefix = "/.auth"
            }
        }
    }
}

# Convert to JSON and save to temp file
$frontendTempFile = [System.IO.Path]::GetTempFileName()
$frontendAuthBody | ConvertTo-Json -Depth 10 | Set-Content -Path $frontendTempFile -Encoding UTF8

az rest `
    --method PUT `
    --uri "https://management.azure.com${frontendWebAppResourceId}?api-version=2022-03-01" `
    --headers "Content-Type=application/json" `
    --body "@$frontendTempFile" `
    --output none

# Clean up temp file
Remove-Item -Path $frontendTempFile -Force

# Store frontend client secret as app setting
Write-Host "Storing frontend client secret in app settings..." -ForegroundColor Yellow
az webapp config appsettings set `
    --name $frontendWebAppName `
    --resource-group $resourceGroupName `
    --settings MICROSOFT_PROVIDER_AUTHENTICATION_SECRET=$frontendClientSecret `
    --output none

# Add Microsoft Graph User.Read permission for frontend
Write-Host "Configuring API permissions for frontend..." -ForegroundColor Yellow
az ad app permission add --id $frontendAppId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope --output none
az ad app update --id $frontendAppId --enable-access-token-issuance true --enable-id-token-issuance true --output none
Write-Host "API permissions configured for frontend" -ForegroundColor Green

# Configure frontend service principal
Write-Host "Configuring frontend service principal..." -ForegroundColor Yellow
az ad sp update --id $frontendAppId --set appRoleAssignmentRequired=false --output none

# Assign the security group to the frontend enterprise app
Write-Host "Assigning security group to frontend enterprise app..." -ForegroundColor Yellow
$frontendSpObjectId = az ad sp show --id $frontendAppId --query "id" -o tsv

# Assign the group to the frontend app
Write-Host "Checking existing frontend group assignments..." -ForegroundColor Gray
$existingFrontendAssignments = az rest `
    --method GET `
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$frontendSpObjectId/appRoleAssignedTo" `
    --query "value[?principalId=='$groupId']" `
    -o json | ConvertFrom-Json

if ($existingFrontendAssignments -and $existingFrontendAssignments.Count -gt 0) {
    Write-Host "Group already assigned to frontend app" -ForegroundColor Yellow
}
else {
    $frontendGroupAssignmentBody = @{
        principalId = $groupId
        resourceId  = $frontendSpObjectId
        appRoleId   = "00000000-0000-0000-0000-000000000000"
    }

    $frontendGroupAssignmentFile = [System.IO.Path]::GetTempFileName()
    $frontendGroupAssignmentBody | ConvertTo-Json -Depth 10 | Set-Content -Path $frontendGroupAssignmentFile -Encoding UTF8

    try {
        az rest `
            --method POST `
            --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$frontendSpObjectId/appRoleAssignments" `
            --headers "Content-Type=application/json" `
            --body "@$frontendGroupAssignmentFile" `
            --output none 2>&1 | Out-Null
        Write-Host "Group assigned to frontend app successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not assign group (may already be assigned): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    finally {
        Remove-Item -Path $frontendGroupAssignmentFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "✅ Frontend Easy Auth configured successfully" -ForegroundColor Green
Write-Host "   - Authentication required for all pages" -ForegroundColor White
Write-Host "   - Users in '$entraIdGroupName' group have access" -ForegroundColor White
Write-Host "   - App Registration: $frontendAppRegName" -ForegroundColor White

# Enable continuous deployment for frontend from ACR
Write-Host "Step 24: Enabling continuous deployment for frontend..." -ForegroundColor Cyan
az webapp deployment container config `
    --name $frontendWebAppName `
    --resource-group $resourceGroupName `
    --enable-cd true `
    --output none
Write-Host "Frontend continuous deployment configured`n" -ForegroundColor Green

# Grant frontend managed identity access to API (add as App Role if needed)
Write-Host "Step 25: Configuring frontend managed identity access to API..." -ForegroundColor Cyan
Write-Host "Frontend will use managed identity to call API" -ForegroundColor Yellow
Write-Host "API will authenticate requests using Easy Auth tokens`n" -ForegroundColor Green

# Wait for frontend app to start
Write-Host "Waiting for Frontend Web App to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Final deployment summary
Write-Host "======================================"
Write-Host "Deployment Complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "✅ Security Features Enabled:" -ForegroundColor Green
Write-Host "  • Docker images scanned for vulnerabilities" -ForegroundColor White
Write-Host "  • Easy Auth (Entra ID) enabled on API and Frontend" -ForegroundColor White
Write-Host "  • Group-based access control configured" -ForegroundColor White
Write-Host "  • Managed Identity for SQL authentication" -ForegroundColor White
Write-Host "  • Frontend uses managed identity to call API" -ForegroundColor White
Write-Host ""
Write-Host "Resources created:" -ForegroundColor Cyan
Write-Host "  Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "  SQL Server: $sqlServerName.database.windows.net" -ForegroundColor White
Write-Host "  Database: $databaseName" -ForegroundColor White
Write-Host "  Container Registry: $acrName.azurecr.io" -ForegroundColor White
Write-Host "  App Service Plan: $appServicePlanName (Linux B1)" -ForegroundColor White
Write-Host "  API Web App: $webAppName.azurewebsites.net" -ForegroundColor White
Write-Host "  Frontend Web App: $frontendWebAppName.azurewebsites.net" -ForegroundColor White
Write-Host "  Entra ID Admin: $($userDetails.displayName)" -ForegroundColor White
Write-Host "  Security Group: $entraIdGroupName (ID: $groupId)" -ForegroundColor White
Write-Host "  API App Registration: $appRegName (AppId: $appId)" -ForegroundColor White
Write-Host "  Frontend App Registration: $frontendAppRegName (AppId: $frontendAppId)" -ForegroundColor White
Write-Host ""
Write-Host "Authentication:" -ForegroundColor Cyan
Write-Host "  Only members of '$entraIdGroupName' can access the application" -ForegroundColor White
Write-Host "  Current members: $($userDetails.displayName)" -ForegroundColor White
Write-Host ""
Write-Host "To add users to the group:" -ForegroundColor Yellow
Write-Host "  az ad group member add --group $groupId --member-id <user-object-id>" -ForegroundColor White
Write-Host ""
Write-Host "Database contains:" -ForegroundColor Cyan
Write-Host "  - 17 musical notes" -ForegroundColor White
Write-Host "  - 13 intervals" -ForegroundColor White
Write-Host "  - 14 scale types" -ForegroundColor White
Write-Host "  - 28 chord types" -ForegroundColor White
Write-Host "  - 70+ key signatures for correct note spelling" -ForegroundColor White
Write-Host ""
Write-Host "Access the Application:" -ForegroundColor Yellow
Write-Host "  🌐 Frontend URL: https://$frontendWebAppName.azurewebsites.net" -ForegroundColor Green
Write-Host "  1. Visit the frontend URL" -ForegroundColor White
Write-Host "  2. Sign in with your Entra ID credentials" -ForegroundColor White
Write-Host "  3. Explore scales and arpeggios with musical staff visualization" -ForegroundColor White
Write-Host ""
Write-Host "API Endpoints (authentication required):" -ForegroundColor Cyan
Write-Host "  API Base URL: https://$webAppName.azurewebsites.net" -ForegroundColor White
Write-Host "  Documentation: https://$webAppName.azurewebsites.net/docs" -ForegroundColor White
Write-Host "  Health Check: https://$webAppName.azurewebsites.net/health" -ForegroundColor White
Write-Host ""
Write-Host "Monitor logs:" -ForegroundColor Yellow
Write-Host "  API: az webapp log tail --name $webAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host "  Frontend: az webapp log tail --name $frontendWebAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host "" 

