# Environment Configuration
# Centralized configuration for different deployment environments

This file documents the environment-specific configurations for the GrooveApp API.

## Environment Overview

| Environment | Purpose | SQL Server | Database |
|------------|---------|------------|----------|
| **dev** | Development and testing | `sql-grooveapp-dev-uhxg.database.windows.net` | `db-grooveapp-dev` |
| **staging** | Pre-production testing | `sql-grooveapp-staging.database.windows.net` | `db-grooveapp-staging` |
| **prod** | Production | `sql-grooveapp-prod.database.windows.net` | `db-grooveapp-prod` |

## Configuration Sources

### Local Development (Docker)
When running locally with Docker, use the `build-localApi.ps1` script with the `-Environment` parameter:

```powershell
# Development (default)
.\build-localApi.ps1 -Rebuild

# Staging
.\build-localApi.ps1 -Rebuild -Environment staging

# Production
.\build-localApi.ps1 -Rebuild -Environment prod
```

The script automatically sets the correct `SQL_SERVER` and `SQL_DATABASE` environment variables.

### Azure Web App Deployment
When deployed to Azure via Terraform, environment variables are automatically configured in the Web App settings:

```hcl
# From infra/terraform/main.tf
app_settings = merge(
  var.api_app_settings,
  {
    SQL_SERVER   = module.database_sql[0].server_fqdn
    SQL_DATABASE = module.database_sql[0].database_name
  }
)
```

The values are dynamically set based on the Terraform environment (dev/staging/prod).

## Environment Variables Required

The API requires these environment variables to connect to the database:

| Variable | Description | Example |
|----------|-------------|---------|
| `SQL_SERVER` | Fully qualified domain name of SQL Server | `sql-grooveapp-dev-uhxg.database.windows.net` |
| `SQL_DATABASE` | Database name | `db-grooveapp-dev` |
| `AZURE_ACCESS_TOKEN` | (Local only) Azure AD access token | Obtained via `az account get-access-token` |

**Note:** In Azure Web Apps, managed identity authentication is used, so `AZURE_ACCESS_TOKEN` is not needed.

## Updating Environment Configuration

### For Local Development
Update the `$envConfig` hashtable in `api/build-localApi.ps1`:

```powershell
$envConfig = @{
    dev = @{
        SqlServer = "sql-grooveapp-dev-uhxg.database.windows.net"
        SqlDatabase = "db-grooveapp-dev"
    }
    # ... other environments
}
```

### For Azure Deployment
The configuration is managed by Terraform:

1. Update environment-specific `.tfvars` files in `infra/terraform/environments/`
2. Terraform automatically provisions resources with environment-specific names
3. Web App environment variables are set via the Terraform web-app module

## Security Best Practices

1. **Never hardcode connection strings** - Always use environment variables
2. **Use managed identity in Azure** - Web Apps authenticate via system-assigned managed identity
3. **Local testing uses temporary tokens** - Access tokens obtained via Azure CLI are short-lived
4. **Separate databases per environment** - Each environment has its own isolated database
5. **Follow least privilege** - Grant only necessary permissions to each identity

## Troubleshooting

### "SQL_SERVER and SQL_DATABASE environment variables must be set"
**Cause:** Environment variables are not provided  
**Solution:** Ensure you're running the container with proper environment configuration

```powershell
# Correct
.\build-localApi.ps1 -Rebuild -Environment dev

# Incorrect (old method)
docker run grooveapp-api  # Missing environment variables
```

### "Database connection failed"
**Cause:** Incorrect SQL Server name or database name  
**Solution:** Verify the server name matches your Azure resource:

```powershell
# Check deployed resources in Azure
az sql server list --query "[].{name:name, fqdn:fullyQualifiedDomainName}" -o table
```

### Local token authentication fails
**Cause:** Not logged into Azure CLI  
**Solution:** Login first:

```powershell
az login --tenant <your-tenant-id>
az account set --subscription <your-subscription-id>
```
