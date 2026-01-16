# GrooveApp Blue-Green Deployment Script
# Builds new Docker images, pushes to ACR, and deploys to staging slots with zero-downtime swap

# Parameters
param(
    [switch]$ApiOnly,
    [switch]$FrontendOnly,
    [switch]$SkipBuild,
    [switch]$SkipSwap,
    [switch]$NoSecurityScan
)

# Variables
$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"
$resourceGroupName = "rg-grooveapp-dev"
$acrName = "acrgrooveappdevuhxg"
$webAppName = "app-grooveapp-dev-api"
$frontendWebAppName = "app-grooveapp-dev-frontend"
$stagingSlotName = "staging"

Write-Host "======================================"
Write-Host "GrooveApp Blue-Green Deployment"
Write-Host "======================================"
Write-Host ""

# Get script directory and workspace root
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
$frontendPath = Join-Path $workspaceRoot "app"

Write-Host "Workspace root: $workspaceRoot" -ForegroundColor Gray
Write-Host ""

# Determine what to deploy
$deployApi = -not $FrontendOnly
$deployFrontend = -not $ApiOnly

# Authentication
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan
az config set core.login_experience_v2=off
az login --tenant $tenantId --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Already authenticated or using cached credentials" -ForegroundColor Yellow
}
az account set --subscription $subscriptionId
Write-Host "Authentication successful`n" -ForegroundColor Green

# Get ACR credentials
Write-Host "Step 2: Getting ACR credentials..." -ForegroundColor Cyan
$acrCredentials = az acr credential show --name $acrName | ConvertFrom-Json
Write-Host "ACR credentials retrieved`n" -ForegroundColor Green

# ====================================
# API DEPLOYMENT
# ====================================

