# GrooveApp Complete Infrastructure Cleanup Script
# Deletes all Azure resources, App Registrations, and Entra ID groups

# Variables
$tenantId = "44e2b0ad-2191-469a-aeaa-76f87ca1f198"
$subscriptionId = "7a06440f-dea7-4668-8d49-5b7c4ebcf187"
$resourceGroupName = "rg-grooveapp"
$sqlServerName = "sql-grooveapp"
$acrName = "acrgrooveapp"
$webAppName = "webapp-grooveapp-api"
$entraIdGroupName = "GrooveApp-Users"
$appRegName = "$webAppName-auth"

Write-Host "======================================"
Write-Host "GrooveApp Infrastructure Cleanup"
Write-Host "======================================"
Write-Host ""
Write-Host "WARNING: This will delete ALL resources created by the deployment script!" -ForegroundColor Red
Write-Host "  - Resource Group: $resourceGroupName" -ForegroundColor Yellow
Write-Host "  - SQL Server: $sqlServerName" -ForegroundColor Yellow
Write-Host "  - Container Registry: $acrName" -ForegroundColor Yellow
Write-Host "  - Web App: $webAppName" -ForegroundColor Yellow
Write-Host "  - Entra ID Group: $entraIdGroupName" -ForegroundColor Yellow
Write-Host "  - App Registration: $appRegName" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Are you sure you want to proceed? Type 'DELETE' to confirm"
if ($confirmation -ne "DELETE") {
    Write-Host "Cleanup cancelled." -ForegroundColor Green
    exit 0
}

Write-Host ""

# Authentication
Write-Host "Step 1: Authenticating with Azure..." -ForegroundColor Cyan
az login --tenant $tenantId
az account set --subscription $subscriptionId
Write-Host "Authentication successful`n" -ForegroundColor Green

# Delete App Registration
Write-Host "Step 2: Deleting App Registration..." -ForegroundColor Cyan
try {
    $existingApp = az ad app list --filter "displayName eq '$appRegName'" --query "[0]" -o json | ConvertFrom-Json
    
    if ($existingApp) {
        $appId = $existingApp.appId
        Write-Host "Found App Registration: $appRegName (AppId: $appId)" -ForegroundColor Yellow
        
        # Delete service principal first
        $spObjectId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv
        if ($spObjectId) {
            Write-Host "Deleting Service Principal..." -ForegroundColor Yellow
            az ad sp delete --id $spObjectId
            Write-Host "Service Principal deleted" -ForegroundColor Green
        }
        
        # Delete app registration
        az ad app delete --id $appId
        Write-Host "App Registration deleted: $appRegName`n" -ForegroundColor Green
    } else {
        Write-Host "App Registration not found (already deleted or never created)`n" -ForegroundColor Gray
    }
} catch {
    Write-Host "Warning: Could not delete App Registration: $_`n" -ForegroundColor Yellow
}

# Delete Entra ID Security Group
Write-Host "Step 3: Deleting Entra ID Security Group..." -ForegroundColor Cyan
try {
    $existingGroup = az ad group list --filter "displayName eq '$entraIdGroupName'" --query "[0]" -o json | ConvertFrom-Json
    
    if ($existingGroup) {
        $groupId = $existingGroup.id
        Write-Host "Found Security Group: $entraIdGroupName (ID: $groupId)" -ForegroundColor Yellow
        az ad group delete --group $groupId
        Write-Host "Security Group deleted: $entraIdGroupName`n" -ForegroundColor Green
    } else {
        Write-Host "Security Group not found (already deleted or never created)`n" -ForegroundColor Gray
    }
} catch {
    Write-Host "Warning: Could not delete Security Group: $_`n" -ForegroundColor Yellow
}

# Delete Resource Group (this will delete all resources within it)
Write-Host "Step 4: Deleting Resource Group and all resources..." -ForegroundColor Cyan
Write-Host "This will delete:" -ForegroundColor Yellow
Write-Host "  - SQL Server: $sqlServerName" -ForegroundColor Gray
Write-Host "  - Database and all data" -ForegroundColor Gray
Write-Host "  - Container Registry: $acrName" -ForegroundColor Gray
Write-Host "  - All Docker images" -ForegroundColor Gray
Write-Host "  - Web App: $webAppName" -ForegroundColor Gray
Write-Host "  - App Service Plan" -ForegroundColor Gray
Write-Host "  - All logs and configurations" -ForegroundColor Gray
Write-Host ""

try {
    $rgExists = az group exists --name $resourceGroupName -o tsv
    
    if ($rgExists -eq "true") {
        Write-Host "Deleting resource group (this may take several minutes)..." -ForegroundColor Yellow
        az group delete --name $resourceGroupName --yes --no-wait
        Write-Host "Resource group deletion initiated: $resourceGroupName" -ForegroundColor Green
        Write-Host "Deletion is running in the background and may take 5-10 minutes to complete.`n" -ForegroundColor Yellow
    } else {
        Write-Host "Resource Group not found (already deleted or never created)`n" -ForegroundColor Gray
    }
} catch {
    Write-Host "Warning: Could not delete Resource Group: $_`n" -ForegroundColor Yellow
}

# Cleanup summary
Write-Host "======================================"
Write-Host "Cleanup Complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "✅ Deleted Resources:" -ForegroundColor Green
Write-Host "  • App Registration: $appRegName" -ForegroundColor White
Write-Host "  • Service Principal" -ForegroundColor White
Write-Host "  • Security Group: $entraIdGroupName" -ForegroundColor White
Write-Host "  • Resource Group: $resourceGroupName (deletion in progress)" -ForegroundColor White
Write-Host ""
Write-Host "Note: Resource group deletion is asynchronous and may take several minutes." -ForegroundColor Yellow
Write-Host "You can check the deletion status in the Azure Portal or with:" -ForegroundColor Yellow
Write-Host "  az group show --name $resourceGroupName" -ForegroundColor White
Write-Host ""
Write-Host "All GrooveApp infrastructure has been removed." -ForegroundColor Green
Write-Host ""
