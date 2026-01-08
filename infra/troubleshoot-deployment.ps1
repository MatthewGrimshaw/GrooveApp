# GrooveApp Deployment Troubleshooting Script
# Helps diagnose deployment and Easy Auth issues

param(
    [ValidateSet('api', 'frontend', 'both')]
    [string]$Service = 'both'
)

$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"
$resourceGroupName = "rg-grooveapp-dev"
$webAppName = "app-grooveapp-dev-api"
$frontendWebAppName = "app-grooveapp-dev-frontend"

Write-Host "======================================"
Write-Host "GrooveApp Deployment Diagnostics"
Write-Host "======================================"
Write-Host ""

# Authenticate
Write-Host "Authenticating with Azure..." -ForegroundColor Cyan
az login --tenant $tenantId --output none 2>$null
az account set --subscription $subscriptionId
Write-Host "✅ Authenticated`n" -ForegroundColor Green

# Function to check webapp status
function Check-WebAppStatus {
    param(
        [string]$AppName,
        [string]$DisplayName
    )

    Write-Host "======================================"
    Write-Host "$DisplayName Status"
    Write-Host "======================================"
    Write-Host ""

    # Get web app details
    Write-Host "Web App Configuration:" -ForegroundColor Cyan
    $webApp = az webapp show --name $AppName --resource-group $resourceGroupName | ConvertFrom-Json
    Write-Host "  State: $($webApp.state)" -ForegroundColor $(if ($webApp.state -eq 'Running') { 'Green' } else { 'Red' })
    Write-Host "  Location: $($webApp.location)"
    Write-Host "  Default Hostname: https://$($webApp.defaultHostName)"
    Write-Host ""

    # Check which slots exist
    Write-Host "Deployment Slots:" -ForegroundColor Cyan
    $slots = az webapp deployment slot list --name $AppName --resource-group $resourceGroupName | ConvertFrom-Json
    if ($slots.Count -eq 0) {
        Write-Host "  No staging slots found" -ForegroundColor Yellow
    }
    else {
        foreach ($slot in $slots) {
            Write-Host "  - $($slot.name): $($slot.state)" -ForegroundColor $(if ($slot.state -eq 'Running') { 'Green' } else { 'Red' })
            Write-Host "    URL: https://$($slot.defaultHostName)"
        }
    }
    Write-Host ""

    # Check Easy Auth configuration
    Write-Host "Easy Auth Configuration:" -ForegroundColor Cyan
    $authSettings = az webapp auth show --name $AppName --resource-group $resourceGroupName | ConvertFrom-Json
    
    if ($authSettings.enabled -eq $true) {
        Write-Host "  ✅ Easy Auth: ENABLED" -ForegroundColor Green
        Write-Host "  Provider: Azure Active Directory"
        Write-Host "  Client ID: $($authSettings.clientId)"
        Write-Host "  Unauthenticated Action: $($authSettings.unauthenticatedClientAction)"
        
        # Check if client secret is configured
        $appSettings = az webapp config appsettings list --name $AppName --resource-group $resourceGroupName | ConvertFrom-Json
        $clientSecretSetting = $appSettings | Where-Object { $_.name -eq 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET' }
        if ($clientSecretSetting) {
            Write-Host "  ✅ Client Secret: Configured" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ Client Secret: NOT CONFIGURED" -ForegroundColor Red
            Write-Host "     This is likely causing authentication failures!" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ⚠️  Easy Auth: DISABLED" -ForegroundColor Yellow
    }
    Write-Host ""

    # Check container configuration
    Write-Host "Container Configuration:" -ForegroundColor Cyan
    $containerSettings = az webapp config container show --name $AppName --resource-group $resourceGroupName | ConvertFrom-Json
    if ($containerSettings) {
        Write-Host "  Image: $($containerSettings[0].value)" -ForegroundColor White
        Write-Host "  Registry: $($containerSettings | Where-Object { $_.name -eq 'DOCKER_REGISTRY_SERVER_URL' } | Select-Object -ExpandProperty value)" -ForegroundColor White
    }
    Write-Host ""

    # Get recent logs
    Write-Host "Recent Application Logs (last 20 lines):" -ForegroundColor Cyan
    Write-Host "Production Slot:" -ForegroundColor Yellow
    try {
        az webapp log tail --name $AppName --resource-group $resourceGroupName --only-show-errors 2>&1 | Select-Object -First 20
    }
    catch {
        Write-Host "  Unable to fetch logs - may need to enable logging" -ForegroundColor Yellow
    }
    
    if ($slots.Count -gt 0) {
        Write-Host "`nStaging Slot:" -ForegroundColor Yellow
        try {
            az webapp log tail --name $AppName --resource-group $resourceGroupName --slot staging --only-show-errors 2>&1 | Select-Object -First 20
        }
        catch {
            Write-Host "  Unable to fetch staging logs" -ForegroundColor Yellow
        }
    }
    Write-Host ""

    # Check for deployment slots and their config
    if ($slots.Count -gt 0) {
        Write-Host "Staging Slot Easy Auth Configuration:" -ForegroundColor Cyan
        $stagingAuthSettings = az webapp auth show --name $AppName --resource-group $resourceGroupName --slot staging 2>$null | ConvertFrom-Json
        if ($stagingAuthSettings.enabled -eq $true) {
            Write-Host "  ✅ Easy Auth: ENABLED" -ForegroundColor Green
            Write-Host "  Client ID: $($stagingAuthSettings.clientId)"
        }
        else {
            Write-Host "  ⚠️  Easy Auth: DISABLED" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Test endpoints
    Write-Host "Endpoint Health Check:" -ForegroundColor Cyan
    Write-Host "Testing Production URL..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "https://$($webApp.defaultHostName)" -Method Get -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction Stop
        Write-Host "  Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 302 -or $statusCode -eq 307) {
            Write-Host "  Status: $statusCode (Redirect - likely to authentication)" -ForegroundColor Green
            Write-Host "  Redirect Location: $($_.Exception.Response.Headers.Location)" -ForegroundColor White
        }
        elseif ($statusCode -eq 403) {
            Write-Host "  Status: 403 Forbidden" -ForegroundColor Yellow
            Write-Host "  This may indicate Easy Auth is working but you're not authorized" -ForegroundColor Yellow
        }
        else {
            Write-Host "  Status: $statusCode" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($slots.Count -gt 0) {
        Write-Host "`nTesting Staging URL..." -ForegroundColor Yellow
        try {
            $stagingUrl = "https://$($webApp.defaultHostName.Replace('.azurewebsites.net', '-staging.azurewebsites.net'))"
            $response = Invoke-WebRequest -Uri $stagingUrl -Method Get -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction Stop
            Write-Host "  Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 302 -or $statusCode -eq 307) {
                Write-Host "  Status: $statusCode (Redirect - likely to authentication)" -ForegroundColor Green
                Write-Host "  Redirect Location: $($_.Exception.Response.Headers.Location)" -ForegroundColor White
            }
            elseif ($statusCode -eq 403) {
                Write-Host "  Status: 403 Forbidden" -ForegroundColor Yellow
            }
            else {
                Write-Host "  Status: $statusCode" -ForegroundColor Red
                Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    Write-Host ""
}

# Check API
if ($Service -eq 'api' -or $Service -eq 'both') {
    Check-WebAppStatus -AppName $webAppName -DisplayName "API"
}

# Check Frontend
if ($Service -eq 'frontend' -or $Service -eq 'both') {
    Check-WebAppStatus -AppName $frontendWebAppName -DisplayName "Frontend"
}

# Summary and recommendations
Write-Host "======================================"
Write-Host "Troubleshooting Recommendations"
Write-Host "======================================"
Write-Host ""

Write-Host "Common Issues:" -ForegroundColor Cyan
Write-Host "1. Client Secret Not Configured:" -ForegroundColor Yellow
Write-Host "   - Easy Auth requires MICROSOFT_PROVIDER_AUTHENTICATION_SECRET" -ForegroundColor White
Write-Host "   - Run: terraform apply to update with new secrets from Terraform" -ForegroundColor White
Write-Host ""

Write-Host "2. Container Not Started:" -ForegroundColor Yellow
Write-Host "   - Check if container image is pulling correctly" -ForegroundColor White
Write-Host "   - View live logs: az webapp log tail --name <app-name> --resource-group $resourceGroupName" -ForegroundColor White
Write-Host ""

Write-Host "3. Wrong Slot Active:" -ForegroundColor Yellow
Write-Host "   - If you deployed with -SkipSwap, your changes are in STAGING only" -ForegroundColor White
Write-Host "   - Swap slots: az webapp deployment slot swap --name <app-name> --resource-group $resourceGroupName --slot staging" -ForegroundColor White
Write-Host ""

Write-Host "4. Redirect URI Mismatch:" -ForegroundColor Yellow
Write-Host "   - Check App Registration redirect URIs match your web app URLs" -ForegroundColor White
Write-Host "   - Should include: https://<app-name>.azurewebsites.net/.auth/login/aad/callback" -ForegroundColor White
Write-Host ""

Write-Host "5. App Registration Permissions:" -ForegroundColor Yellow
Write-Host "   - Ensure service principal exists and has correct permissions" -ForegroundColor White
Write-Host ""

Write-Host "Detailed Log Commands:" -ForegroundColor Cyan
Write-Host "  # Stream live logs from production" -ForegroundColor White
Write-Host "  az webapp log tail --name $webAppName --resource-group $resourceGroupName" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Stream live logs from staging" -ForegroundColor White
Write-Host "  az webapp log tail --name $webAppName --resource-group $resourceGroupName --slot staging" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Download logs" -ForegroundColor White
Write-Host "  az webapp log download --name $webAppName --resource-group $resourceGroupName --log-file logs.zip" -ForegroundColor Gray
Write-Host ""
Write-Host "  # View App Insights logs (if configured)" -ForegroundColor White
Write-Host "  az monitor app-insights query --app <app-insights-name> --analytics-query 'requests | take 50'" -ForegroundColor Gray
Write-Host ""

Write-Host "Azure Portal Checks:" -ForegroundColor Cyan
Write-Host "  1. Navigate to: https://portal.azure.com" -ForegroundColor White
Write-Host "  2. Go to your App Service" -ForegroundColor White
Write-Host "  3. Check: Deployment Center > Logs (to see container pull status)" -ForegroundColor White
Write-Host "  4. Check: Log stream (real-time application logs)" -ForegroundColor White
Write-Host "  5. Check: Authentication (verify Easy Auth settings)" -ForegroundColor White
Write-Host "  6. Check: Configuration (verify app settings and connection strings)" -ForegroundColor White
Write-Host ""
