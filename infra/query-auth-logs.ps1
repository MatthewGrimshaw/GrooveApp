# Query App Service Authentication and HTTP Logs
# This script checks for Easy Auth failures and 401 errors

param(
    [int]$LastMinutes = 60
)

Write-Host "Getting Log Analytics Workspace ID..." -ForegroundColor Cyan
$workspaceId = az monitor log-analytics workspace show `
    --resource-group "rg-grooveapp-dev" `
    --workspace-name "log-grooveapp-dev-uhxg" `
    --query customerId `
    -o tsv

if (-not $workspaceId) {
    Write-Host "ERROR: Could not retrieve workspace ID" -ForegroundColor Red
    exit 1
}

Write-Host "Workspace ID: $workspaceId" -ForegroundColor Green
Write-Host ""

# Query 1: Authentication logs
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Authentication Logs (last $LastMinutes minutes)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$authQuery = @"
AppServiceAuthenticationLogs
| where TimeGenerated > ago($($LastMinutes)m)
| where ResourceId contains 'app-grooveapp-dev-api'
| project TimeGenerated, Level, OperationName, Details, StatusCode, CallerIpAddress
| order by TimeGenerated desc
| take 50
"@

az monitor log-analytics query `
    --workspace $workspaceId `
    --analytics-query $authQuery `
    --output table

Write-Host ""

# Query 2: HTTP 401 errors
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "HTTP 401 Errors (last $LastMinutes minutes)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$httpQuery = @"
AppServiceHTTPLogs
| where TimeGenerated > ago($($LastMinutes)m)
| where ResourceId contains 'app-grooveapp-dev-api'
| where ScStatus == 401
| project TimeGenerated, CsHost, CsUriStem, CsMethod, ScStatus, CsUserAgent, CIp
| order by TimeGenerated desc
| take 50
"@

az monitor log-analytics query `
    --workspace $workspaceId `
    --analytics-query $httpQuery `
    --output table

Write-Host ""

# Query 3: All API requests in last 10 minutes
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Recent API Requests (last 10 minutes)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$recentQuery = @"
AppServiceHTTPLogs
| where TimeGenerated > ago(10m)
| where ResourceId contains 'app-grooveapp-dev-api'
| project TimeGenerated, CsHost, CsUriStem, CsMethod, ScStatus, TimeTaken
| order by TimeGenerated desc
| take 20
"@

az monitor log-analytics query `
    --workspace $workspaceId `
    --analytics-query $recentQuery `
    --output table

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Summary:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "- 401 errors are EXPECTED when Easy Auth is enabled and no authentication token is provided" -ForegroundColor Cyan
Write-Host "- To access the API, you need to:"
Write-Host "  1. Authenticate through the frontend (which has Easy Auth configured)" -ForegroundColor Yellow
Write-Host "  2. Or use the health endpoint: /health (if not protected)" -ForegroundColor Yellow
Write-Host "  3. Or disable Easy Auth temporarily by setting enable_authentication = false in dev.tfvars" -ForegroundColor Yellow
Write-Host ""