if ($deployApi) {
    Write-Host "======================================"
    Write-Host "API Deployment"
    Write-Host "======================================"
    Write-Host ""

    if (-not $SkipBuild) {
        Write-Host "Step 3: Building and pushing API Docker image..." -ForegroundColor Cyan
        Write-Host "This may take a few minutes..." -ForegroundColor Yellow

        $apiDockerfilePath = Join-Path $apiPath "Dockerfile"

        # Build and scan locally before pushing to ACR
        if (-not $NoSecurityScan) {
            Write-Host "Building and scanning Docker image locally..." -ForegroundColor Yellow
            Push-Location $apiPath
            try {
                $buildScript = Join-Path $apiPath "build-localApi.ps1"
                & $buildScript -Rebuild -MaxSeverity high
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Security scan failed. Fix vulnerabilities before deploying." -ForegroundColor Red
                    Write-Host "Review vulnerabilities with: docker scout cves grooveapp-api" -ForegroundColor Yellow
                    Pop-Location
                    exit 1
                }
                Write-Host "✅ Security scan passed - No HIGH or CRITICAL CVEs detected`n" -ForegroundColor Green
            }
            catch {
                Write-Host "Error during build/scan: $_" -ForegroundColor Red
                Pop-Location
                exit 1
            }
            finally {
                Pop-Location
            }
        }

        # Generate unique tag for grooveapp-api repository
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $apiImageTag = "grooveapp-api:$timestamp"
        $apiLatestTag = "grooveapp-api:latest"

        # Push to Azure Container Registry with both unique and latest tags
        Write-Host "Pushing image to ACR repository 'grooveapp-api' with tags: $timestamp and latest" -ForegroundColor Yellow
        az acr build `
            --registry $acrName `
            --image $apiImageTag `
            --image $apiLatestTag `
            --file $apiDockerfilePath `
            $apiPath

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ API Docker image build failed" -ForegroundColor Red
            Write-Host "Check the build output above for details" -ForegroundColor Yellow
            exit 1
        }

        Write-Host "API Docker image built and pushed successfully`n" -ForegroundColor Green
    }
    else {
        Write-Host "Step 3: Skipping API image build (using existing latest image)`n" -ForegroundColor Yellow
    }

    # Create staging slot if it doesn't exist
    Write-Host "Step 4: Ensuring API staging slot exists..." -ForegroundColor Cyan
    $apiSlotExists = az webapp deployment slot list `
        --name $webAppName `
        --resource-group $resourceGroupName `
        --query "[?name=='$stagingSlotName'].name" `
        -o tsv

    if (-not $apiSlotExists) {
        Write-Host "Creating staging slot for API..." -ForegroundColor Yellow
        az webapp deployment slot create `
            --name $webAppName `
            --resource-group $resourceGroupName `
            --slot $stagingSlotName `
            --configuration-source $webAppName `
            --output none
        Write-Host "Staging slot created" -ForegroundColor Green
    }
    else {
        Write-Host "Staging slot already exists" -ForegroundColor Green
    }

    # Deploy to staging slot
    Write-Host "Step 5: Deploying API to staging slot..." -ForegroundColor Cyan
    az webapp config container set `
        --name $webAppName `
        --resource-group $resourceGroupName `
        --slot $stagingSlotName `
        --docker-custom-image-name "$acrName.azurecr.io/grooveapp-api:latest" `
        --docker-registry-server-url "https://$acrName.azurecr.io" `
        --docker-registry-server-user $acrCredentials.username `
        --docker-registry-server-password $acrCredentials.passwords[0].value `
        --output none

    Write-Host "API deployed to staging slot" -ForegroundColor Green
    Write-Host "Staging URL: https://$webAppName-$stagingSlotName.azurewebsites.net" -ForegroundColor White
    Write-Host ""

    # Wait for staging slot to warm up
    Write-Host "Waiting for staging slot to warm up..." -ForegroundColor Yellow
    Start-Sleep -Seconds 20

    # Health check on staging
    Write-Host "Performing health check on staging slot..." -ForegroundColor Yellow
    $stagingHealthUrl = "https://$webAppName-$stagingSlotName.azurewebsites.net/health"
    $maxRetries = 5
    $retryCount = 0
    $healthy = $false

    while ($retryCount -lt $maxRetries -and -not $healthy) {
        try {
            $response = Invoke-WebRequest -Uri $stagingHealthUrl -Method Get -TimeoutSec 10 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                $healthy = $true
                Write-Host "✅ Staging slot is healthy" -ForegroundColor Green
            }
        }
        catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "Health check failed, retrying... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 10
            }
            else {
                Write-Host "⚠️ Warning: Health check failed after $maxRetries attempts" -ForegroundColor Red
                Write-Host "You may want to check the logs before swapping:" -ForegroundColor Yellow
                Write-Host "  az webapp log tail --name $webAppName --resource-group $resourceGroupName --slot $stagingSlotName" -ForegroundColor White
                
                $continue = Read-Host "Continue with swap anyway? (y/N)"
                if ($continue -ne "y" -and $continue -ne "Y") {
                    Write-Host "Deployment cancelled`n" -ForegroundColor Red
                    exit 1
                }
            }
        }
    }

    # Swap slots
    if (-not $SkipSwap) {
        Write-Host "Step 6: Swapping staging to production..." -ForegroundColor Cyan
        Write-Host "This will perform a zero-downtime deployment" -ForegroundColor Yellow
        
        az webapp deployment slot swap `
            --name $webAppName `
            --resource-group $resourceGroupName `
            --slot $stagingSlotName `
            --target-slot production `
            --output none

        Write-Host "✅ API swap complete!" -ForegroundColor Green
        Write-Host "Production URL: https://$webAppName.azurewebsites.net`n" -ForegroundColor White
    }
    else {
        Write-Host "Step 6: Skipping slot swap (manual swap required)`n" -ForegroundColor Yellow
        Write-Host "To manually swap slots, run:" -ForegroundColor White
        Write-Host "  az webapp deployment slot swap --name $webAppName --resource-group $resourceGroupName --slot $stagingSlotName`n" -ForegroundColor Gray
    }
}

