# Import existing Entra ID resources into Terraform state
# This script must be run from the infra/terraform directory

param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Entra ID resource import for environment: $Environment" -ForegroundColor Cyan

# Get app registration details from Azure
$apiAppName = "appreg-app-grooveapp-$Environment-api"
$frontendAppName = "appreg-app-grooveapp-$Environment-frontend"
$securityGroupName = "GrooveApp-$Environment-Users"

Write-Host "`nRetrieving API app registration..." -ForegroundColor Yellow
$apiApp = az ad app list --display-name $apiAppName --query '[0]' | ConvertFrom-Json
if (-not $apiApp) {
    Write-Host "API app registration not found. It will be created by Terraform." -ForegroundColor Green
}
else {
    Write-Host "Found API app: $($apiApp.appId)" -ForegroundColor Green
    Write-Host "Importing API application..."
    terraform import "module.entra_id.azuread_application.api" $apiApp.id
    
    Write-Host "Retrieving API service principal..."
    $apiSp = az ad sp list --display-name $apiAppName --query '[0]' | ConvertFrom-Json
    if ($apiSp) {
        Write-Host "Importing API service principal..."
        terraform import "module.entra_id.azuread_service_principal.api" $apiSp.id
    }
}

Write-Host "`nRetrieving Frontend app registration..." -ForegroundColor Yellow
$frontendApp = az ad app list --display-name $frontendAppName --query '[0]' | ConvertFrom-Json
if (-not $frontendApp) {
    Write-Host "Frontend app registration not found. It will be created by Terraform." -ForegroundColor Green
}
else {
    Write-Host "Found Frontend app: $($frontendApp.appId)" -ForegroundColor Green
    Write-Host "Importing Frontend application..."
    terraform import "module.entra_id.azuread_application.frontend" $frontendApp.id
    
    Write-Host "Retrieving Frontend service principal..."
    $frontendSp = az ad sp list --display-name $frontendAppName --query '[0]' | ConvertFrom-Json
    if ($frontendSp) {
        Write-Host "Importing Frontend service principal..."
        terraform import "module.entra_id.azuread_service_principal.frontend" $frontendSp.id
    }
}

Write-Host "`nRetrieving security group..." -ForegroundColor Yellow
$secGroup = az ad group list --display-name $securityGroupName --query '[0]' | ConvertFrom-Json
if (-not $secGroup) {
    Write-Host "Security group not found. It will be created by Terraform." -ForegroundColor Green
}
else {
    Write-Host "Found security group: $($secGroup.id)" -ForegroundColor Green
    Write-Host "Importing security group..."
    terraform import "module.entra_id.azuread_group.security" $secGroup.id
}

Write-Host "`n" -NoNewline
Write-Host "IMPORTANT: " -ForegroundColor Red -NoNewline
Write-Host "Application passwords (secrets) cannot be imported." -ForegroundColor Yellow
Write-Host "Terraform will create new secrets for both applications." -ForegroundColor Yellow
Write-Host "You will need to update your App Service configuration with the new secrets." -ForegroundColor Yellow

Write-Host "`nImport complete! Run 'terraform plan' to verify." -ForegroundColor Cyan
