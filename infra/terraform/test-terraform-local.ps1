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

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Init Complete"
Write-Host "======================================"
Write-Host ""

# Validate Terraform configuration
Write-Host "Running terraform validate..." -ForegroundColor Cyan
Write-Host ""

terraform validate

Write-Host ""
Write-Host "======================================"
Write-Host "Terraform Validate Complete"
Write-Host "======================================"
Write-Host ""

# Format Terraform files
Write-Host "Running terraform fmt..." -ForegroundColor Cyan
Write-Host ""

terraform fmt -check -recursive

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

terraform apply -var-file="$varFile" -auto-approve
terraform apply terraform.tfplan


if ($exitCode -eq 0) {
    Write-Host "✅ Success!" -ForegroundColor Green
    Write-Host "   Debug log saved to: terraform-debug.log" -ForegroundColor White
}
else {
    Write-Host "❌ Failed with exit code: $exitCode" -ForegroundColor Red
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

#exit $exitCode