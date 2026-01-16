# Troubleshoot API Health Issues
# This script helps diagnose why the App Service is reporting as unhealthy

param(
    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev",
    [Parameter(Mandatory = $false)]
    [switch]$OpenPortal
)

$resourceGroupName = "rg-grooveapp-$Environment"
$apiWebAppName = "app-grooveapp-$Environment-api"
$workspaceName = "law-grooveapp-$Environment-uhxg"

Write-Host "======================================"
Write-Host "API Health Troubleshooting"
Write-Host "======================================"
Write-Host ""
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Cyan
Write-Host "API Web App: $apiWebAppName" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check current health status
Write-Host "Step 1: Checking current health status..." -ForegroundColor Yellow
$apiUrl = "https://$apiWebAppName.azurewebsites.net"
$healthUrl = "$apiUrl/health"

Write-Host "Health URL: $healthUrl" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri $healthUrl -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✓ Health check endpoint returned: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Health check failed!" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Step 2: Get App Service status
Write-Host "Step 2: Checking App Service status..." -ForegroundColor Yellow
$webApp = az webapp show --name $apiWebAppName --resource-group $resourceGroupName | ConvertFrom-Json
Write-Host "State: $($webApp.state)" -ForegroundColor $(if ($webApp.state -eq 'Running') { 'Green' } else { 'Red' })
Write-Host "Availability State: $($webApp.availabilityState)" -ForegroundColor $(if ($webApp.availabilityState -eq 'Normal') { 'Green' } else { 'Red' })
Write-Host "Enabled: $($webApp.enabled)" -ForegroundColor Gray
Write-Host ""

# Step 3: Check recent logs
Write-Host "Step 3: Fetching recent application logs..." -ForegroundColor Yellow
Write-Host "Streaming last 100 lines (Ctrl+C to stop)..." -ForegroundColor Gray
Write-Host ""
az webapp log tail --name $apiWebAppName --resource-group $resourceGroupName --only-show-errors 2>$null | Select-Object -First 100
Write-Host ""

