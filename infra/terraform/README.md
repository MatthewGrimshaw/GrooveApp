# Terraform Infrastructure for GrooveApp

This directory contains Terraform configurations to deploy the GrooveApp infrastructure on Azure.

## Overview

The Terraform configuration provides a **modular, flexible infrastructure** that can deploy the application with different database backends (SQL Server, PostgreSQL, or Cosmos DB) across multiple environments (dev, staging, prod).

## Features

- **Multi-Database Support**: Switch between Azure SQL, PostgreSQL, or Cosmos DB
- **Environment-Based Configuration**: Separate tfvars files for dev, staging, and production
- **Modular Design**: Reusable modules for database, container registry, app services, and Entra ID
- **Security**: Managed identities, Easy Auth, and security groups
- **Best Practices**: Follows Azure and Terraform conventions

## Prerequisites

1. **Terraform**: Install Terraform 1.5 or later
   ```bash
   # Verify installation
   terraform version
   ```

2. **Azure CLI**: Install and authenticate
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

3. **Permissions**: Ensure you have:
   - Contributor role on the Azure subscription
   - Application Administrator role in Azure AD (for app registrations)

## Project Structure

```
infra/
├── main.tf                    # Main orchestration file
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
├── environments/              # Environment-specific configurations
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
└── modules/                   # Reusable modules
    ├── database-sql/          # Azure SQL Server
    ├── database-postgres/     # PostgreSQL Flexible Server
    ├── database-cosmos/       # Cosmos DB
    ├── container-registry/    # Azure Container Registry
    ├── app-service-plan/      # App Service Plan
    ├── entra-id/              # Security groups and app registrations
    └── web-app/               # Web App with Easy Auth
```

## Quick Start

### 1. Configure Variables

Copy the example file and update with your values:

```bash
cp terraform.tfvars.example environments/dev.tfvars
```

Edit `environments/dev.tfvars` and set:
- `tenant_id`: Your Azure AD tenant ID
- `subscription_id`: Your Azure subscription ID
- `sql_admin_user_id`: Your Object ID (get with `az ad signed-in-user show --query id -o tsv`)
- `sql_admin_user_principal`: Your email/UPN

### 2. Initialize Terraform

```bash
cd infra
terraform init
```

### 3. Plan Deployment

```bash
terraform plan -var-file=environments/dev.tfvars
```

### 4. Deploy Infrastructure

```bash
terraform apply -var-file=environments/dev.tfvars
```

### 5. View Outputs

```bash
terraform output
```

## Database Type Switching

The infrastructure supports three database types. To switch between them:

1. Edit your tfvars file and change `database_type`:
   ```hcl
   database_type = "sql"      # For Azure SQL Server
   database_type = "postgres" # For PostgreSQL
   database_type = "cosmos"   # For Cosmos DB
   ```

2. Add required variables for the chosen database:
   
   **For SQL Server:**
   ```hcl
   sql_admin_user_id        = "..."
   sql_admin_user_principal = "..."
   sql_sku_name             = "S0"
   ```

   **For PostgreSQL:**
   ```hcl
   postgres_admin_username = "pgadmin"
   postgres_admin_password = "SecurePassword123!"
   postgres_sku_name       = "B_Standard_B1ms"
   ```

   **For Cosmos DB:**
   ```hcl
   cosmos_consistency_level = "Session"
   cosmos_throughput        = 400
   ```

3. Apply changes:
   ```bash
   terraform apply -var-file=environments/dev.tfvars
   ```

## Environment Management

### Development
```bash
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

### Staging
```bash
terraform plan -var-file=environments/staging.tfvars
terraform apply -var-file=environments/staging.tfvars
```

### Production
```bash
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

## State Management

### Local State (Default)

By default, Terraform stores state locally in `terraform.tfstate`. **Do not commit this file to version control.**

### Remote State (Recommended for Production)

For production, configure Azure Storage backend:

1. Create storage account and container:
   ```bash
   az group create --name rg-terraform-state --location eastus
   az storage account create --name <unique-name> --resource-group rg-terraform-state --sku Standard_LRS
   az storage container create --name tfstate --account-name <unique-name>
   ```

2. Uncomment and configure backend in `main.tf`:
   ```hcl
   terraform {
     backend "azurerm" {
       resource_group_name  = "rg-terraform-state"
       storage_account_name = "<unique-name>"
       container_name       = "tfstate"
       key                  = "grooveapp.tfstate"
     }
   }
   ```

3. Re-initialize:
   ```bash
   terraform init -migrate-state
   ```

## Post-Deployment Steps

After Terraform completes, you still need to:

1. **Build and Push Container Images**:
   ```bash
   # Login to ACR
   az acr login --name <acr-name>
   
   # Build and push API
   cd api
   docker build -t <acr-name>.azurecr.io/grooveapp-api:latest .
   docker push <acr-name>.azurecr.io/grooveapp-api:latest
   
   # Build and push Frontend
   cd ../app
   docker build -t <acr-name>.azurecr.io/grooveapp-frontend:latest .
   docker push <acr-name>.azurecr.io/grooveapp-frontend:latest
   ```

2. **Populate Database** (for SQL Server):
   ```bash
   cd infra
   ./build-appInfra.ps1 -DatabaseOnly
   ```

3. **Add Users to Security Group**:
   ```bash
   az ad group member add --group <group-id> --member-id <user-object-id>
   ```

## Destroying Resources

To delete all resources:

```bash
terraform destroy -var-file=environments/dev.tfvars
```

**Warning**: This will delete all data. Ensure backups are in place.

## Comparison with PowerShell Script

| Feature | PowerShell (`build-appInfra.ps1`) | Terraform |
|---------|-----------------------------------|-----------|
| Database Support | SQL Server only | SQL Server, PostgreSQL, Cosmos DB |
| Environment Management | Manual script parameters | Separate tfvars files |
| State Tracking | None | Terraform state |
| Idempotency | Partial | Full |
| Modularity | Monolithic script | Reusable modules |
| Best Use Case | Quick deployments, testing | Production, multi-environment |

**Recommendation**: 
- Use **PowerShell** for quick testing and development iterations
- Use **Terraform** for staging and production deployments

## Troubleshooting

### Error: "terraform init" fails
- Ensure Terraform 1.5+ is installed
- Check internet connectivity

### Error: "az login" required
```bash
az login
az account set --subscription <subscription-id>
```

### Error: Insufficient permissions
- Verify you have Contributor role: `az role assignment list --assignee <your-email>`
- Verify Azure AD permissions for app registrations

### Error: Resource name already exists
- Resource names must be globally unique (especially ACR and SQL Server)
- Modify `app_name` in tfvars to use a unique value

## Additional Resources

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Naming Conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## Support

For issues related to:
- **Terraform configuration**: Check module documentation in `modules/*/README.md`
- **Azure resources**: Consult [Azure documentation](https://learn.microsoft.com/azure/)
- **Application code**: See main repository README
