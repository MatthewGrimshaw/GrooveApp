# set location
Set-Location -Path "C:\Users\matgri\repos\grooveapp\infra\terraform"

$env = "dev" # Change to "staging" or "prod" as needed
$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"

# authenticate with azure
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan
az login --tenant $tenantId
az account set --subscription $subscriptionId
Write-Host "Authentication successful`n" -ForegroundColor Green


# check if firewall is set to public on storage account
$storageAccountName = "stgrooveapptfstate"
$resourceGroupName = "rg-grooveapp-tfstate"

$account = az storage account show --name $storageAccountName --resource-group $resourceGroupName --query "{publicNetworkAccess:publicNetworkAccess, allowBlobPublicAccess:allowBlobPublicAccess, defaultAction:networkRuleSet.defaultAction}" -o json
$account | ConvertFrom-Json; Write-Host "Storage Account: $storageAccountName"; Write-Host "Public Network Access: $($account.publicNetworkAccess)"
if ($account.publicNetworkAccess -ne "Enabled") {
    Write-Host "Enabling public network access on storage account..." -ForegroundColor Yellow
    az storage account update --name $storageAccountName --resource-group $resourceGroupName --public-network-access Enabled
    Write-Host "Public network access enabled`n" -ForegroundColor Green
} 

# Terraform Apply with Verbose Logging
# This script runs terraform apply with detailed logging to troubleshoot tenant/permission issues

# Set Terraform logging
$env:TF_LOG = "DEBUG"
$env:TF_LOG_PATH = "terraform-debug.log"

# Set Azure CLI logging
$env:AZURE_CLI_DIAGNOSTICS = "1"

Write-Host "======================================"
Write-Host "Terraform Apply with Verbose Logging"
Write-Host "======================================"
Write-Host ""
Write-Host "Logging Configuration:" -ForegroundColor Cyan
Write-Host "  TF_LOG: $env:TF_LOG" -ForegroundColor White
Write-Host "  TF_LOG_PATH: $env:TF_LOG_PATH" -ForegroundColor White
Write-Host "  Azure CLI diagnostics: Enabled" -ForegroundColor White
Write-Host ""

# Show current Azure context
Write-Host "Current Azure Context:" -ForegroundColor Cyan
az account show --query "{subscription: name, tenant: tenantId, user: user.name}" -o table
Write-Host ""

# Confirm tenant
$tenantInfo = az account show --query "{tenantId: tenantId, tenantDisplayName: tenantDisplayName}" -o json | ConvertFrom-Json
Write-Host "Tenant Information:" -ForegroundColor Yellow
Write-Host "  Tenant ID: $($tenantInfo.tenantId)" -ForegroundColor White
Write-Host "  Tenant Name: $($tenantInfo.tenantDisplayName)" -ForegroundColor White
Write-Host ""

# Show selected environment
Write-Host "Environment: $env" -ForegroundColor Yellow
Write-Host ""


# Initialize Terraform
Write-Host "Running terraform init for $($env) environment..." -ForegroundColor Cyan
Write-Host ""

terraform init -backend-config="key=grooveapp-$($env).tfstate"
# uncomment if the environment changes
#terraform init -reconfigure -backend-config="key=grooveapp-$env.tfstate"

