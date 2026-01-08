# Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying GrooveApp to Azure using either the automated PowerShell script or manual Terraform configuration.

## Prerequisites

### Required Tools
- **Azure CLI** 2.50+: `az --version`
- **PowerShell** 7+: `$PSVersionTable.PSVersion`
- **Docker Desktop**: For building container images
- **Git**: For source control
- **sqlcmd** (optional): For database management

### Azure Requirements
- **Azure Subscription** with Owner or Contributor role
- **Entra ID Permissions**: Application Administrator (for app registrations)
- **Resource Quotas**: Ensure sufficient quota for:
  - App Service Plans (Standard S1 or higher)
  - Azure SQL Database
  - Container Registry

## Option 1: Automated Deployment (Recommended)

### Step 1: Authenticate to Azure

```powershell
# Login to Azure
az login --tenant <your-tenant-id>

# Set subscription
az account set --subscription <your-subscription-id>

# Verify authentication
az account show
```

### Step 2: Run Deployment Script

```powershell
# Navigate to infra directory
cd infra

# Run deployment script
.\build-appInfra.ps1
```

**What this script does (25 steps):**

1. ✅ Authenticates to Azure
2. ✅ Creates resource group
3. ✅ Creates Azure SQL Server with Entra ID admin
4. ✅ Creates SQL Database
5. ✅ Populates database with music theory data
6. ✅ Creates Azure Container Registry
7. ✅ Builds and scans API Docker image
8. ✅ Pushes API image to ACR
9. ✅ Creates App Service Plan (Linux B1)
10. ✅ Creates Entra ID security group
11. ✅ Creates API web app
12. ✅ Enables managed identity for API
13. ✅ Configures API container settings
14. ✅ Configures API app settings
15. ✅ Configures Easy Auth for API
16. ✅ Grants managed identity database access
17. ✅ Enables continuous deployment for API
18. ✅ Builds and scans frontend Docker image
19. ✅ Pushes frontend image to ACR
20. ✅ Creates frontend web app
21. ✅ Configures frontend container settings
22. ✅ Configures frontend app settings
23. ✅ Configures Easy Auth for frontend
24. ✅ Enables continuous deployment for frontend
25. ✅ Creates Entra ID app registrations

**Deployment time:** ~15-20 minutes

### Step 3: Verify Deployment

```powershell
# Check API health
curl https://app-grooveapp-dev-api.azurewebsites.net/health

# Check frontend
Start-Process "https://app-grooveapp-dev-frontend.azurewebsites.net"
```

## Option 2: Terraform Deployment

### Step 1: Configure Environment

```powershell
cd infra/terraform

# Copy example configuration
cp environments/dev.tfvars.example environments/dev.tfvars

# Edit dev.tfvars with your values
code environments/dev.tfvars
```

**Required variables:**
```hcl
tenant_id           = "your-tenant-id"
subscription_id     = "your-subscription-id"
sql_admin_user_id   = "your-object-id"  # az ad signed-in-user show --query id -o tsv
sql_admin_user_principal = "your.email@domain.com"
```

### Step 2: Initialize Terraform

```powershell
# Initialize backend
terraform init -backend-config="key=grooveapp-dev.tfstate"
```

### Step 3: Plan Deployment

```powershell
# Review planned changes
terraform plan -var-file="environments/dev.tfvars" -out="terraform.tfplan"

# View plan details
terraform show terraform.tfplan
```

### Step 4: Apply Configuration

```powershell
# Deploy infrastructure
terraform apply terraform.tfplan
```

### Step 5: Build and Push Container Images

```powershell
# Get ACR credentials
$acrName = terraform output -raw container_registry_name
$acrServer = terraform output -raw container_registry_login_server

# Login to ACR
az acr login --name $acrName

# Build and push API
cd ../../api
docker build -t ${acrServer}/grooveapp-api:latest .
docker push ${acrServer}/grooveapp-api:latest

# Build and push frontend
cd ../app
docker build --build-arg BUILD_CONFIGURATION=dev -t ${acrServer}/grooveapp-frontend:latest .
docker push ${acrServer}/grooveapp-frontend:latest
```

### Step 6: Populate Database

```powershell
cd ../infra

# Get database details
$sqlServer = terraform output -raw sql_server_fqdn
$sqlDatabase = terraform output -raw sql_database_name

# Run setup script
sqlcmd -S $sqlServer -d $sqlDatabase -G -i setup-music-tables.sql
```

## Post-Deployment Configuration

### Configure CORS

```powershell
# Get resource names
$apiName = "app-grooveapp-dev-api"
$frontendName = "app-grooveapp-dev-frontend"
$rgName = "rg-grooveapp-dev"

# Configure API CORS
az webapp cors add `
    --name $apiName `
    --resource-group $rgName `
    --allowed-origins "https://${frontendName}.azurewebsites.net"

