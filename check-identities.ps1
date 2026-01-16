Write-Host "Checking managed identity principal names..." -ForegroundColor Cyan
Write-Host ""

# Get API production app identity
$apiProd = az webapp identity show --name "app-grooveapp-dev-api" --resource-group "rg-grooveapp-dev" --query principalId -o tsv
Write-Host "API Production Principal ID: $apiProd" -ForegroundColor Yellow

# Get the actual service principal name
$apiProdName = az ad sp show --id $apiProd --query displayName -o tsv
Write-Host "API Production Display Name: $apiProdName" -ForegroundColor Green
Write-Host ""

# Get API staging slot identity  
$apiStaging = az webapp identity show --name "app-grooveapp-dev-api" --resource-group "rg-grooveapp-dev" --slot "staging" --query principalId -o tsv
Write-Host "API Staging Principal ID: $apiStaging" -ForegroundColor Yellow

# Get the actual service principal name
$apiStagingName = az ad sp show --id $apiStaging --query displayName -o tsv  
Write-Host "API Staging Display Name: $apiStagingName" -ForegroundColor Green
Write-Host ""

Write-Host "Now checking database users..." -ForegroundColor Cyan
Write-Host ""

# Query database for existing users
$token = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv
$query = "SELECT name, type_desc, authentication_type_desc FROM sys.database_principals WHERE type IN ('E', 'X') ORDER BY name"

Invoke-Sqlcmd -ServerInstance "sql-grooveapp-dev-uhxg.database.windows.net" -Database "sqldb-grooveapp-dev" -AccessToken $token -Query $query | Format-Table -AutoSize