# ====================================
# FRONTEND DEPLOYMENT
# ====================================

if ($deployFrontend) {
    Write-Host "======================================"
    Write-Host "Frontend Deployment"
    Write-Host "======================================"
    Write-Host ""

    if (-not $SkipBuild) {
        Write-Host "Step 7: Building and pushing Frontend Docker image..." -ForegroundColor Cyan
        Write-Host "This may take a few minutes..." -ForegroundColor Yellow

        $frontendDockerfilePath = Join-Path $frontendPath "Dockerfile"

        # Update environment.dev.ts with API URL and logging configuration
        Write-Host "Updating dev environment configuration..." -ForegroundColor Yellow
        $envDevPath = Join-Path $frontendPath "src\environments\environment.dev.ts"
        $envDevContent = @"
export const environment = {
  production: true,
  apiUrl: 'https://$webAppName.azurewebsites.net',
  // Application Insights connection string (injected at build time via environment variable)
  appInsightsConnectionString: '`${APPLICATIONINSIGHTS_CONNECTION_STRING}',
  // Log Level: 'OFF' | 'ERROR' | 'WARNING' | 'INFO' | 'DEBUG'
  logLevel: 'DEBUG'
};
"@
        Set-Content -Path $envDevPath -Value $envDevContent -Encoding UTF8
        Write-Host "Environment configured with API URL and logging: https://$webAppName.azurewebsites.net" -ForegroundColor Green

        # Build and scan locally before pushing to ACR
        if (-not $NoSecurityScan) {
            Write-Host "Building and scanning Frontend Docker image locally..." -ForegroundColor Yellow
            Push-Location $frontendPath
            try {
                $buildScript = Join-Path $frontendPath "build-localFrontEnd.ps1"
                & $buildScript -Rebuild -MaxSeverity high
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Security scan failed. Fix vulnerabilities before deploying." -ForegroundColor Red
                    Write-Host "Review vulnerabilities with: docker scout cves grooveapp-frontend" -ForegroundColor Yellow
                    Pop-Location
                    exit 1
                }
                Write-Host "✅ Security scan passed - No HIGH or CRITICAL CVEs detected`n" -ForegroundColor Green
            }
            catch {
                Write-Host "Error during build/scan: $_" -ForegroundColor Red
                Pop-Location
                exit 1
            }
            finally {
                Pop-Location
            }
        }

        # Generate unique tag for grooveapp-frontend repository
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $frontendImageTag = "grooveapp-frontend:$timestamp"
        $frontendLatestTag = "grooveapp-frontend:latest"

        # Build and push frontend image to ACR with both unique and latest tags
        Write-Host "Pushing image to ACR repository 'grooveapp-frontend' with tags: $timestamp and latest" -ForegroundColor Yellow
        az acr build `
            --registry $acrName `
            --image $frontendImageTag `
            --image $frontendLatestTag `
            --file $frontendDockerfilePath `
            --build-arg SKIP_AUDIT=true `
            --build-arg BUILD_CONFIGURATION=dev `
            $frontendPath

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Frontend Docker image build failed" -ForegroundColor Red
            Write-Host "Check the build output above for details" -ForegroundColor Yellow
            exit 1
        }

        Write-Host "Frontend Docker image built and pushed successfully`n" -ForegroundColor Green
    }
    else {
        Write-Host "Step 7: Skipping Frontend image build (using existing latest image)`n" -ForegroundColor Yellow
    }

    # Create staging slot if it doesn't exist
    Write-Host "Step 8: Ensuring Frontend staging slot exists..." -ForegroundColor Cyan
    $frontendSlotExists = az webapp deployment slot list `
        --name $frontendWebAppName `
        --resource-group $resourceGroupName `
        --query "[?name=='$stagingSlotName'].name" `
        -o tsv

    if (-not $frontendSlotExists) {
        Write-Host "Creating staging slot for Frontend..." -ForegroundColor Yellow
        az webapp deployment slot create `
            --name $frontendWebAppName `
            --resource-group $resourceGroupName `
            --slot $stagingSlotName `
            --configuration-source $frontendWebAppName `
            --output none
        Write-Host "Staging slot created" -ForegroundColor Green
    }
    else {
        Write-Host "Staging slot already exists" -ForegroundColor Green
    }

    # Deploy to staging slot
    Write-Host "Step 9: Deploying Frontend to staging slot..." -ForegroundColor Cyan
    
    # Configure WEBSITES_PORT for nginx (listens on 8080)
    az webapp config appsettings set `
        --name $frontendWebAppName `
        --resource-group $resourceGroupName `
        --slot $stagingSlotName `
        --settings WEBSITES_PORT=8080 `
        --output none
    
    az webapp config container set `
        --name $frontendWebAppName `
        --resource-group $resourceGroupName `
        --slot $stagingSlotName `
        --docker-custom-image-name "$acrName.azurecr.io/grooveapp-frontend:latest" `
        --docker-registry-server-url "https://$acrName.azurecr.io" `
        --docker-registry-server-user $acrCredentials.username `
        --docker-registry-server-password $acrCredentials.passwords[0].value `
        --output none

    Write-Host "Frontend deployed to staging slot" -ForegroundColor Green
    Write-Host "Staging URL: https://$frontendWebAppName-$stagingSlotName.azurewebsites.net" -ForegroundColor White
    Write-Host ""

    # Wait for staging slot to warm up
    Write-Host "Waiting for frontend staging slot to warm up..." -ForegroundColor Yellow
    Start-Sleep -Seconds 20

    # Health check on staging (check if page loads)
    Write-Host "Performing health check on frontend staging slot..." -ForegroundColor Yellow
    $frontendStagingUrl = "https://$frontendWebAppName-$stagingSlotName.azurewebsites.net"
    $maxRetries = 5
    $retryCount = 0
    $healthy = $false

    while ($retryCount -lt $maxRetries -and -not $healthy) {
        try {
            # For frontend with Easy Auth, check if we get either 200 (allowed) or 302 (redirect to login)
            # Both indicate the app is running
            $response = Invoke-WebRequest -Uri $frontendStagingUrl -Method Get -TimeoutSec 10 -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
                $healthy = $true
                Write-Host "✅ Frontend staging slot is healthy" -ForegroundColor Green
            }
        }
        catch {
            # Check if it's a redirect (302) which is expected with Easy Auth
            if ($_.Exception.Response.StatusCode -eq 'Redirect') {
                $healthy = $true
                Write-Host "✅ Frontend staging slot is healthy (redirecting to auth)" -ForegroundColor Green
            }
            else {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Health check failed, retrying... ($retryCount/$maxRetries)" -ForegroundColor Yellow
                    Start-Sleep -Seconds 10
                }
                else {
                    Write-Host "⚠️ Warning: Health check failed after $maxRetries attempts" -ForegroundColor Red
                    Write-Host "You may want to check the logs before swapping:" -ForegroundColor Yellow
                    Write-Host "  az webapp log tail --name $frontendWebAppName --resource-group $resourceGroupName --slot $stagingSlotName" -ForegroundColor White
                    
                    $continue = Read-Host "Continue with swap anyway? (y/N)"
                    if ($continue -ne "y" -and $continue -ne "Y") {
                        Write-Host "Deployment cancelled`n" -ForegroundColor Red
                        exit 1
                    }
                }
            }
        }
    }

    # Swap slots
    if (-not $SkipSwap) {
        Write-Host "Step 10: Swapping frontend staging to production..." -ForegroundColor Cyan
        Write-Host "This will perform a zero-downtime deployment" -ForegroundColor Yellow
        
        az webapp deployment slot swap `
            --name $frontendWebAppName `
            --resource-group $resourceGroupName `
            --slot $stagingSlotName `
            --target-slot production `
            --output none

        Write-Host "✅ Frontend swap complete!" -ForegroundColor Green
        Write-Host "Production URL: https://$frontendWebAppName.azurewebsites.net`n" -ForegroundColor White
    }
    else {
        Write-Host "Step 10: Skipping slot swap (manual swap required)`n" -ForegroundColor Yellow
        Write-Host "To manually swap slots, run:" -ForegroundColor White
        Write-Host "  az webapp deployment slot swap --name $frontendWebAppName --resource-group $resourceGroupName --slot $stagingSlotName`n" -ForegroundColor Gray
    }
}