# Step 4: Get container logs
Write-Host "Step 4: Checking container/Docker logs..." -ForegroundColor Yellow
$logFiles = az webapp log download --name $apiWebAppName --resource-group $resourceGroupName --log-file "api-logs.zip" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Logs downloaded to api-logs.zip" -ForegroundColor Green
    Write-Host "Extract and check:" -ForegroundColor Yellow
    Write-Host "  - LogFiles/Application/*.txt - Application logs" -ForegroundColor White
    Write-Host "  - LogFiles/Docker/*.log - Container logs" -ForegroundColor White
    Write-Host "  - LogFiles/kudu/trace/*.txt - Deployment logs" -ForegroundColor White
}
else {
    Write-Host "⚠️ Could not download logs" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Check environment variables
Write-Host "Step 5: Checking critical environment variables..." -ForegroundColor Yellow
$appSettings = az webapp config appsettings list --name $apiWebAppName --resource-group $resourceGroupName | ConvertFrom-Json

$criticalSettings = @(
    'SQL_SERVER',
    'SQL_DATABASE',
    'APPLICATIONINSIGHTS_CONNECTION_STRING',
    'WEBSITES_PORT',
    'LOG_LEVEL'
)

foreach ($setting in $criticalSettings) {
    $value = $appSettings | Where-Object { $_.name -eq $setting } | Select-Object -ExpandProperty value
    if ($value) {
        if ($setting -like '*CONNECTION*' -or $setting -like '*SECRET*') {
            Write-Host "  $setting = [REDACTED]" -ForegroundColor Gray
        }
        else {
            Write-Host "  $setting = $value" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  $setting = [NOT SET]" -ForegroundColor Red
    }
}
Write-Host ""

# Step 6: Provide Log Analytics queries
Write-Host "======================================"
Write-Host "Log Analytics & Application Insights Queries"
Write-Host "======================================"
Write-Host ""
Write-Host "Workspace: $workspaceName" -ForegroundColor Cyan
Write-Host ""

Write-Host "Query 1: Recent App Service HTTP Logs (Last Hour)" -ForegroundColor Yellow
Write-Host "Go to: Azure Portal > Log Analytics Workspace > Logs" -ForegroundColor White
Write-Host ""
$query1 = @"
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where _ResourceId contains '$apiWebAppName'
| project TimeGenerated, ScStatus, CsMethod, CsUriStem, TimeTaken, CsHost
| order by TimeGenerated desc
| take 50
"@
Write-Host $query1 -ForegroundColor Gray
Write-Host ""

Write-Host "Query 2: Application Errors (Last Hour)" -ForegroundColor Yellow
$query2 = @"
AppServiceConsoleLogs
| where TimeGenerated > ago(1h)
| where _ResourceId contains '$apiWebAppName'
| where ResultDescription contains 'error' or ResultDescription contains 'Error' or ResultDescription contains 'ERROR'
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
| take 50
"@
Write-Host $query2 -ForegroundColor Gray
Write-Host ""

Write-Host "Query 3: Health Check Failures" -ForegroundColor Yellow
$query3 = @"
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where _ResourceId contains '$apiWebAppName'
| where CsUriStem == '/health'
| project TimeGenerated, ScStatus, TimeTaken, CsHost
| order by TimeGenerated desc
| take 50
"@
Write-Host $query3 -ForegroundColor Gray
Write-Host ""

Write-Host "Query 4: Application Insights Exceptions" -ForegroundColor Yellow
$query4 = @"
exceptions
| where timestamp > ago(1h)
| where cloud_RoleName == '$apiWebAppName'
| project timestamp, type, outerMessage, innermostMessage, operation_Name
| order by timestamp desc
| take 50
"@
Write-Host $query4 -ForegroundColor Gray
Write-Host ""

Write-Host "Query 5: Application Insights Failed Requests" -ForegroundColor Yellow
$query5 = @"
requests
| where timestamp > ago(1h)
| where cloud_RoleName == '$apiWebAppName'
| where success == false
| project timestamp, name, url, resultCode, duration
| order by timestamp desc
| take 50
"@
Write-Host $query5 -ForegroundColor Gray
Write-Host ""

Write-Host "Query 6: Authentication/Authorization Logs" -ForegroundColor Yellow
$query6 = @"
AppServiceConsoleLogs
| where TimeGenerated > ago(1h)
| where _ResourceId contains '$apiWebAppName'
| where ResultDescription contains 'auth' or ResultDescription contains 'token' or ResultDescription contains 'Easy Auth'
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
| take 50
"@
Write-Host $query6 -ForegroundColor Gray
Write-Host ""

# Step 7: Common issues and solutions
Write-Host "======================================"
Write-Host "Common Issues & Solutions"
Write-Host "======================================"
Write-Host ""

Write-Host "1. Container Not Starting:" -ForegroundColor Yellow
Write-Host "   - Check Docker logs for startup errors" -ForegroundColor White
Write-Host "   - Verify WEBSITES_PORT matches container's port (8000)" -ForegroundColor White
Write-Host "   - Check if database connection is failing" -ForegroundColor White
Write-Host ""

Write-Host "2. Health Check Timing Out:" -ForegroundColor Yellow
Write-Host "   - Health check path is /health (verify it's correct)" -ForegroundColor White
Write-Host "   - Check if Easy Auth is blocking /health (should be excluded)" -ForegroundColor White
Write-Host "   - Increase health check timeout if app is slow to start" -ForegroundColor White
Write-Host ""

Write-Host "3. Database Connection Issues:" -ForegroundColor Yellow
Write-Host "   - Verify SQL_SERVER and SQL_DATABASE environment variables" -ForegroundColor White
Write-Host "   - Check if managed identity has database access" -ForegroundColor White
Write-Host "   - Verify VNet integration if using private endpoints" -ForegroundColor White
Write-Host ""

Write-Host "4. Easy Auth Configuration:" -ForegroundColor Yellow
Write-Host "   - /health endpoint should be in excluded_paths" -ForegroundColor White
Write-Host "   - unauthenticated_action should be 'Return401' for APIs" -ForegroundColor White
Write-Host "   - Check allowed_audiences includes frontend app ID" -ForegroundColor White
Write-Host ""

Write-Host "5. Application Insights:" -ForegroundColor Yellow
Write-Host "   - Verify APPLICATIONINSIGHTS_CONNECTION_STRING is set" -ForegroundColor White
Write-Host "   - Check Application Insights for exceptions/failures" -ForegroundColor White
Write-Host ""

# Step 8: Quick actions
Write-Host "======================================"
Write-Host "Quick Actions"
Write-Host "======================================"
Write-Host ""

Write-Host "Restart the app:" -ForegroundColor Yellow
Write-Host "  az webapp restart --name $apiWebAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host ""

Write-Host "View live logs:" -ForegroundColor Yellow
Write-Host "  az webapp log tail --name $apiWebAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host ""

Write-Host "Open Azure Portal (App Service):" -ForegroundColor Yellow
Write-Host "  https://portal.azure.com/#@/resource/subscriptions/7a06440f-dea7-4668-8d49-5b7c4ebcf187/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$apiWebAppName" -ForegroundColor White
Write-Host ""

Write-Host "Open Application Insights:" -ForegroundColor Yellow
Write-Host "  https://portal.azure.com/#@/resource/subscriptions/7a06440f-dea7-4668-8d49-5b7c4ebcf187/resourceGroups/$resourceGroupName/providers/Microsoft.Insights/components/appi-grooveapp" -ForegroundColor White
Write-Host ""

if ($OpenPortal) {
    Write-Host "Opening Azure Portal..." -ForegroundColor Green
    Start-Process "https://portal.azure.com/#@/resource/subscriptions/7a06440f-dea7-4668-8d49-5b7c4ebcf187/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$apiWebAppName"
}