if ($LASTEXITCODE -ne 0) {
    Write-Host "" 
    Write-Host "❌ Terraform init failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Init Complete"
Write-Host "======================================"
Write-Host ""

# Validate Terraform configuration
Write-Host "Running terraform validate..." -ForegroundColor Cyan
Write-Host ""

terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host "" 
    Write-Host "❌ Terraform validate failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Validate Complete"
Write-Host "======================================"
Write-Host ""

# Format Terraform files
Write-Host "Running terraform fmt..." -ForegroundColor Cyan
Write-Host ""

terraform fmt -check -recursive

if ($LASTEXITCODE -ne 0) {
    Write-Host "" 
    Write-Host "❌ Terraform fmt check failed - files need formatting" -ForegroundColor Red
    Write-Host "Run 'terraform fmt -recursive' to fix formatting" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Fmt Complete"
Write-Host "======================================"
Write-Host ""

# Plan Terraform changes

Write-Host "Running terraform plan for $($env) environment..." -ForegroundColor Cyan
Write-Host ""

switch ($env) {
    "dev" { $varFile = "environments\dev.tfvars" }
    "staging" { $varFile = "environments\staging.tfvars" }
    "prod" { $varFile = "environments\prod.tfvars" }
    default { Write-Host "Invalid environment specified. Use 'dev', 'staging', or 'prod'." -ForegroundColor Red; exit 1 }
}

terraform plan -var-file="$varFile" -out="terraform.tfplan"

if ($LASTEXITCODE -ne 0) {
    Write-Host "" 
    Write-Host "❌ Terraform plan failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Plan Complete"
Write-Host "======================================"
Write-Host ""

#show terraform plan output
Write-Host "Running terraform show..." -ForegroundColor Cyan
Write-Host ""

terraform show terraform.tfplan

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Show Complete"
Write-Host "======================================"
Write-Host ""

# Apply Terraform configuration with local environment variables
Write-Host "Running terraform apply for $($env) environment..." -ForegroundColor Cyan
Write-Host ""

terraform apply terraform.tfplan

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Success!" -ForegroundColor Green
    Write-Host "   Debug log saved to: terraform-debug.log" -ForegroundColor White
}
else {
    Write-Host ""
    Write-Host "❌ Failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "   Check terraform-debug.log for details" -ForegroundColor Yellow
    Write-Host "   Last 50 lines of debug log:" -ForegroundColor Yellow
    Write-Host ""
    Get-Content "terraform-debug.log" -Tail 50
}

# Clean up environment variables
Remove-Item Env:\TF_LOG -ErrorAction SilentlyContinue
Remove-Item Env:\TF_LOG_PATH -ErrorAction SilentlyContinue
Remove-Item Env:\AZURE_CLI_DIAGNOSTICS -ErrorAction SilentlyContinue
Remove-Item terraform.tfplan -ErrorAction SilentlyContinue
Remove-Item .\terraform-debug.log -ErrorAction SilentlyContinue
Remove-Item .\.api_secret.txt -ErrorAction SilentlyContinue
Remove-Item .\.db_connection.txt -ErrorAction SilentlyContinue
Remove-Item .\.frontend_secret.txt -ErrorAction SilentlyContinue

# If terraform apply succeeded, build and deploy container images
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "======================================"
    Write-Host "Building and Deploying Container Images"
    Write-Host "======================================"
    Write-Host ""
    
    # Change to infra directory (parent of terraform directory)
    Set-Location -Path ".."
    
    Write-Host "Current directory: $(Get-Location)" -ForegroundColor Cyan
    Write-Host "Running deploy-updates.ps1..." -ForegroundColor Cyan
    Write-Host ""
    
    # Call deploy-updates.ps1
    & ".\deploy-updates.ps1"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Container images built and deployed successfully!" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "======================================"
        Write-Host "Post-Deployment Health Checks"
        Write-Host "======================================"
        Write-Host ""
        
        # Get the deployed URLs
        $apiWebAppName = "app-grooveapp-$env-api"
        $frontendWebAppName = "app-grooveapp-$env-frontend"
        $apiUrl = "https://$apiWebAppName.azurewebsites.net"
        $frontendUrl = "https://$frontendWebAppName.azurewebsites.net"
        
        $allHealthy = $true
        
        # Test 1: API Health Endpoint (should return 200 OK without auth)
        Write-Host "Testing API health endpoint..." -ForegroundColor Cyan
        try {
            $apiHealthResponse = Invoke-WebRequest -Uri "$apiUrl/health" -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            if ($apiHealthResponse.StatusCode -eq 200) {
                Write-Host "✅ API health check passed (HTTP $($apiHealthResponse.StatusCode))" -ForegroundColor Green
            }
            else {
                Write-Host "❌ API health check failed (HTTP $($apiHealthResponse.StatusCode))" -ForegroundColor Red
                $allHealthy = $false
            }
        }
        catch {
            Write-Host "❌ API health check failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.Exception.Response) {
                Write-Host "   Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
            }
            $allHealthy = $false
        }
        Write-Host ""
        
        # Test 2: Frontend Authentication Redirect (with browser headers)
        Write-Host "Testing Frontend authentication redirect..." -ForegroundColor Cyan
        try {
            # Use browser-like headers to trigger redirect (not API 401)
            $headers = @{
                'Accept'     = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            $frontendResponse = Invoke-WebRequest -Uri $frontendUrl -Method Get -Headers $headers -UseBasicParsing -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction SilentlyContinue
            
            if ($frontendResponse.StatusCode -eq 200) {
                Write-Host "⚠️  Frontend returned 200 without authentication - Easy Auth may be disabled" -ForegroundColor Yellow
                $allHealthy = $false
            }
            else {
                Write-Host "❌ Frontend returned unexpected status (HTTP $($frontendResponse.StatusCode))" -ForegroundColor Red
                $allHealthy = $false
            }
        }
        catch {
            # 302 redirects throw exceptions with -MaximumRedirection 0
            if ($_.Exception.Response.StatusCode.value__ -eq 302) {
                $location = $_.Exception.Response.Headers.Location
                if ($location -and $location.AbsoluteUri -match 'login\.windows\.net|login\.microsoftonline\.com') {
                    Write-Host "✅ Frontend redirects to Azure AD login (HTTP 302)" -ForegroundColor Green
                    Write-Host "   Redirect URL: $($location.AbsoluteUri.Substring(0, [Math]::Min(80, $location.AbsoluteUri.Length)))..." -ForegroundColor Gray
                }
                else {
                    Write-Host "⚠️  Frontend redirects but not to Azure AD: $location" -ForegroundColor Yellow
                    $allHealthy = $false
                }
            }
            elseif ($_.Exception.Response.StatusCode.value__ -eq 401) {
                Write-Host "❌ Frontend returned 401 instead of 302 - Easy Auth issuer may be missing" -ForegroundColor Red
                Write-Host "   With browser headers, Easy Auth should return 302 redirect, not 401" -ForegroundColor Yellow
                $allHealthy = $false
            }
            else {
                Write-Host "❌ Frontend check failed: $($_.Exception.Message)" -ForegroundColor Red
                if ($_.Exception.Response) {
                    Write-Host "   Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
                }
                $allHealthy = $false
            }
        }
        Write-Host ""
        
        # Test 3: API Protected Endpoint (should return 401 with Bearer challenge)
        Write-Host "Testing API authentication on protected endpoint..." -ForegroundColor Cyan
        try {
            $apiProtectedResponse = Invoke-WebRequest -Uri "$apiUrl/circle-of-fifths/keys" -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            Write-Host "⚠️  API returned $($apiProtectedResponse.StatusCode) without authentication - Easy Auth may be disabled" -ForegroundColor Yellow
            $allHealthy = $false
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 401) {
                # Check for WWW-Authenticate header (indicates proper auth challenge)
                $wwwAuth = $_.Exception.Response.Headers['WWW-Authenticate']
                if ($wwwAuth -and $wwwAuth -match 'Bearer') {
                    Write-Host "✅ API authentication is active (HTTP 401 with Bearer challenge)" -ForegroundColor Green
                }
                else {
                    Write-Host "✅ API returns 401 Unauthorized" -ForegroundColor Green
                    Write-Host "   Note: WWW-Authenticate header not found" -ForegroundColor Gray
                }
            }
            elseif ($_.Exception.Response.StatusCode.value__ -ge 500) {
                Write-Host "❌ API returned server error $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
                Write-Host "   This could indicate database connectivity issues" -ForegroundColor Yellow
                $allHealthy = $false
            }
            else {
                Write-Host "⚠️  API returned unexpected status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
            }
        }
        Write-Host ""
        
        # Test 3b: API Database Connectivity via Health Endpoint
        Write-Host "Testing API database connectivity..." -ForegroundColor Cyan
        try {
            $healthResponse = Invoke-WebRequest -Uri "$apiUrl/health" -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            $health = $healthResponse.Content | ConvertFrom-Json
            
            if ($health.status -eq 'healthy' -and $health.checks.database.status -eq 'healthy') {
                Write-Host "✅ API database connection is healthy" -ForegroundColor Green
                Write-Host "   Database: $($health.database)" -ForegroundColor Gray
                Write-Host "   Auth method: $($health.checks.authentication.method)" -ForegroundColor Gray
            }
            elseif ($health.checks.database.status -eq 'unhealthy') {
                Write-Host "❌ API database connection is unhealthy" -ForegroundColor Red
                if ($health.checks.database.error) {
                    Write-Host "   Error: $($health.checks.database.error.Substring(0, [Math]::Min(150, $health.checks.database.error.Length)))..." -ForegroundColor Yellow
                }
                $allHealthy = $false
            }
            else {
                Write-Host "⚠️  API health status: $($health.status)" -ForegroundColor Yellow
                Write-Host "   Database status: $($health.checks.database.status)" -ForegroundColor Yellow
                $allHealthy = $false
            }
        }
        catch {
            Write-Host "❌ Failed to check API health endpoint: $($_.Exception.Message)" -ForegroundColor Red
            $allHealthy = $false
        }
        Write-Host ""
        
        # Test 4: Check Easy Auth Configuration
        Write-Host "Validating Easy Auth configuration..." -ForegroundColor Cyan
        $apiAuthSettings = az webapp auth show --name $apiWebAppName --resource-group "rg-grooveapp-$env" | ConvertFrom-Json
        $frontendAuthSettings = az webapp auth show --name $frontendWebAppName --resource-group "rg-grooveapp-$env" | ConvertFrom-Json
        
        # Check API auth config
        $apiAuthOk = $true
        if ($apiAuthSettings.enabled) {
            Write-Host "✅ API Easy Auth is enabled" -ForegroundColor Green
            
            # Check for client ID
            if ($apiAuthSettings.clientId) {
                Write-Host "   Client ID: $($apiAuthSettings.clientId.Substring(0,8))..." -ForegroundColor Gray
            }
            else {
                Write-Host "   ❌ Missing client ID" -ForegroundColor Red
                $apiAuthOk = $false
            }
            
            # Check unauthenticated action (should be AllowAnonymous for API)
            if ($apiAuthSettings.unauthenticatedClientAction -eq 'AllowAnonymous') {
                Write-Host "   Unauthenticated action: AllowAnonymous (correct for API)" -ForegroundColor Gray
            }
            else {
                Write-Host "   ⚠️  Unauthenticated action: $($apiAuthSettings.unauthenticatedClientAction)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "❌ API Easy Auth is disabled" -ForegroundColor Red
            $apiAuthOk = $false
        }
        
        if (-not $apiAuthOk) { $allHealthy = $false }
        Write-Host ""
        
        # Check Frontend auth config
        $frontendAuthOk = $true
        if ($frontendAuthSettings.enabled) {
            Write-Host "✅ Frontend Easy Auth is enabled" -ForegroundColor Green
            
            # Check for client ID
            if ($frontendAuthSettings.clientId) {
                Write-Host "   Client ID: $($frontendAuthSettings.clientId.Substring(0,8))..." -ForegroundColor Gray
            }
            else {
                Write-Host "   ❌ Missing client ID" -ForegroundColor Red
                $frontendAuthOk = $false
            }
            
            # Check unauthenticated action (should be RedirectToLoginPage for Frontend)
            if ($frontendAuthSettings.unauthenticatedClientAction -eq 'RedirectToLoginPage') {
                Write-Host "   Unauthenticated action: RedirectToLoginPage (correct for Frontend)" -ForegroundColor Gray
            }
            else {
                Write-Host "   ⚠️  Unauthenticated action: $($frontendAuthSettings.unauthenticatedClientAction)" -ForegroundColor Yellow
            }
            
            # Check default provider
            if ($frontendAuthSettings.defaultProvider -eq 'AzureActiveDirectory') {
                Write-Host "   Default provider: AzureActiveDirectory" -ForegroundColor Gray
            }
            else {
                Write-Host "   ⚠️  Default provider: $($frontendAuthSettings.defaultProvider)" -ForegroundColor Yellow
            }
            
            # Check issuer (critical for redirect to work)
            if ($frontendAuthSettings.issuer) {
                Write-Host "   Issuer: $($frontendAuthSettings.issuer)" -ForegroundColor Gray
            }
            else {
                Write-Host "   ⚠️  Issuer not set - may cause 401 instead of 302 redirect" -ForegroundColor Yellow
                Write-Host "      Frontend will return 401 Bearer challenge instead of redirecting browsers" -ForegroundColor Yellow
                $frontendAuthOk = $false
            }
        }
        else {
            Write-Host "❌ Frontend Easy Auth is disabled" -ForegroundColor Red
            $frontendAuthOk = $false
        }
        
        if (-not $frontendAuthOk) { $allHealthy = $false }
        Write-Host ""
        
        if (-not $allHealthy) {
            Write-Host "======================================"
            Write-Host "⚠️  DEPLOYMENT HEALTH CHECK WARNINGS"
            Write-Host "======================================"
            Write-Host ""
            Write-Host "One or more health checks failed. Review the errors above." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Common issues and fixes:" -ForegroundColor Cyan
            Write-Host "  • Frontend returns 401 instead of 302:" -ForegroundColor White
            Write-Host "    - Check issuer is set in auth_settings (Terraform module)" -ForegroundColor Gray
            Write-Host "    - Verify defaultProvider = 'AzureActiveDirectory'" -ForegroundColor Gray
            Write-Host "  • Database unhealthy:" -ForegroundColor White
            Write-Host "    - Verify managed identity has database permissions" -ForegroundColor Gray
            Write-Host "    - Check VNet integration is active" -ForegroundColor Gray
            Write-Host "    - Run: infra/grant-webapp-db-access.ps1" -ForegroundColor Gray
            Write-Host "  • API returns 5xx errors:" -ForegroundColor White
            Write-Host "    - Check application logs for detailed error messages" -ForegroundColor Gray
            Write-Host "    - Verify environment variables are set correctly" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Diagnostic commands:" -ForegroundColor Cyan
            Write-Host "  View API logs:      az webapp log tail --name $apiWebAppName --resource-group rg-grooveapp-$env" -ForegroundColor White
            Write-Host "  View Frontend logs: az webapp log tail --name $frontendWebAppName --resource-group rg-grooveapp-$env" -ForegroundColor White
            Write-Host "  Check auth config:  az webapp auth show --name $frontendWebAppName --resource-group rg-grooveapp-$env" -ForegroundColor White
            Write-Host "  Test with curl:     curl -v -H 'Accept: text/html' $frontendUrl 2>&1 | Select-String 'HTTP/|location:'" -ForegroundColor White
            Write-Host "  Check DB users:     Run SQL query: SELECT name, type_desc FROM sys.database_principals WHERE type = 'E'" -ForegroundColor White
            Write-Host ""
        }
        
        # Run comprehensive API tests only if health checks passed
        if ($allHealthy) {
            Write-Host "======================================"
            Write-Host "Running Comprehensive API Tests"
            Write-Host "======================================"
            Write-Host ""
            
            Write-Host "Testing API at: $apiUrl" -ForegroundColor Cyan
            Write-Host ""
            
            # Navigate to api directory to run test script
            # Current location: infra/terraform, need to go up to repo root
            $repoRoot = Split-Path -Parent (Split-Path -Parent (Get-Location))
            $testScript = Join-Path $repoRoot "api\test-apiResponses.ps1"
            
            if (Test-Path $testScript) {
                # Run comprehensive API tests against deployed endpoint
                & $testScript -ApiUrl $apiUrl
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host ""
                    Write-Host "✅ All API tests passed! Deployment verified." -ForegroundColor Green
                    Write-Host ""
                    Write-Host "======================================"
                    Write-Host "Deployment Complete and Verified"
                    Write-Host "======================================"
                    Write-Host ""
                    Write-Host "Frontend: $frontendUrl" -ForegroundColor White
                    Write-Host "API:      $apiUrl" -ForegroundColor White
                    Write-Host ""
                }
                else {
                    Write-Host ""
                    Write-Host "❌ API tests failed! Deployment may have issues." -ForegroundColor Red
                    Write-Host "   Review the test output above for details" -ForegroundColor Yellow
                    Write-Host "   Check logs at /logs/test-api-failures-*.json" -ForegroundColor Yellow
                    exit 1
                }
            }
            else {
                Write-Warning "API test script not found at: $testScript"
                Write-Host "Skipping comprehensive API validation" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "⚠️  Skipping comprehensive API tests due to failed health checks" -ForegroundColor Yellow
            Write-Host "   Fix the issues above and redeploy" -ForegroundColor Yellow
            Write-Host ""
            exit 1
        }
    }
    else {
        Write-Host ""
        Write-Host "❌ Container deployment failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "   Check the output above for details" -ForegroundColor Yellow
        exit 1
    }
    
    # Return to terraform directory
    Set-Location -Path "terraform"
}

#exit $exitCode