# Enable credentials support
az rest --method PUT `
    --uri "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rgName/providers/Microsoft.Web/sites/$apiName/config/web?api-version=2021-02-01" `
    --body '{"properties":{"cors":{"allowedOrigins":["https://app-grooveapp-dev-frontend.azurewebsites.net"],"supportCredentials":true}}}'
```

### Update Easy Auth to Return 401

```powershell
# Get current auth config
$authConfig = az rest --method GET `
    --uri "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rgName/providers/Microsoft.Web/sites/$apiName/config/authsettingsV2?api-version=2021-02-01" | ConvertFrom-Json

# Update unauthenticated action
$authConfig.properties.globalValidation.unauthenticatedClientAction = "Return401"

# Save and apply
$authConfig | ConvertTo-Json -Depth 10 | Out-File "$env:TEMP\api-auth-config.json" -Encoding UTF8
az rest --method PUT `
    --uri "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rgName/providers/Microsoft.Web/sites/$apiName/config/authsettingsV2?api-version=2021-02-01" `
    --body "@$env:TEMP\api-auth-config.json"
```

## Updating the Application

### Update API Only

```powershell
cd infra
.\deploy-updates.ps1 -ApiOnly
```

### Update Frontend Only

```powershell
cd infra
.\deploy-updates.ps1 -FrontendOnly
```

### Update Both (Default)

```powershell
cd infra
.\deploy-updates.ps1
```

### Deploy to Staging Only (No Swap)

```powershell
.\deploy-updates.ps1 -SkipSwap
```

### Manual Slot Swap

```powershell
# Swap API
az webapp deployment slot swap `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --slot staging

# Swap Frontend
az webapp deployment slot swap `
    --name app-grooveapp-dev-frontend `
    --resource-group rg-grooveapp-dev `
    --slot staging
```

## Rollback Procedure

### Automatic Rollback

```powershell
# Swap slots again to revert
az webapp deployment slot swap `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --slot staging
```

### Manual Rollback

1. **Stop staging slot:** Prevents it from being swapped
   ```powershell
   az webapp stop --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --slot staging
   ```

2. **Deploy previous image tag:**
   ```powershell
   az webapp config container set `
       --name app-grooveapp-dev-api `
       --resource-group rg-grooveapp-dev `
       --docker-custom-image-name "acrgrooveappdevuhxg.azurecr.io/grooveapp-api:20260106-120000"
   ```

## Environment-Specific Deployments

### Development
```powershell
# Use dev.tfvars
terraform apply -var-file="environments/dev.tfvars"
```

### Staging
```powershell
# Use staging.tfvars
terraform apply -var-file="environments/staging.tfvars"
```

### Production
```powershell
# Use prod.tfvars
terraform apply -var-file="environments/prod.tfvars"
```

## Monitoring Deployment

### View Deployment Logs

```powershell
# API logs
az webapp log tail --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev

# Frontend logs
az webapp log tail --name app-grooveapp-dev-frontend --resource-group rg-grooveapp-dev

# Staging slot logs
az webapp log tail --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --slot staging
```

### Download Logs

```powershell
# Download API logs
az webapp log download --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --log-file "$env:TEMP\api-logs.zip"

# Extract and view
Expand-Archive -Path "$env:TEMP\api-logs.zip" -DestinationPath "$env:TEMP\api-logs" -Force
Get-Content "$env:TEMP\api-logs\LogFiles\*_docker.log" | Select-Object -Last 100
```

## Cleanup

### Remove All Resources

```powershell
# Using cleanup script
cd infra
.\cleanup-appInfra.ps1

# Or using Terraform
cd terraform
terraform destroy -var-file="environments/dev.tfvars"
```

### Remove Specific Resources

```powershell
# Delete resource group (removes everything)
az group delete --name rg-grooveapp-dev --yes

# Delete Entra ID app registrations manually from Azure Portal
```

## Troubleshooting

See [Troubleshooting Guide](TROUBLESHOOTING.md) for common deployment issues and solutions.

## Security Best Practices

✅ **Secrets Management**: Never commit secrets to Git  
✅ **Managed Identity**: Use for database access  
✅ **Easy Auth**: Enable Entra ID authentication  
✅ **HTTPS Only**: Enforce TLS 1.2+  
✅ **Image Scanning**: Run Docker Scout before deployment  
✅ **Least Privilege**: Grant minimum required permissions  

## References

- [Azure App Service Deployment](https://learn.microsoft.com/en-us/azure/app-service/deploy-continuous-deployment)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)

---

**Last Updated:** January 2026