# Final summary
Write-Host "======================================"
Write-Host "Deployment Complete!"
Write-Host "======================================"
Write-Host ""

if ($deployApi) {
    Write-Host "✅ API deployed successfully" -ForegroundColor Green
    Write-Host "   Production: https://$webAppName.azurewebsites.net" -ForegroundColor White
    Write-Host "   Staging: https://$webAppName-$stagingSlotName.azurewebsites.net" -ForegroundColor White
    Write-Host ""
}

if ($deployFrontend) {
    Write-Host "✅ Frontend deployed successfully" -ForegroundColor Green
    Write-Host "   Production: https://$frontendWebAppName.azurewebsites.net" -ForegroundColor White
    Write-Host "   Staging: https://$frontendWebAppName-$stagingSlotName.azurewebsites.net" -ForegroundColor White
    Write-Host ""
}

Write-Host "Usage Examples:" -ForegroundColor Cyan
Write-Host "  Deploy both API and Frontend:" -ForegroundColor White
Write-Host "    .\deploy-updates.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  Deploy only API:" -ForegroundColor White
Write-Host "    .\deploy-updates.ps1 -ApiOnly" -ForegroundColor Gray
Write-Host ""
Write-Host "  Deploy only Frontend:" -ForegroundColor White
Write-Host "    .\deploy-updates.ps1 -FrontendOnly" -ForegroundColor Gray
Write-Host ""
Write-Host "  Skip build (use existing images):" -ForegroundColor White
Write-Host "    .\deploy-updates.ps1 -SkipBuild" -ForegroundColor Gray
Write-Host ""
Write-Host "  Deploy to staging only (no swap):" -ForegroundColor White
Write-Host "    .\deploy-updates.ps1 -SkipSwap" -ForegroundColor Gray
Write-Host ""
Write-Host "  Skip security scan:" -ForegroundColor White
Write-Host "    .\deploy-updates.ps1 -NoSecurityScan" -ForegroundColor Gray
Write-Host ""

