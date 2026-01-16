# Quick check for container issues in Log Analytics
$query = @"
AppServiceConsoleLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev-api'
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
| take 100
"@

Write-Host "Run this query in Azure Portal:" -ForegroundColor Yellow
Write-Host "Portal > Log Analytics Workspaces > law-grooveapp-dev-uhxg > Logs" -ForegroundColor White
Write-Host ""
Write-Host $query -ForegroundColor Cyan
Write-Host ""
Write-Host "Or check these critical queries:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Container Pull Errors:" -ForegroundColor Cyan
Write-Host @"
AppServiceConsoleLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev-api'
| where ResultDescription contains 'pull' or ResultDescription contains 'docker' or ResultDescription contains 'container'
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
"@ -ForegroundColor White
Write-Host ""
Write-Host "2. Authentication/ACR Errors:" -ForegroundColor Cyan
Write-Host @"
AppServiceConsoleLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev-api'
| where ResultDescription contains '401' or ResultDescription contains 'unauthorized' or ResultDescription contains 'authentication'
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
"@ -ForegroundColor White
Write-Host ""
Write-Host "3. Container Start/Exit:" -ForegroundColor Cyan
Write-Host @"
AppServiceConsoleLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev-api'
| where ResultDescription contains 'start' or ResultDescription contains 'exit' or ResultDescription contains 'crash'
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
"@ -ForegroundColor White
Write-Host ""
Write-Host "4. Easy Auth Authentication Logs (Preview):" -ForegroundColor Cyan
Write-Host @"
AppServiceAuthenticationLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev'
| project TimeGenerated, 
    Resource = split(_ResourceId, '/')[8], 
    Level, 
    StatusCode, 
    Result, 
    Message, 
    Identity = IdentityName,
    ClientIP
| order by TimeGenerated desc
"@ -ForegroundColor White
Write-Host ""
Write-Host "5. Easy Auth Failures (401/403):" -ForegroundColor Cyan
Write-Host @"
AppServiceAuthenticationLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev'
| where StatusCode in (401, 403) or Result != 'Success'
| project TimeGenerated, 
    Resource = split(_ResourceId, '/')[8],
    StatusCode, 
    Result, 
    Message,
    Identity = IdentityName
| order by TimeGenerated desc
"@ -ForegroundColor White
Write-Host ""
Write-Host "6. Token Acquisition Logs:" -ForegroundColor Cyan
Write-Host @"
AppServiceAuthenticationLogs
| where TimeGenerated > ago(2h)
| where _ResourceId contains 'app-grooveapp-dev'
| where Message contains 'token' or Message contains 'Token'
| project TimeGenerated, 
    Resource = split(_ResourceId, '/')[8],
    Level,
    Message,
    StatusCode
| order by TimeGenerated desc
"@ -ForegroundColor White