if (-not $SkipSwap) {
    Write-Host "Rollback Instructions:" -ForegroundColor Yellow
    Write-Host "  If you need to rollback, simply swap the slots again:" -ForegroundColor White
    if ($deployApi) {
        Write-Host "    az webapp deployment slot swap --name $webAppName --resource-group $resourceGroupName --slot $stagingSlotName" -ForegroundColor Gray
    }
    if ($deployFrontend) {
        Write-Host "    az webapp deployment slot swap --name $frontendWebAppName --resource-group $resourceGroupName --slot $stagingSlotName" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "Monitor logs:" -ForegroundColor Cyan
if ($deployApi) {
    Write-Host "  API Production: az webapp log tail --name $webAppName --resource-group $resourceGroupName" -ForegroundColor White
    Write-Host "  API Staging: az webapp log tail --name $webAppName --resource-group $resourceGroupName --slot $stagingSlotName" -ForegroundColor White
}
if ($deployFrontend) {
    Write-Host "  Frontend Production: az webapp log tail --name $frontendWebAppName --resource-group $resourceGroupName" -ForegroundColor White
    Write-Host "  Frontend Staging: az webapp log tail --name $frontendWebAppName --resource-group $resourceGroupName --slot $stagingSlotName" -ForegroundColor White
}
Write-Host ""
